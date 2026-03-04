import SwiftUI

struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel

    init(manga: Manga) {
        _viewModel = StateObject(wrappedValue: DetailViewModel(manga: manga))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                heroCard
                statsSection
                tagsSection
                synopsis
                chapters
            }
            .padding(AppTheme.Spacing.l)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(viewModel.detail.manga.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var heroCard: some View {
        CardContainer {
            HStack(alignment: .top, spacing: 12) {
                detailCover
                    .frame(width: 106, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(viewModel.detail.manga.title)
                            .font(.title.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                        if viewModel.detail.isColor {
                            Text("彩色")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color(hex: 0xF97316)))
                                .foregroundStyle(.white)
                        }
                    }

                    if !viewModel.detail.subtitle.isEmpty {
                        Text(viewModel.detail.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    Text("作者：\(viewModel.detail.manga.author)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    HStack(spacing: 8) {
                        pill(text: viewModel.detail.manga.status)
                        if valueExists(viewModel.detail.updateDate) {
                            pill(text: "更新 \(viewModel.detail.updateDate)")
                        }
                    }

                    infoLine([
                        ("地区", displayValue(viewModel.detail.region)),
                        ("语言", displayValue(viewModel.detail.language)),
                        ("版本", displayValue(viewModel.detail.version))
                    ])

                    infoLine([
                        ("维护", displayValue(viewModel.detail.maintainer)),
                        ("扫者", displayValue(viewModel.detail.scanner)),
                        ("最后出版", displayValue(viewModel.detail.lastPublish))
                    ])

                    HStack(spacing: 10) {
                        Text(String(format: "%.1f", viewModel.detail.rating))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("评分")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var statsSection: some View {
        CardContainer {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                if valueExists(viewModel.detail.subscribed) {
                    metricPill(label: "订阅", value: viewModel.detail.subscribed)
                }
                metricPill(label: "收藏", value: displayValue(viewModel.detail.favorited))
                metricPill(label: "读过", value: displayValue(viewModel.detail.readCount))
                metricPill(label: "热度", value: displayValue(viewModel.detail.heat))
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !viewModel.detail.tags.isEmpty {
            CardContainer {
                VStack(alignment: .leading, spacing: 10) {
                    Text("分类")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                        ForEach(viewModel.detail.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                                        .fill(Color(hex: 0xEEF2FF))
                                )
                                .foregroundStyle(Color(hex: 0x334155))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailCover: some View {
        if let coverURL = viewModel.detail.manga.coverURL {
            RemoteCoverImage(urlString: coverURL, referer: "https://kzo.moe/")
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0xE2E8F0))
                .overlay(Image(systemName: viewModel.detail.manga.coverName).font(.system(size: 40)).foregroundStyle(AppTheme.Colors.primary))
        }
    }

    private func infoLine(_ pairs: [(String, String)]) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                let text = "\(pair.0) \(pair.1)"
                Text(text)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func metricPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(hex: 0xF8FAFC))
        )
    }

    private func pill(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color(hex: 0xEEF2FF))
            )
            .foregroundStyle(Color(hex: 0x334155))
    }

    private func valueExists(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "--"
    }

    private func displayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "--" : trimmed
    }

    private var synopsis: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("Synopsis")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if viewModel.detail.summary.isEmpty {
                    Text("暂无简介数据")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                } else {
                    Text(viewModel.detail.summary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var chapters: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Chapters")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("Sort by Newest")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                if viewModel.detail.chapters.isEmpty {
                    Text("暂无章节数据")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                } else {
                    ForEach(viewModel.detail.chapters) { chapter in
                        chapterRow(
                            title: chapter.title,
                            date: chapter.date,
                            tag: chapter.isFree ? "可下载" : "未开放"
                        )
                    }
                }
            }
        }
    }

    private func chapterRow(title: String, date: String, tag: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(date)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            Spacer()
            Text(tag)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tag == "可下载" ? AppTheme.Colors.success : AppTheme.Colors.textMuted)
        }
        .padding(.vertical, 6)
    }
}
