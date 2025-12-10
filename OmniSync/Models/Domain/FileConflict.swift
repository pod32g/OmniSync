import Foundation

struct FileConflict: Identifiable {
    let id = UUID()
    let path: String
    let localModified: Date?
    let remoteModified: Date?
    let localSize: Int64?
    let remoteSize: Int64?
    var resolution: ConflictResolution = .keepNewer
}
