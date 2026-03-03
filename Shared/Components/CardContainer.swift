import SwiftUI

struct CardContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppTheme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .appCard()
    }
}
