import Foundation

struct TransferEstimate {
    let fileCount: Int
    let totalBytes: Int64
    let estimatedSeconds: Int

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var formattedTime: String {
        if estimatedSeconds < 60 {
            return "\(estimatedSeconds)s"
        } else if estimatedSeconds < 3600 {
            let minutes = estimatedSeconds / 60
            let seconds = estimatedSeconds % 60
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            let hours = estimatedSeconds / 3600
            let minutes = (estimatedSeconds % 3600) / 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
    }
}
