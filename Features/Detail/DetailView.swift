import SwiftUI

struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel

    init(manga: Manga) {
        _viewModel = StateObject(wrappedValue: DetailViewModel(manga: manga))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                cover
                titleSection
                statsSection
                actionRow
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

    private var cover: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: [.gray.opacity(0.2), .blue.opacity(0.12)], startPoint: .top, endPoint: .bottom))
            .frame(width: 150, height: 190)
            .overlay(Image(systemName: viewModel.detail.manga.coverName).font(.system(size: 60)).foregroundStyle(AppTheme.Colors.primary))
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.detail.manga.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(viewModel.detail.manga.author)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.primary)

            HStack(spacing: 8) {
                ForEach(viewModel.detail.tags, id: \.self) { tag in
                    StatusChip(title: tag, isSelected: false)
                }
            }
        }
    }

    private var statsSection: some View {
        CardContainer {
            HStack {
                statItem(value: String(format: "%.1f", viewModel.detail.rating), label: "RATING")
                Divider()
                statItem(value: "\(viewModel.detail.chapters.count)", label: "CHAPTERS")
                Divider()
                statItem(value: viewModel.detail.reads, label: "READS")
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Button(action: {}) {
                Label("Read Now", systemImage: "book.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: AppTheme.Radius.button, style: .continuous).fill(AppTheme.Colors.primary))
                    .foregroundStyle(.white)
            }

            smallActionButton(symbol: "heart")
            smallActionButton(symbol: "arrow.down")
        }
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
                            tag: chapter.isFree ? "FREE" : "LOCKED"
                        )
                    }
                }
            }
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func smallActionButton(symbol: String) -> some View {
        Button(action: {}) {
            Image(systemName: symbol)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.button, style: .continuous)
                        .fill(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.button, style: .continuous)
                        .stroke(AppTheme.Colors.background, lineWidth: 1)
                )
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
                .foregroundStyle(tag == "FREE" ? AppTheme.Colors.success : AppTheme.Colors.textMuted)
        }
        .padding(.vertical, 6)
    }
}
