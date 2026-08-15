import Foundation

final class AppScanner {
    private let fs: FileSystemProvider

    init(fileSystem: FileSystemProvider = LocalFileSystemProvider()) {
        self.fs = fileSystem
    }

    func scan(rootURL: URL) async -> [AppCacheInfo] {
        guard let containers = try? fs.directories(at: rootURL) else { return [] }
        return await withTaskGroup(of: AppCacheInfo?.self, returning: [AppCacheInfo].self) { group in
            for container in containers {
                group.addTask { [fs] in
                    let bundleID = Self.readBundleIdentifier(container) ?? container.lastPathComponent
                    let tmp = container.appendingPathComponent("tmp")
                    let caches = container.appendingPathComponent("Library/Caches")
                    let logs = container.appendingPathComponent("Library/Logs")
                    let tmpSize = fs.size(of: tmp)
                    let cacheSize = fs.size(of: caches)
                    let logSize = fs.size(of: logs)
                    guard tmpSize + cacheSize + logSize > 0 else { return nil }
                    return AppCacheInfo(bundleID: bundleID, containerURL: container, tmpSize: tmpSize, cacheSize: cacheSize, logSize: logSize)
                }
            }
            var result: [AppCacheInfo] = []
            for await item in group {
                if let item { result.append(item) }
            }
            return result.sorted { $0.totalSize > $1.totalSize }
        }
    }

    private static func readBundleIdentifier(_ container: URL) -> String? {
        let metadata = container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        guard let data = try? Data(contentsOf: metadata),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist["MCMMetadataIdentifier"] as? String
    }
}
