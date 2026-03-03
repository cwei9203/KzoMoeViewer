import SwiftUI

struct StatusChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : AppTheme.Colors.textSecondary)
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.background)
            )
    }
}
