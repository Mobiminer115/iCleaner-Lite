import Foundation

protocol FileSystemProvider {
    func directories(at url: URL) throws -> [URL]
    func size(of url: URL) -> Int64
    func removeContents(of url: URL) throws
}

enum FileSystemAccessError: LocalizedError {
    case inaccessible(URL, Error)

    var errorDescription: String? {
        switch self {
        case .inaccessible(let url, let error):
            return "Cannot access \(url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

final class LocalFileSystemProvider: FileSystemProvider {
    private let fileManager = FileManager.default

    func directories(at url: URL) throws -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ).filter { item in
                let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                return values?.isDirectory == true && values?.isSymbolicLink != true
            }
        } catch {
            throw FileSystemAccessError.inaccessible(url, error)
        }
    }

    func size(of url: URL) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
                if values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                if values.isRegularFile == true {
                    total += Int64(values.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        return total
    }

    func removeContents(of url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let items = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: []
            )
            for item in items {
                let values = try? item.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values?.isSymbolicLink != true else { continue }
                try fileManager.removeItem(at: item)
            }
        } catch {
            throw FileSystemAccessError.inaccessible(url, error)
        }
    }
}
