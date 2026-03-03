import SwiftUI

struct MangaGridCard: View {
    let manga: Manga
    private let coverAspect: CGFloat = 142.0 / 202.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                coverView

                Text(manga.status)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.Colors.textPrimary))
                    .foregroundStyle(.white)
                    .padding(8)
            }

            Text(manga.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(manga.author)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(AppTheme.Colors.textMuted)

            if let updateInfo = manga.updateInfo, !updateInfo.isEmpty {
                Text(updateInfo)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
    }

    @ViewBuilder
    private var coverView: some View {
        if let coverURL = manga.coverURL {
            RemoteCoverImage(urlString: coverURL, referer: "https://kzo.moe/")
            .aspectRatio(coverAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                ratingBadge
            }
        } else {
            placeholderCover
                .overlay(alignment: .bottomTrailing) {
                    ratingBadge
                }
        }
    }

    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: [.blue.opacity(0.25), .cyan.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .aspectRatio(coverAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(
                Image(systemName: manga.coverName)
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.Colors.primary)
            )
    }

    @ViewBuilder
    private var ratingBadge: some View {
        if let rating = manga.ratingText, !rating.isEmpty {
            Text(rating)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xF97316), Color(hex: 0xEF4444)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white, lineWidth: 1.2)
                )
                .foregroundStyle(.white)
                .padding(8)
        }
    }
}
