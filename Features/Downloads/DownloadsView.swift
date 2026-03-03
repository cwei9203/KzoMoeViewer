import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.l) {
                storageCard
                downloadingCard
                completedCard
            }
            .padding(AppTheme.Spacing.l)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var storageCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("DEVICE STORAGE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("24.5 GB")
                        .font(.title.weight(.bold))
                    Text("Free")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Spacer()
                    Text("75% Used")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                ProgressView(value: viewModel.usedRatio)
                    .tint(AppTheme.Colors.primary)

                Text("Vol.moe is using 4.2GB of your storage.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
    }

    private var downloadingCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("DOWNLOADING (\(viewModel.downloadingTasks.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textMuted)
                ForEach(Array(viewModel.downloadingTasks.enumerated()), id: \.element.id) { index, task in
                    downloadRow(task: task)
                    if index < viewModel.downloadingTasks.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var completedCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("COMPLETED")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textMuted)
                ForEach(viewModel.completedTasks) { task in
                    completedRow(task: task)
                }
            }
        }
    }

    private func downloadRow(task: DownloadTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.Colors.background)
                    .frame(width: 38, height: 50)
                    .overlay(Image(systemName: "book").foregroundStyle(AppTheme.Colors.primary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.subheadline.weight(.semibold))
                    Text(task.detailText).font(.caption).foregroundStyle(AppTheme.Colors.textMuted)
                }
                Spacer()
                Button(action: { viewModel.togglePauseResume(taskID: task.id) }) {
                    Image(systemName: task.state == .downloading ? "pause.circle" : "play.circle")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            HStack {
                ProgressView(value: task.progress)
                    .tint(task.state == .downloading ? AppTheme.Colors.success : AppTheme.Colors.warning)
                Text(task.speedText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(task.state == .downloading ? AppTheme.Colors.success : AppTheme.Colors.textMuted)
            }
        }
    }

    private func completedRow(task: DownloadTask) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppTheme.Colors.background)
                .frame(width: 38, height: 50)
                .overlay(Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.Colors.primary))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.subheadline.weight(.semibold))
                Text("\(Int(task.totalMB)) MB    \(task.dateText)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
            Spacer()
            Button(action: { viewModel.removeCompleted(taskID: task.id) }) {
                Image(systemName: "trash")
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
    }
}
