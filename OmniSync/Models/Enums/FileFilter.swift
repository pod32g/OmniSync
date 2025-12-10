import Foundation

enum FileFilter: String, CaseIterable, Identifiable {
    case all
    case video
    case photo
    case documents
    case audio
    case archives
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All files"
        case .video: return "Videos"
        case .photo: return "Photos"
        case .documents: return "Text & Docs"
        case .audio: return "Audio"
        case .archives: return "Archives"
        case .custom: return "Custom patterns"
        }
    }

    var patterns: [String] {
        switch self {
        case .all: return []
        case .video: return ["*.mp4", "*.mov", "*.mkv", "*.avi", "*.m4v", "*.mts", "*.m2ts", "*.webm", "*.mpeg", "*.mpg", "*.3gp"]
        case .photo: return ["*.jpg", "*.jpeg", "*.png", "*.heic", "*.heif", "*.gif", "*.tif", "*.tiff", "*.bmp", "*.raw", "*.dng", "*.cr2", "*.nef", "*.arw", "*.raf"]
        case .documents: return ["*.txt", "*.md", "*.rtf", "*.pdf", "*.doc", "*.docx", "*.pages", "*.csv", "*.xls", "*.xlsx", "*.ppt", "*.pptx", "*.key"]
        case .audio: return ["*.mp3", "*.flac", "*.aac", "*.m4a", "*.wav", "*.aiff", "*.aif", "*.ogg", "*.opus", "*.wma"]
        case .archives: return ["*.zip", "*.tar", "*.gz", "*.tgz", "*.7z", "*.rar", "*.bz2", "*.xz", "*.iso"]
        case .custom: return []
        }
    }

    var example: String {
        switch self {
        case .all: return "No filtering"
        case .video: return "*.mp4, *.mov, *.mkv"
        case .photo: return "*.jpg, *.png, *.heic"
        case .documents: return "*.txt, *.pdf, *.docx"
        case .audio: return "*.mp3, *.flac, *.wav"
        case .archives: return "*.zip, *.tar, *.rar"
        case .custom: return "Comma-separated patterns"
        }
    }
}
