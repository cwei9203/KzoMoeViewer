import SwiftUI

struct BookshelfView: View {
    @StateObject private var viewModel = BookshelfViewModel()
    @State private var keyword = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10),
        count: 3
    )

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.l, pinnedViews: [.sectionHeaders]) {
                    Section {
                        grid
                    } header: {
                        stickySearchHeader
                            .zIndex(10)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.bottom, AppTheme.Spacing.l)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Task {
                await viewModel.loadInitialIfNeeded()
            }
        }
        .refreshable {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                await viewModel.refresh()
            } else {
                await viewModel.search(keyword: trimmed)
            }
        }
    }

    private var stickySearchHeader: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.top, AppTheme.Spacing.s)
                .padding(.bottom, AppTheme.Spacing.s)
        }
        .background(AppTheme.Colors.background)
        .overlay(alignment: .top) {
            AppTheme.Colors.background
                .frame(height: topSafeAreaInset)
                .offset(y: -topSafeAreaInset)
        }
    }

    private var topSafeAreaInset: CGFloat {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: \.isKeyWindow)
        else {
            return 0
        }
        return window.safeAreaInsets.top
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.Colors.textMuted)
            TextField("Search manga, authors...", text: $keyword)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
                .onSubmit {
                    triggerSearch()
                }
            Spacer()
            if keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                Button {
                    keyword = ""
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
        )
        .appCard()
    }

    private var grid: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            if viewModel.isLoading && viewModel.mangas.isEmpty {
                LazyVGrid(columns: columns, spacing: AppTheme.Spacing.m) {
                    ForEach(0..<12, id: \.self) { _ in
                        skeletonCard
                    }
                }
            } else if !viewModel.isLoading && viewModel.mangas.isEmpty {
                CardContainer {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("没有匹配结果")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("请更换关键词，或清空搜索后查看首页列表。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: AppTheme.Spacing.m) {
                    ForEach(viewModel.mangas) { manga in
                        NavigationLink(destination: DetailView(manga: manga)) {
                            MangaGridCard(manga: manga)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            Task {
                                await viewModel.loadNextIfNeeded(currentItem: manga)
                            }
                        }
                    }
                }
                loadMoreFooter
            }
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: 0xE2E8F0))
                .aspectRatio(142.0 / 202.0, contentMode: .fit)
                .modifier(SkeletonShimmer())

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: 0xE2E8F0))
                .frame(height: 12)
                .modifier(SkeletonShimmer())

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: 0xE2E8F0))
                .frame(width: 56, height: 10)
                .modifier(SkeletonShimmer())
        }
        .opacity(0.95)
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.top, AppTheme.Spacing.s)
        } else if !viewModel.hasMore && !viewModel.mangas.isEmpty {
            Text("没有更多了")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.Spacing.s)
        }
    }

    private func triggerSearch() {
        Task {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == viewModel.currentKeyword {
                return
            }
            if trimmed.isEmpty {
                await viewModel.refresh()
            } else {
                await viewModel.search(keyword: trimmed)
            }
        }
    }
}

private struct SkeletonShimmer: ViewModifier {
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let width = max(proxy.size.width, 1)
                    let highlightWidth = width * 1.8

                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.16),
                            .white.opacity(0.38),
                            .white.opacity(0.16),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: highlightWidth)
                    .offset(x: phase * width * 1.6)
                }
                .mask(content)
                .allowsHitTesting(false)
            }
            .onAppear {
                phase = -1.2
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .onDisappear {
                phase = -1.2
            }
    }
}
