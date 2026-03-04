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
    
    // 下载相关字段
    let volID: Int          // 卷ID
    let sizeMB: Double      // 文件大小(MB)
    let pageCount: Int      // 页数
    let isCompleted: Bool   // 是否已完成制作
    let isNew: Bool         // 是否最近更新
    
    init(
        id: Int,
        title: String,
        date: String,
        isFree: Bool,
        volID: Int = 0,
        sizeMB: Double = 0,
        pageCount: Int = 0,
        isCompleted: Bool = false,
        isNew: Bool = false
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.isFree = isFree
        self.volID = volID
        self.sizeMB = sizeMB
        self.pageCount = pageCount
        self.isCompleted = isCompleted
        self.isNew = isNew
    }
}

struct MangaDetail: Hashable {
    let manga: Manga
    let summary: String
    let tags: [String]
    let rating: Double
    let reads: String
    let chapters: [MangaChapter]
    let subtitle: String
    let region: String
    let language: String
    let lastPublish: String
    let updateDate: String
    let version: String
    let scanner: String
    let maintainer: String
    let subscribed: String
    let favorited: String
    let readCount: String
    let heat: String
    let isColor: Bool

    init(
        manga: Manga,
        summary: String,
        tags: [String],
        rating: Double,
        reads: String,
        chapters: [MangaChapter],
        subtitle: String = "",
        region: String = "--",
        language: String = "--",
        lastPublish: String = "--",
        updateDate: String = "--",
        version: String = "--",
        scanner: String = "--",
        maintainer: String = "--",
        subscribed: String = "--",
        favorited: String = "--",
        readCount: String = "--",
        heat: String = "--",
        isColor: Bool = false
    ) {
        self.manga = manga
        self.summary = summary
        self.tags = tags
        self.rating = rating
        self.reads = reads
        self.chapters = chapters
        self.subtitle = subtitle
        self.region = region
        self.language = language
        self.lastPublish = lastPublish
        self.updateDate = updateDate
        self.version = version
        self.scanner = scanner
        self.maintainer = maintainer
        self.subscribed = subscribed
        self.favorited = favorited
        self.readCount = readCount
        self.heat = heat
        self.isColor = isColor
    }
}
