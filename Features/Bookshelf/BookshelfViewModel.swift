import Foundation

@MainActor
final class BookshelfViewModel: ObservableObject {
    @Published private(set) var mangas: [Manga] = []
    @Published private(set) var isLoading = false
    @Published private(set) var currentKeyword: String = ""

    private let service: MangaServicing
    private var requestID: UInt64 = 0

    init(service: MangaServicing = MangaService()) {
        self.service = service
    }

    func refresh() async {
        requestID &+= 1
        let currentRequest = requestID
        isLoading = true
        let result = await service.loadBookshelf()
        guard currentRequest == requestID else { return }
        mangas = result
        currentKeyword = ""
        isLoading = false
    }

    func search(keyword: String) async {
        requestID &+= 1
        let currentRequest = requestID
        isLoading = true
        let result = await service.searchBooks(keyword: keyword)
        guard currentRequest == requestID else { return }
        mangas = result
        currentKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = false
    }
}
