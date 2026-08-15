import Foundation

struct AppCacheInfo: Identifiable, Hashable {
    let id: UUID
    let bundleID: String
    let containerURL: URL
    var tmpSize: Int64
    var cacheSize: Int64
    var logSize: Int64

    init(id: UUID = UUID(), bundleID: String, containerURL: URL, tmpSize: Int64 = 0, cacheSize: Int64 = 0, logSize: Int64 = 0) {
        self.id = id
        self.bundleID = bundleID
        self.containerURL = containerURL
        self.tmpSize = tmpSize
        self.cacheSize = cacheSize
        self.logSize = logSize
    }

    var totalSize: Int64 { tmpSize + cacheSize + logSize }
}

enum CleanTarget: String, CaseIterable, Hashable, Identifiable {
    case tmp
    case caches
    case logs

    var id: String { rawValue }
    var title: String {
        switch self {
        case .tmp: return "tmp"
        case .caches: return "Caches"
        case .logs: return "Logs"
        }
    }

    var relativePath: String {
        switch self {
        case .tmp: return "tmp"
        case .caches: return "Library/Caches"
        case .logs: return "Library/Logs"
        }
    }
}
