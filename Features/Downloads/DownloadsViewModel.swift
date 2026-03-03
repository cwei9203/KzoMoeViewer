import Foundation

@MainActor
final class DownloadsViewModel: ObservableObject {
    @Published private(set) var tasks: [DownloadTask] = DownloadMockData.tasks
    private let engine = DownloadQueueEngine(seedTasks: DownloadMockData.tasks)

    init() {
        Task { @MainActor [weak self] in
            await self?.refreshFromEngine()
        }
    }

    var downloadingTasks: [DownloadTask] {
        tasks.filter { $0.state == .downloading || $0.state == .paused || $0.state == .waiting }
    }

    var completedTasks: [DownloadTask] {
        tasks.filter { $0.state == .completed }
    }

    var usedRatio: Double {
        let used = tasks.reduce(0.0) { $0 + $1.downloadedMB }
        let capacity = 32.0 * 1024.0
        return min(max(used / capacity, 0), 1)
    }

    func togglePauseResume(taskID: UUID) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            tasks = await engine.togglePauseResume(id: taskID)
        }
    }

    func removeCompleted(taskID: UUID) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            tasks = await engine.removeCompleted(id: taskID)
        }
    }

    private func refreshFromEngine() async {
        tasks = await engine.snapshot()
    }
}
