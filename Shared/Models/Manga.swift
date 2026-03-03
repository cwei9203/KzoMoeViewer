import Foundation

struct Manga: Identifiable, Hashable {
    let id: Int
    let title: String
    let author: String
    let coverName: String
    let coverURL: String?
    let ratingText: String?
    let status: String
    let updateInfo: String?
    let path: String?

    init(
        id: Int,
        title: String,
        author: String,
        coverName: String,
        coverURL: String? = nil,
        ratingText: String? = nil,
        status: String,
        updateInfo: String? = nil,
        path: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverName = coverName
        self.coverURL = coverURL
        self.ratingText = ratingText
        self.status = status
        self.updateInfo = updateInfo
        self.path = path
    }
}

struct MangaChapter: Identifiable, Hashable {
    let id: Int
    let title: String
    let date: String
    let isFree: Bool
}

struct MangaDetail: Hashable {
    let manga: Manga
    let summary: String
    let tags: [String]
    let rating: Double
    let reads: String
    let chapters: [MangaChapter]
}
