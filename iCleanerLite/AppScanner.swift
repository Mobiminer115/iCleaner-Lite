import Foundation

struct ScanResult {
    let apps: [AppCacheInfo]
    let message: String?
    let accessDenied: Bool
}

final class AppScanner {
    private let fs: FileSystemProvider

    init(fileSystem: FileSystemProvider = LocalFileSystemProvider()) {
        self.fs = fileSystem
    }

    func scan(rootURL: URL) async -> ScanResult {
        do {
            let containers = try fs.directories(at: rootURL)

            guard !containers.isEmpty else {
                return ScanResult(
                    apps: [],
                    message: "No application containers were found. The current filesystem provider may not have access to other apps.",
                    accessDenied: false
                )
            }

            let results = await withTaskGroup(of: AppCacheInfo?.self, returning: [AppCacheInfo].self) { group in
                for container in containers {
                    group.addTask { [fs] in
                        let bundleID = Self.readBundleIdentifier(container) ?? container.lastPathComponent
                        let tmp = container.appendingPathComponent("tmp", isDirectory: true)
                        let caches = container.appendingPathComponent("Library/Caches", isDirectory: true)
                        let logs = container.appendingPathComponent("Library/Logs", isDirectory: true)

                        let tmpSize = fs.size(of: tmp)
                        let cacheSize = fs.size(of: caches)
                        let logSize = fs.size(of: logs)
                        let total = tmpSize + cacheSize + logSize

                        guard total > 0 else { return nil }

                        return AppCacheInfo(
                            bundleID: bundleID,
                            containerURL: container,
                            tmpSize: tmpSize,
                            cacheSize: cacheSize,
                            logSize: logSize
                        )
                    }
                }

                var result: [AppCacheInfo] = []
                for await item in group {
                    if let item { result.append(item) }
                }
                return result
            }

            let sorted = results.sorted { $0.totalSize > $1.totalSize }
            return ScanResult(
                apps: sorted,
                message: sorted.isEmpty ? "Application containers are visible, but the selected cleanup folders are empty." : nil,
                accessDenied: false
            )
        } catch let error as FileSystemAccessError {
            return ScanResult(
                apps: [],
                message: "Filesystem access is unavailable. iOS is blocking access to other apps' containers in the current environment. Enable a supported filesystem backend, then tap Retry Scan.",
                accessDenied: true
            )
        } catch {
            return ScanResult(
                apps: [],
                message: "Could not scan application containers: \(error.localizedDescription)",
                accessDenied: true
            )
        }
    }

    private static func readBundleIdentifier(_ container: URL) -> String? {
        let metadata = container.appendingPathComponent(
            ".com.apple.mobile_container_manager.metadata.plist"
        )

        guard let data = try? Data(contentsOf: metadata),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return nil
        }

        return plist["MCMMetadataIdentifier"] as? String
    }
}
