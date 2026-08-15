import Foundation

final class CacheCleaner {
    private let fs: FileSystemProvider

    init(fileSystem: FileSystemProvider = LocalFileSystemProvider()) {
        self.fs = fileSystem
    }

    func clean(app: AppCacheInfo, targets: Set<CleanTarget>) throws {
        for target in targets {
            let url = app.containerURL.appendingPathComponent(target.relativePath)
            try fs.removeContents(of: url)
        }
    }
}
