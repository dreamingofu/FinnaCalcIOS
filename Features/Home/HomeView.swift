//
//  HomeView.swift
//  FinnaCalcIOS
//
//  Landing tab. Phase 8 fleshes out the financial-education hub / marketing
//  content; for now it welcomes the user and orients them to the sections.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthManager

    private let sections: [(icon: String, title: String, blurb: String)] = [
        ("wallet.bifold", "Budgeting", "Connect accounts and get AI budget guidance."),
        ("chart.line.uptrend.xyaxis", "Investing", "Markets, brokerages, and your portfolio."),
        ("doc.text", "Taxes", "Calculators, education, and e-filing."),
        ("book", "Education", "Learn the money concepts behind it all."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FCWordmark(size: 34)

                Text(auth.user.map { "Welcome back, \($0.displayName)." } ?? "Smarter money decisions, calculated.")
                    .font(.system(size: Theme.FontSize.base))
                    .foregroundStyle(Theme.mutedForeground)

                ForEach(sections, id: \.title) { section in
                    FCCard {
                        FCCardHeader {
                            HStack(spacing: 12) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Theme.primary)
                                FCCardTitle(section.title)
                            }
                            FCCardDescription(section.blurb)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    HomeView().environmentObject(AuthManager())
}
