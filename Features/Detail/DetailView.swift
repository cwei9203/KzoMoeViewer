import SwiftUI
import UIKit

struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel
    @State private var isSynopsisExpanded = false
    @State private var synopsisCanExpand = false
    @State private var synopsisTextWidth: CGFloat = 0

    init(manga: Manga) {
        _viewModel = StateObject(wrappedValue: DetailViewModel(manga: manga))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                heroCard
                synopsis
                downloadProgressSection
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
        .alert("下载错误", isPresented: .init(
            get: { viewModel.downloadError != nil },
            set: { if !$0 { viewModel.downloadError = nil } }
        )) {
            Button("确定") {
                viewModel.downloadError = nil
            }
        } message: {
            Text(viewModel.downloadError ?? "")
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

    // MARK: - Hero Card
    private var heroCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    detailCover
                        .frame(width: 106, height: 148)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(viewModel.detail.manga.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .lineLimit(2)
                            if viewModel.detail.isColor {
                                textBadge("彩色", bg: Color(hex: 0xF97316), fg: .white)
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
                            textBadge(viewModel.detail.manga.status, bg: Color(hex: 0xEEF2FF), fg: Color(hex: 0x334155))
                            if valueExists(viewModel.detail.updateDate) {
                                textBadge("更新 \(viewModel.detail.updateDate)", bg: Color(hex: 0xEEF2FF), fg: Color(hex: 0x334155))
                            }
                            Spacer(minLength: 0)
                            ratingBadge
                        }

                        if !heroMetaLine.isEmpty {
                            Text(heroMetaLine)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }

                        if valueExists(viewModel.detail.lastPublish) {
                            Text("最后出版 \(displayValue(viewModel.detail.lastPublish))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                                .lineLimit(1)
                        }
                    }
                }

                HStack(spacing: 0) {
                    ForEach(Array(heroMetrics.enumerated()), id: \.offset) { index, metric in
                        metricInline(label: metric.label, value: metric.value)
                        if index < heroMetrics.count - 1 {
                            Divider()
                                .frame(height: 24)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: 0xF8FAFC))
                )

                if !viewModel.detail.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.detail.tags, id: \.self) { tag in
                                textBadge(tag, bg: Color(hex: 0xEEF2FF), fg: Color(hex: 0x334155))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Detail Cover
    @ViewBuilder
    private var detailCover: some View {
        if let coverURL = viewModel.detail.manga.coverURL {
            RemoteCoverImage(urlString: coverURL, referer: "https://kzo.moe/")
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0xE2E8F0))
                .overlay(Image(systemName: viewModel.detail.manga.coverName).font(.system(size: 40)).foregroundStyle(AppTheme.Colors.primary))
        }
    }

    private var ratingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(String(format: "%.1f", viewModel.detail.rating))
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Color(hex: 0xB45309))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(hex: 0xFEF3C7))
        )
    }

    private var heroMetaLine: String {
        let entries = [
            displayValue(viewModel.detail.region),
            displayValue(viewModel.detail.language),
            displayValue(viewModel.detail.version)
        ]
        .filter { $0 != "--" }
        return entries.joined(separator: " · ")
    }

    private var heroMetrics: [(label: String, value: String)] {
        var metrics: [(label: String, value: String)] = []
        if valueExists(viewModel.detail.subscribed) {
            metrics.append(("订阅", viewModel.detail.subscribed))
        }
        metrics.append(("收藏", displayValue(viewModel.detail.favorited)))
        metrics.append(("读过", displayValue(viewModel.detail.readCount)))
        metrics.append(("热度", displayValue(viewModel.detail.heat)))
        return metrics
    }

    // MARK: - Inline Metric
    private func metricInline(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    // MARK: - Badge
    private func textBadge(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(bg)
            )
            .foregroundStyle(fg)
    }

    // MARK: - Value Exists
    private func valueExists(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "--"
    }

    // MARK: - Display Value
    private func displayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "--" : trimmed
    }

    // MARK: - Synopsis
    private var synopsis: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Label("简介", systemImage: "text.alignleft")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if viewModel.detail.summary.isEmpty {
                    Text("暂无简介数据")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        Text(viewModel.detail.summary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .lineSpacing(3)
                            .lineLimit(isSynopsisExpanded ? nil : 2)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .onAppear {
                                            synopsisTextWidth = proxy.size.width
                                            updateSynopsisExpandState(for: proxy.size.width)
                                        }
                                        .onChange(of: proxy.size.width) { newWidth in
                                            synopsisTextWidth = newWidth
                                            updateSynopsisExpandState(for: newWidth)
                                        }
                                }
                            )

                        if synopsisCanExpand {
                            if !isSynopsisExpanded {
                                LinearGradient(
                                    colors: [
                                        AppTheme.Colors.card.opacity(0),
                                        AppTheme.Colors.card.opacity(0.92),
                                        AppTheme.Colors.card
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 30)
                                .frame(maxWidth: .infinity, alignment: .bottom)
                                .allowsHitTesting(false)
                            }

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSynopsisExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(isSynopsisExpanded ? "收起" : "展开全文")
                                    Image(systemName: isSynopsisExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .shadow(color: AppTheme.Colors.card, radius: 2, x: 0, y: 0)
                            .padding(.trailing, 4)
                            .padding(.bottom, 2)
                            .offset(y: 8)
                        }
                    }
                    .padding(.bottom, synopsisCanExpand ? 8 : 0)
                }
            }
            .onChange(of: viewModel.detail.summary) { _ in
                updateSynopsisExpandState(for: synopsisTextWidth)
                if !synopsisCanExpand {
                    isSynopsisExpanded = false
                }
            }
        }
    }

    // MARK: - Download Progress Section
    @ViewBuilder
    private var downloadProgressSection: some View {
        if !viewModel.downloadTasks.isEmpty {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("下载管理")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        if !viewModel.completedTasks.isEmpty {
                            Button("清除已完成") {
                                viewModel.clearCompletedTasks()
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.primary)
                        }
                    }
                    
                    ForEach(viewModel.downloadTasks) { task in
                        downloadTaskRow(task)
                    }
                }
            }
        }
    }

    private func downloadTaskRow(_ task: ChapterDownloadTask) -> some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: stateIcon(for: task.state))
                .font(.title3)
                .foregroundStyle(stateColor(for: task.state))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(task.sizeText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    
                    if task.state == .downloading {
                        Text(task.progressText)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.primary)
                    } else {
                        Text(task.state.rawValue)
                            .font(.caption)
                            .foregroundStyle(stateColor(for: task.state))
                    }
                }
                
                // 进度条
                if task.state == .downloading {
                    ProgressView(value: task.progress)
                        .tint(AppTheme.Colors.primary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                switch task.state {
                case .downloading:
                    Button {
                        viewModel.pauseDownload(task.id)
                    } label: {
                        Image(systemName: "pause.circle")
                            .font(.title3)
                    }
                    
                case .paused:
                    Button {
                        Task {
                            await viewModel.resumeDownload(task.id)
                        }
                    } label: {
                        Image(systemName: "play.circle")
                            .font(.title3)
                    }
                    
                case .failed:
                    Button {
                        Task {
                            await viewModel.resumeDownload(task.id)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title3)
                    }
                    
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    
                case .waiting:
                    EmptyView()
                }
                
                Button {
                    viewModel.cancelDownload(task.id)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stateIcon(for state: DownloadTaskState) -> String {
        switch state {
        case .waiting: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        }
    }

    private func stateColor(for state: DownloadTaskState) -> Color {
        switch state {
        case .waiting: return .gray
        case .downloading: return AppTheme.Colors.primary
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }

    // MARK: - Chapters
    private var chapters: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                chapterHeader

                if viewModel.detail.chapters.isEmpty {
                    Text("暂无章节数据")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.detail.chapters.enumerated()), id: \.element.id) { index, chapter in
                            chapterRow(chapter: chapter)
                            if index < viewModel.detail.chapters.count - 1 {
                                Divider()
                                    .padding(.leading, viewModel.isSelectionMode ? 34 : 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private var chapterHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(chapterSectionTitle, systemImage: "list.bullet.rectangle.portrait")
                    .font(.headline.weight(.semibold))
                if !viewModel.detail.chapters.isEmpty {
                    Text("\(viewModel.detail.chapters.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.primary.opacity(0.1))
                        )
                }

                Spacer()
            }

            HStack(spacing: 8) {
                if viewModel.isSelectionMode {
                    HStack(spacing: 8) {
                        formatPickerButton

                        Button {
                            viewModel.toggleSelectAll()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: viewModel.selectAll ? "checkmark.square.fill" : "square")
                                Text(viewModel.selectAll ? "取消全选" : "全选")
                                    .lineLimit(1)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.selectAll ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(hex: 0xF8FAFC))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(hex: 0xD9E2F2), lineWidth: 1)
                            )
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                    Button {
                        Task {
                            await viewModel.downloadSelectedChapters()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("下载(\(viewModel.selectedCount))")
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(viewModel.hasSelection ? Color(hex: 0x64748B) : Color.gray)
                        )
                    }
                    .disabled(!viewModel.hasSelection)
                    .layoutPriority(1)

                    Button {
                        viewModel.toggleSelectionMode()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("完成")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.Colors.primary)
                        )
                    }
                    }
                } else {
                    formatPickerButton
                    Spacer()
                    Button {
                        viewModel.toggleSelectionMode()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                            Text("批量操作")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(hex: 0xF8FAFC))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(hex: 0xD9E2F2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func chapterRow(chapter: MangaChapter) -> some View {
        HStack(spacing: 10) {
            // 选择框（选择模式时显示，所有章节都展示占位）
            if viewModel.isSelectionMode {
                let canSelect = viewModel.isChapterDownloadable(chapter)
                Button {
                    if canSelect {
                        viewModel.toggleChapterSelection(chapter.id)
                    }
                } label: {
                    Image(systemName: selectionIcon(for: chapter, canSelect: canSelect))
                        .font(.title2)
                        .foregroundStyle(selectionColor(for: chapter, canSelect: canSelect))
                }
                .buttonStyle(.plain)
                .disabled(!canSelect)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayChapterTitle(chapter.title))
                        .font(.subheadline.weight(.semibold))
                    
                    // 新更新标签
                    if chapter.isNew {
                        Text("新")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    Text(chapter.date)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                    
                    if chapter.sizeMB > 0 {
                        Text(String(format: "%.1f MB", chapter.sizeMB))
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    
                    if chapter.pageCount > 0 {
                        Text("\(chapter.pageCount)页")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            if viewModel.isSelectionMode {
                EmptyView()
            } else if viewModel.isChapterDownloadable(chapter) {
                let latestTask = viewModel.latestTask(for: chapter)
                let isBusy = viewModel.hasActiveTask(for: chapter)
                
                Button {
                    Task {
                        await viewModel.downloadChapter(chapter)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: downloadButtonIcon(for: latestTask))
                        Text(downloadButtonTitle(for: latestTask))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isBusy ? AppTheme.Colors.textSecondary : .white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isBusy ? Color(hex: 0xE2E8F0) : AppTheme.Colors.primary)
                    )
                }
                .disabled(isBusy)
            } else {
                statusTag(for: chapter)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            guard viewModel.isSelectionMode, viewModel.isChapterDownloadable(chapter) else { return }
            viewModel.toggleChapterSelection(chapter.id)
        }
    }
    
    private func statusTag(for chapter: MangaChapter) -> some View {
        let title = viewModel.isChapterDownloadable(chapter) ? "可下载" : "不可下载"
        let style: StatusTagStyle = viewModel.isChapterDownloadable(chapter) ? .ready : .inactive
        return statusTag(title: title, style: style)
    }

    private func statusTag(title: String, style: StatusTagStyle) -> some View {
        let fg: Color
        let bg: Color
        switch style {
        case .ready:
            fg = AppTheme.Colors.success
            bg = AppTheme.Colors.success.opacity(0.12)
        case .inactive:
            fg = AppTheme.Colors.textMuted
            bg = Color(hex: 0xE2E8F0)
        }

        return Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(bg))
    }
    
    private func downloadButtonTitle(for task: ChapterDownloadTask?) -> String {
        guard let task else { return "下载" }
        switch task.state {
        case .waiting, .downloading:
            return "下载中"
        case .completed:
            return "已下载"
        case .failed:
            return "重试"
        case .paused:
            return "继续"
        }
    }
    
    private func downloadButtonIcon(for task: ChapterDownloadTask?) -> String {
        guard let task else { return "arrow.down.circle" }
        switch task.state {
        case .waiting, .downloading:
            return "clock"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "arrow.clockwise.circle"
        case .paused:
            return "play.circle"
        }
    }

    private func selectionIcon(for chapter: MangaChapter, canSelect: Bool) -> String {
        guard canSelect else { return "xmark.circle" }
        return viewModel.selectedChapterIDs.contains(chapter.id) ? "checkmark.circle.fill" : "circle"
    }

    private func selectionColor(for chapter: MangaChapter, canSelect: Bool) -> Color {
        guard canSelect else { return AppTheme.Colors.textMuted.opacity(0.45) }
        return viewModel.selectedChapterIDs.contains(chapter.id) ? AppTheme.Colors.primary : AppTheme.Colors.textMuted
    }

    private func formatShortTitle(_ format: DownloadFormat) -> String {
        switch format {
        case .epub: return "EPUB"
        case .mobi: return "MOBI"
        }
    }

    private var formatPickerButton: some View {
        Menu {
            ForEach(DownloadFormat.allCases, id: \.self) { format in
                Button(format.title) {
                    viewModel.selectedFormat = format
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(formatShortTitle(viewModel.selectedFormat))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 82)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0xF8FAFC))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: 0xD9E2F2), lineWidth: 1)
            )
            .foregroundStyle(AppTheme.Colors.primary)
        }
    }

    private var chapterSectionTitle: String {
        let titles = viewModel.detail.chapters.map(\.title)
        return inferredSectionTitle(from: titles)
    }

    private func inferredSectionTitle(from titles: [String]) -> String {
        let joined = titles.joined(separator: " ").lowercased()
        if joined.contains("vol") || joined.contains("volume") || joined.contains("卷") {
            return "Volume"
        }
        return "Chapter"
    }

    private func displayChapterTitle(_ raw: String) -> String {
        let trimmed = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(\S+)\s+\1(\s+|$)"#
        return trimmed.replacingOccurrences(of: pattern, with: "$1 ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateSynopsisExpandState(for width: CGFloat) {
        guard width > 0 else { return }
        let summary = viewModel.detail.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            synopsisCanExpand = false
            return
        }

        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let rect = (summary as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let maxHeight = font.lineHeight * 2
        synopsisCanExpand = ceil(rect.height) > ceil(maxHeight + 1)
        if !synopsisCanExpand {
            isSynopsisExpanded = false
        }
    }
}

private enum StatusTagStyle {
    case ready
    case inactive
}
