import Foundation

@MainActor
final class DetailViewModel: ObservableObject {
    @Published private(set) var detail: MangaDetail
    @Published private(set) var isLoading = false

    private let manga: Manga
    private let service: DetailServicing

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
}
