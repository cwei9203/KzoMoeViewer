import Foundation

enum DownloadState: String, Hashable {
    case waiting
    case downloading
    case paused
    case failed
    case completed
}

struct DownloadTask: Identifiable, Hashable {
    let id: UUID
    let title: String
    let totalMB: Double
    var downloadedMB: Double
    var speedMBps: Double
    var state: DownloadState
    let dateText: String

    var progress: Double {
        guard totalMB > 0 else { return 0 }
        return min(max(downloadedMB / totalMB, 0), 1)
    }

    var detailText: String {
        "\(String(format: "%.1f", downloadedMB)) MB / \(String(format: "%.0f", totalMB)) MB"
    }

    var speedText: String {
        state == .downloading ? "\(String(format: "%.1f", speedMBps)) MB/s" : "-- MB/s"
    }
}

enum DownloadMockData {
    static let tasks: [DownloadTask] = [
        .init(id: UUID(), title: "One Piece Vol.100", totalMB: 145, downloadedMB: 28.5, speedMBps: 2.4, state: .downloading, dateText: "Mar 12"),
        .init(id: UUID(), title: "Jujutsu Kaisen Vol.18", totalMB: 138, downloadedMB: 12.5, speedMBps: 0, state: .paused, dateText: "Mar 10"),
        .init(id: UUID(), title: "Spy x Family Vol.9", totalMB: 152, downloadedMB: 152, speedMBps: 0, state: .completed, dateText: "Mar 12"),
        .init(id: UUID(), title: "Chainsaw Man Vol.11", totalMB: 134, downloadedMB: 134, speedMBps: 0, state: .completed, dateText: "Feb 28"),
        .init(id: UUID(), title: "Berserk Vol.41", totalMB: 189, downloadedMB: 189, speedMBps: 0, state: .completed, dateText: "Feb 20")
    ]
}
