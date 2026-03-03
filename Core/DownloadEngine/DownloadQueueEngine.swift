import Foundation

actor DownloadQueueEngine {
    private var tasks: [DownloadTask]

    init(seedTasks: [DownloadTask]) {
        self.tasks = seedTasks
    }

    func snapshot() -> [DownloadTask] {
        tasks
    }

    func togglePauseResume(id: UUID) -> [DownloadTask] {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return tasks }
        switch tasks[idx].state {
        case .downloading:
            tasks[idx].state = .paused
            tasks[idx].speedMBps = 0
        case .paused, .waiting:
            tasks[idx].state = .downloading
            tasks[idx].speedMBps = max(tasks[idx].speedMBps, 1.2)
        default:
            break
        }
        return tasks
    }

    func removeCompleted(id: UUID) -> [DownloadTask] {
        tasks.removeAll { $0.id == id && $0.state == .completed }
        return tasks
    }
}
