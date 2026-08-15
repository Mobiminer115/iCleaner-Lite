import SwiftUI

struct ContentView: View {
    @State private var apps: [AppCacheInfo] = []
    @State private var selected = Set<UUID>()
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var showLogs = true
    @State private var statusMessage: String?

    private let scanner = AppScanner()
    private let cleaner = CacheCleaner()
    private let applicationRoot = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application", isDirectory: true)

    private var selectedSize: Int64 {
        apps.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(format(selectedSize))
                                    .font(.title2.weight(.bold))
                                    .minimumScaleFactor(0.7)
                            }

                            Spacer(minLength: 8)

                            Button(selected.count == apps.count && !apps.isEmpty ? "Deselect All" : "Select All") {
                                if selected.count == apps.count {
                                    selected.removeAll()
                                } else {
                                    selected = Set(apps.map(\.id))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Button {
                            Task { await scan() }
                        } label: {
                            HStack {
                                Image(systemName: isScanning ? "hourglass" : "magnifyingglass")
                                Text(isScanning ? "Scanning…" : "Scan Applications")
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isScanning || isCleaning)
                    }
                }

                if let statusMessage {
                    Section {
                        Label(statusMessage, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Targets") {
                    Toggle("Include Library/Logs", isOn: $showLogs)
                    Text("Only tmp, Library/Caches and optional Library/Logs are selected for cleaning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Applications") {
                    if apps.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "shippingbox")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Nothing scanned yet")
                                .font(.headline)
                            Text("Tap Scan Applications to search for cache data.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(apps) { app in
                            Button {
                                if selected.contains(app.id) {
                                    selected.remove(app.id)
                                } else {
                                    selected.insert(app.id)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected.contains(app.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(app.bundleID)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        HStack(spacing: 6) {
                                            Text("tmp \(format(app.tmpSize))")
                                            Text("cache \(format(app.cacheSize))")
                                            if showLogs { Text("logs \(format(app.logSize))") }
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    }

                                    Spacer(minLength: 4)

                                    Text(format(app.totalSize))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await cleanSelected() }
                    } label: {
                        HStack {
                            Spacer()
                            if isCleaning {
                                ProgressView()
                            } else {
                                Label("Clean Selected • \(format(selectedSize))", systemImage: "trash")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                        }
                    }
                    .disabled(selected.isEmpty || isScanning || isCleaning)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("iCleaner Lite")
        }
    }

    private func scan() async {
        isScanning = true
        statusMessage = nil
        defer { isScanning = false }

        let result = await scanner.scan(rootURL: applicationRoot)
        apps = result.apps
        selected.removeAll()
        statusMessage = result.message
    }

    private func cleanSelected() async {
        isCleaning = true
        defer { isCleaning = false }

        var targets: Set<CleanTarget> = [.tmp, .caches]
        if showLogs { targets.insert(.logs) }

        for app in apps where selected.contains(app.id) {
            try? cleaner.clean(app: app, targets: targets)
        }

        let result = await scanner.scan(rootURL: applicationRoot)
        apps = result.apps
        selected.removeAll()
        statusMessage = result.message ?? "Cleaning complete."
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
