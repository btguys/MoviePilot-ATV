//
//  CardButtonStyle.swift
//  MoviePilotTV
//
//  Created on 2025-12-31.
//

import SwiftUI

struct CardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(isFocused ? 4 : 0) // 留出缓冲，避免内部内容顶到边缘
            .background(Color.clear)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: isFocused ? ColorTokens.focusCardGlow : .clear, radius: 12)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var cardButton: CardButtonStyle {
        CardButtonStyle()
    }
}
