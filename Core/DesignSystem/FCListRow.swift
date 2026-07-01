//
//  FCListRow.swift
//  FinnaCalcIOS
//
//  ListRow / IconChip — the standard navigation row from the renovated design
//  system (calculator hub, "Research & Learn", education topics). A brand-tinted
//  IconChip fronts a title + subtitle, with a trailing chevron by default.
//

import SwiftUI

/// A rounded, tinted square holding an SF Symbol — the brand-blue icon chip.
struct FCIconChip: View {
    let systemName: String
    var tone: FCResultTone = .neutral
    var size: CGFloat = 40

    private var foreground: Color {
        switch tone {
        case .neutral:  return Theme.primary
        case .positive: return Theme.positive
        case .negative: return Theme.negative
        }
    }
    private var background: Color {
        switch tone {
        case .neutral:  return Theme.brandTint
        case .positive: return Theme.positive.opacity(0.12)
        case .negative: return Theme.negative.opacity(0.12)
        }
    }

    var body: some View {
        Image(systemName: systemName)
            .font(Theme.sans(size * 0.45, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

/// A navigation row: icon chip + title/subtitle + trailing accessory.
struct FCListRow<Trailing: View>: View {
    let icon: String
    var iconTone: FCResultTone = .neutral
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            FCIconChip(systemName: icon, tone: iconTone)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundStyle(Theme.mutedForeground)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

extension FCListRow where Trailing == Image {
    /// Default trailing chevron (the common "navigates somewhere" row).
    init(icon: String, iconTone: FCResultTone = .neutral, title: String, subtitle: String? = nil) {
        self.init(icon: icon, iconTone: iconTone, title: title, subtitle: subtitle) {
            Image(systemName: "chevron.right")
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        FCListRow(icon: "banknote", title: "Loan Calculator",
                  subtitle: "Payments, true APR, and remaining balances")
        Divider()
        FCListRow(icon: "chart.line.uptrend.xyaxis", iconTone: .positive, title: "AAPL", subtitle: "Apple Inc.") {
            FCBadge("+1.8%", variant: .positive, dot: true)
        }
    }
    .background(Theme.card)
    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.background)
}
