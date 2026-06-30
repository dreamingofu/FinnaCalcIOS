//
//  ComingSoonView.swift
//  FinnaCalcIOS
//
//  Shared placeholder for the feature tabs whose real content lands in later
//  phases. Built on the Phase 1 design system so the shell already reads like
//  FinnaCalc.
//

import SwiftUI

struct ComingSoonView: View {
    let icon: String
    let title: String
    let message: String
    let phase: String

    var body: some View {
        ScrollView {
            FCCard {
                FCCardHeader {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                        FCCardTitle(title)
                    }
                    FCCardDescription(message)
                }
                FCCardContent {
                    FCBadge(phase, variant: .secondary)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    ComingSoonView(
        icon: "chart.line.uptrend.xyaxis",
        title: "Investing",
        message: "Markets, brokerage connections, and your portfolio will live here.",
        phase: "Coming in Phase 5"
    )
}
