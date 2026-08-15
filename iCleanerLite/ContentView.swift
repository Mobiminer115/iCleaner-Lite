import SwiftUI

struct ContentView: View {
    @State private var apps: [AppCacheInfo] = []
    @State private var selected = Set<UUID>()
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var showLogs = false
    @State private var statusMessage: String?
    @State private var showCleanConfirmation = false

    private let scanner = AppScanner()
    private let cleaner = CacheCleaner()
    private let applicationRoot = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application", isDirectory: true)

    private var selectedSize: Int64 { apps.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.totalSize } }
    private var totalJunk: Int64 { apps.reduce(0) { $0 + $1.totalSize } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    scanButton
                    if let statusMessage { statusCard(statusMessage) }
                    if !apps.isEmpty {
                        optionsCard
                        appsCard
                        cleanButton
                    } else if !isScanning {
                        emptyCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("iCleaner Lite")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if isScanning { scanningOverlay } }
            .confirmationDialog("Clean selected files?", isPresented: $showCleanConfirmation, titleVisibility: .visible) {
                Button("Clean", role: .destructive) { Task { await cleanSelected() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Only tmp, Library/Caches and the optional Library/Logs contents will be removed.")
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 58, height: 58)
                Image(systemName: "sparkles").font(.title2.weight(.semibold)).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Junk found").font(.subheadline).foregroundStyle(.secondary)
                Text(format(totalJunk)).font(.system(.title, design: .rounded).weight(.bold)).minimumScaleFactor(0.65).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("Selected").font(.caption).foregroundStyle(.secondary)
                Text(format(selectedSize)).font(.headline.weight(.semibold)).minimumScaleFactor(0.6).lineLimit(1)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var scanButton: some View {
        Button { Task { await scan() } } label: {
            Label(isScanning ? "Scanning…" : "Scan for Junk", systemImage: isScanning ? "hourglass" : "magnifyingglass")
                .font(.headline).frame(maxWidth: .infinity).frame(minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isScanning || isCleaning)
    }

    private func statusCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.lowercased().contains("cannot") || message.lowercased().contains("no application") ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(.secondary)
            Text(message).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label("Cleanup targets", systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Toggle("Include logs", isOn: $showLogs).labelsHidden()
            }
            Text(showLogs ? "tmp + Library/Caches + Library/Logs" : "tmp + Library/Caches")
                .font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, 8)
            HStack {
                Text("Applications").font(.subheadline.weight(.semibold))
                Spacer()
                Button(selected.count == apps.count ? "Deselect All" : "Select All") {
                    if selected.count == apps.count { selected.removeAll() } else { selected = Set(apps.map(\.id)) }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var appsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                appRow(app)
                if index < apps.count - 1 { Divider().padding(.leading, 56) }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func appRow(_ app: AppCacheInfo) -> some View {
        Button {
            if selected.contains(app.id) { selected.remove(app.id) } else { selected.insert(app.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected.contains(app.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected.contains(app.id) ? Color.accentColor : .secondary).frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(app.bundleID).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1).truncationMode(.middle)
                    HStack(spacing: 8) {
                        sizePill("tmp", app.tmpSize)
                        sizePill("cache", app.cacheSize)
                        if showLogs && app.logSize > 0 { sizePill("logs", app.logSize) }
                    }
                }
                Spacer(minLength: 4)
                Text(format(app.totalSize)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).minimumScaleFactor(0.6).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14).padding(.vertical, 14).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sizePill(_ title: String, _ size: Int64) -> some View {
        Text("\(title) \(format(size))").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    }

    private var cleanButton: some View {
        Button(role: .destructive) { showCleanConfirmation = true } label: {
            Label("Clean Selected • \(format(selectedSize))", systemImage: "trash")
                .font(.headline).frame(maxWidth: .infinity).frame(minHeight: 50)
        }
        .buttonStyle(.borderedProminent).tint(.red)
        .disabled(selected.isEmpty || isScanning || isCleaning)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass.circle").font(.system(size: 42)).foregroundStyle(.secondary)
            Text("Ready to scan").font(.headline)
            Text("Find temporary files, app caches and optional logs without touching app data.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var scanningOverlay: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Scanning application containers…").font(.subheadline.weight(.semibold))
            Text("Please wait").font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 12, y: 6)
    }

    private func scan() async {
        isScanning = true
        statusMessage = nil
        selected.removeAll()
        let result = await scanner.scan(rootURL: applicationRoot)
        apps = result.apps
        statusMessage = result.message
        isScanning = false
    }

    private func cleanSelected() async {
        isCleaning = true
        var targets: Set<CleanTarget> = [.tmp, .caches]
        if showLogs { targets.insert(.logs) }
        for app in apps where selected.contains(app.id) { try? cleaner.clean(app: app, targets: targets) }
        let result = await scanner.scan(rootURL: applicationRoot)
        apps = result.apps
        selected.removeAll()
        statusMessage = result.message ?? "Cleaning complete."
        isCleaning = false
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
