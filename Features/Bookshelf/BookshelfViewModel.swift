import Foundation

@MainActor
final class BookshelfViewModel: ObservableObject {
    @Published private(set) var mangas: [Manga] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    @Published private(set) var currentKeyword: String = ""

    private let service: MangaServicing
    private var requestID: UInt64 = 0
    private var nextPage: Int = 1
    private var seenKeys = Set<String>()
    private var hasLoadedInitially = false

    init(service: MangaServicing = MangaService()) {
        self.service = service
    }

    func loadInitialIfNeeded() async {
        guard !hasLoadedInitially else { return }
        hasLoadedInitially = true

        if currentKeyword.isEmpty {
            await startQuery(keyword: "")
        } else {
            await startQuery(keyword: currentKeyword)
        }
    }

    func refresh() async {
        await startQuery(keyword: "")
    }

    func search(keyword: String) async {
        await startQuery(keyword: keyword)
    }

    func loadNextIfNeeded(currentItem: Manga?) async {
        guard !isLoading, !isLoadingMore, hasMore else { return }
        guard shouldLoadMore(currentItem: currentItem) else { return }

        isLoadingMore = true
        let currentRequest = requestID
        let pageToLoad = nextPage
        let keyword = currentKeyword
        defer {
            if currentRequest == requestID {
                isLoadingMore = false
            }
        }

        let result: [Manga]
        if keyword.isEmpty {
            result = await service.loadBookshelf(page: pageToLoad)
        } else {
            result = await service.searchBooks(keyword: keyword, page: pageToLoad)
        }

        guard currentRequest == requestID else { return }

        if result.isEmpty {
            hasMore = false
            return
        }

        appendUnique(result)
        nextPage += 1
    }

    private func startQuery(keyword: String) async {
        requestID &+= 1
        let currentRequest = requestID

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        isLoadingMore = false
        hasMore = true
        nextPage = 1
        mangas = []
        seenKeys.removeAll()
        currentKeyword = trimmed

        let result: [Manga]
        if trimmed.isEmpty {
            result = await service.loadBookshelf(page: 1)
        } else {
            result = await service.searchBooks(keyword: trimmed, page: 1)
        }

        guard currentRequest == requestID else { return }
        appendUnique(result)
        hasMore = !result.isEmpty
        nextPage = 2
        if result.isEmpty {
            hasMore = false
        }
        isLoading = false
    }

    private func shouldLoadMore(currentItem: Manga?) -> Bool {
        guard let currentItem else { return mangas.isEmpty }
        guard let index = mangas.firstIndex(where: { $0.id == currentItem.id }) else { return false }
        let thresholdIndex = max(0, mangas.count - 6)
        return index >= thresholdIndex
    }

    private func appendUnique(_ incoming: [Manga]) {
        for manga in incoming {
            let key = makeKey(for: manga)
            if seenKeys.insert(key).inserted {
                mangas.append(manga)
            }
        }
    }

    private func makeKey(for manga: Manga) -> String {
        let title = manga.title
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let author = manga.author
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(manga.path ?? "")|\(title)|\(author)"
    }
}
