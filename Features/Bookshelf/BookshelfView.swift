import SwiftUI

struct BookshelfView: View {
    @StateObject private var viewModel = BookshelfViewModel()
    @State private var keyword = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 110), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                searchBar
                grid
            }
            .padding(AppTheme.Spacing.l)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task {
                if keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await viewModel.refresh()
                } else {
                    await viewModel.search(keyword: keyword)
                }
            }
        }
        .refreshable {
            if keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await viewModel.refresh()
            } else {
                await viewModel.search(keyword: keyword)
            }
        }
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
                .onChange(of: isSearchFocused) { focused in
                    if !focused {
                        triggerSearch()
                    }
                }
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            if !viewModel.isLoading && viewModel.mangas.isEmpty {
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
                    }
                }
            }
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
