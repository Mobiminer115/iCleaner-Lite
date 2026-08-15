import SwiftUI

struct ContentView: View {
    @State private var apps: [AppCacheInfo] = []
    @State private var selected = Set<UUID>()
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var showLogs = true

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
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Selected").font(.caption).foregroundStyle(.secondary)
                            Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                                .font(.title2.bold())
                        }
                        Spacer()
                        Button(selected.count == apps.count && !apps.isEmpty ? "Deselect All" : "Select All") {
                            if selected.count == apps.count { selected.removeAll() } else { selected = Set(apps.map(\.id)) }
                        }
                    }

                    Button {
                        Task { await scan() }
                    } label: {
                        Label(isScanning ? "Scanning…" : "Scan Applications", systemImage: "magnifyingglass")
                    }
                    .disabled(isScanning || isCleaning)
                }

                Section("Targets") {
                    Toggle("Include Library/Logs", isOn: $showLogs)
                    Text("Only tmp, Library/Caches and optional Library/Logs are touched. Other app data is never selected by this cleaner.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Applications") {
                    if apps.isEmpty {
                        ContentUnavailableView("No cache data scanned", systemImage: "shippingbox")
                    } else {
                        ForEach(apps) { app in
                            Button {
                                if selected.contains(app.id) { selected.remove(app.id) } else { selected.insert(app.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selected.contains(app.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(app.bundleID).font(.headline).foregroundStyle(.primary).lineLimit(1)
                                        HStack(spacing: 8) {
                                            Text("tmp \(format(app.tmpSize))")
                                            Text("cache \(format(app.cacheSize))")
                                            if showLogs { Text("logs \(format(app.logSize))") }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(format(app.totalSize)).fontWeight(.semibold).foregroundStyle(.primary)
                                }
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
                            if isCleaning { ProgressView() } else { Label("Clean Selected • \(format(selectedSize))", systemImage: "trash") }
                            Spacer()
                        }
                    }
                    .disabled(selected.isEmpty || isScanning || isCleaning)
                }
            }
            .navigationTitle("iCleaner Lite")
        }
    }

    private func scan() async {
        isScanning = true
        defer { isScanning = false }
        apps = await scanner.scan(rootURL: applicationRoot)
        selected.removeAll()
    }

    private func cleanSelected() async {
        isCleaning = true
        defer { isCleaning = false }
        var targets: Set<CleanTarget> = [.tmp, .caches]
        if showLogs { targets.insert(.logs) }
        for app in apps where selected.contains(app.id) {
            try? cleaner.clean(app: app, targets: targets)
        }
        apps = await scanner.scan(rootURL: applicationRoot)
        selected.removeAll()
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
