import Foundation

@MainActor
final class DetailViewModel: ObservableObject {
    @Published private(set) var detail: MangaDetail
    @Published private(set) var isLoading = false
    @Published var selectedFormat: DownloadFormat = .epub
    @Published var selectedLine: DownloadLine = .line1
    @Published var isDownloading = false
    @Published var downloadError: String? = nil
    
    // 批量选择相关
    @Published var selectedChapterIDs: Set<Int> = []
    @Published var isSelectionMode = false
    @Published var selectAll = false
    
    // 下载任务管理
    @Published var downloadTasks: [ChapterDownloadTask] = []
    
    private let manga: Manga
    private let service: DetailServicing
    private let downloadService = DownloadService.shared

    init(manga: Manga, service: DetailServicing = DetailService()) {
        self.manga = manga
        self.service = service
        self.detail = MangaDetail(
            manga: manga,
            summary: "",
            tags: [manga.status.capitalized].filter { !$0.isEmpty },
            rating: 0,
            reads: "--",
            chapters: []
        )
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        detail = await service.loadDetail(for: manga)
        isLoading = false
    }
    
    // MARK: - 批量选择
    
    /// 切换选择模式
    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedChapterIDs.removeAll()
            selectAll = false
        }
    }
    
    /// 切换章节选中状态
    func toggleChapterSelection(_ chapterID: Int) {
        if selectedChapterIDs.contains(chapterID) {
            selectedChapterIDs.remove(chapterID)
        } else {
            selectedChapterIDs.insert(chapterID)
        }
        
        let downloadableIDs = Set(detail.chapters.filter(isChapterDownloadable).map(\.id))
        selectAll = !downloadableIDs.isEmpty && selectedChapterIDs == downloadableIDs
    }
    
    /// 全选/取消全选
    func toggleSelectAll() {
        if selectAll {
            // 取消全选
            selectedChapterIDs.removeAll()
            selectAll = false
        } else {
            // 全选所有可下载的章节
            let downloadableChapters = detail.chapters.filter(isChapterDownloadable)
            selectedChapterIDs = Set(downloadableChapters.map { $0.id })
            selectAll = true
        }
    }
    
    /// 获取选中的章节
    var selectedChapters: [MangaChapter] {
        detail.chapters.filter { selectedChapterIDs.contains($0.id) }
    }
    
    /// 选中的章节数量
    var selectedCount: Int {
        selectedChapterIDs.count
    }
    
    /// 是否有选中章节
    var hasSelection: Bool {
        !selectedChapterIDs.isEmpty
    }
    
    // MARK: - 下载功能
    
    /// 下载单个章节
    func downloadChapter(_ chapter: MangaChapter) async {
        guard isChapterDownloadable(chapter) else {
            downloadError = "该章节暂不可下载"
            return
        }
        
        // 避免同一章节重复进入下载队列（等待中/下载中）
        if hasActiveTask(for: chapter) {
            return
        }
        
        // 创建下载任务
        let taskID = UUID()
        let task = ChapterDownloadTask(
            id: taskID,
            chapter: chapter,
            manga: manga,
            format: selectedFormat,
            progress: 0,
            state: .waiting
        )
        
        // 添加到下载队列
        downloadTasks.append(task)
        
        // 开始下载
        await startDownload(taskID: taskID)
    }
    
    /// 批量下载选中的章节
    func downloadSelectedChapters() async {
        let chapters = selectedChapters.filter(isChapterDownloadable)
        
        var newTasks: [ChapterDownloadTask] = []
        for chapter in chapters {
            let task = ChapterDownloadTask(
                id: UUID(),
                chapter: chapter,
                manga: manga,
                format: selectedFormat,
                progress: 0,
                state: .waiting
            )
            newTasks.append(task)
        }
        
        // 添加所有任务
        downloadTasks.append(contentsOf: newTasks)
        
        // 退出选择模式
        isSelectionMode = false
        selectedChapterIDs.removeAll()
        selectAll = false
        
        // 开始下载（逐个下载）
        for task in newTasks {
            await startDownload(taskID: task.id)
        }
    }
    
    /// 下载所有可用章节
    func downloadAllAvailableChapters() async {
        let availableChapters = detail.chapters.filter(isChapterDownloadable)
        
        var newTasks: [ChapterDownloadTask] = []
        for chapter in availableChapters {
            let task = ChapterDownloadTask(
                id: UUID(),
                chapter: chapter,
                manga: manga,
                format: selectedFormat,
                progress: 0,
                state: .waiting
            )
            newTasks.append(task)
        }
        
        // 添加所有任务
        downloadTasks.append(contentsOf: newTasks)
        
        // 开始下载
        for task in newTasks {
            await startDownload(taskID: task.id)
        }
    }
    
    /// 开始下载任务
    private func startDownload(taskID: UUID) async {
        // 找到任务索引
        guard let index = downloadTasks.firstIndex(where: { $0.id == taskID }) else { return }
        
        downloadTasks[index].state = .downloading
        
        do {
            let task = downloadTasks[index]
            
            // 获取下载URL
            let url = try await downloadService.getDownloadURL(
                bookID: manga.id,
                volID: task.chapter.volID,
                format: task.format,
                line: selectedLine
            )
            
            // 生成保存路径
            let filename = downloadService.generateFilename(for: manga, chapter: task.chapter, format: task.format)
            let destination = downloadService.downloadsDirectory().appendingPathComponent(filename)
            
            // 下载文件
            try await downloadService.downloadFile(from: url, to: destination, progress: { progress in
                Task { @MainActor in
                    if let idx = self.downloadTasks.firstIndex(where: { $0.id == taskID }) {
                        self.downloadTasks[idx].progress = progress
                    }
                }
            }, bookID: manga.id)
            
            // 下载完成 - 更新状态
            if let idx = downloadTasks.firstIndex(where: { $0.id == taskID }) {
                downloadTasks[idx].progress = 1.0
                downloadTasks[idx].state = .completed
            }
            
        } catch {
            // 下载失败 - 更新状态
            if let idx = downloadTasks.firstIndex(where: { $0.id == taskID }) {
                downloadTasks[idx].state = .failed
                downloadTasks[idx].error = error.localizedDescription
            }
        }
    }
    
    /// 暂停下载
    func pauseDownload(_ taskID: UUID) {
        if let index = downloadTasks.firstIndex(where: { $0.id == taskID }) {
            downloadTasks[index].state = .paused
        }
    }
    
    /// 继续下载
    func resumeDownload(_ taskID: UUID) async {
        if let index = downloadTasks.firstIndex(where: { $0.id == taskID && $0.state == .paused }) {
            downloadTasks[index].state = .waiting
            await startDownload(taskID: taskID)
        }
    }
    
    /// 取消下载
    func cancelDownload(_ taskID: UUID) {
        downloadTasks.removeAll { $0.id == taskID }
    }
    
    /// 清除已完成的任务
    func clearCompletedTasks() {
        downloadTasks.removeAll { $0.state == .completed }
    }
    
    /// 获取等待/下载中的任务
    var activeTasks: [ChapterDownloadTask] {
        downloadTasks.filter { $0.state == .waiting || $0.state == .downloading }
    }
    
    /// 获取已完成的任务
    var completedTasks: [ChapterDownloadTask] {
        downloadTasks.filter { $0.state == .completed }
    }
    
    /// 获取失败的任务
    var failedTasks: [ChapterDownloadTask] {
        downloadTasks.filter { $0.state == .failed }
    }
    
    /// 返回某章节最近一个下载任务（按追加顺序）
    func latestTask(for chapter: MangaChapter) -> ChapterDownloadTask? {
        downloadTasks.last { $0.chapter.id == chapter.id }
    }
    
    /// 该章节是否已有活跃下载任务
    func hasActiveTask(for chapter: MangaChapter) -> Bool {
        guard let task = latestTask(for: chapter) else { return false }
        return task.state == .waiting || task.state == .downloading
    }

    func isChapterDownloadable(_ chapter: MangaChapter) -> Bool {
        chapter.isFree
    }
    
    // MARK: - 兼容旧接口
    
    /// 下载选中的章节（兼容旧代码）
    func downloadChapters(_ chapters: [MangaChapter]) async {
        for chapter in chapters {
            await downloadChapter(chapter)
        }
    }
}

/// 下载任务状态
enum DownloadTaskState: String {
    case waiting = "等待中"
    case downloading = "下载中"
    case paused = "已暂停"
    case completed = "已完成"
    case failed = "失败"
}

/// 章节下载任务
struct ChapterDownloadTask: Identifiable {
    let id: UUID
    let chapter: MangaChapter
    let manga: Manga
    let format: DownloadFormat
    var progress: Double
    var state: DownloadTaskState
    var error: String?
    
    var title: String {
        chapter.title
    }
    
    var sizeText: String {
        String(format: "%.1f MB", chapter.sizeMB)
    }
    
    var progressText: String {
        "\(Int(progress * 100))%"
    }
}
