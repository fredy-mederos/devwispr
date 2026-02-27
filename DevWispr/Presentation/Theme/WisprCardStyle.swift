//
//  WisprCardStyle.swift
//  DevWispr
//

import SwiftUI

struct WisprCard: ViewModifier {
    var padding: CGFloat = WisprTheme.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(WisprTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: WisprTheme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WisprTheme.cardCornerRadius)
                    .stroke(WisprTheme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func wisprCard(padding: CGFloat = WisprTheme.cardPadding) -> some View {
        modifier(WisprCard(padding: padding))
    }
}
