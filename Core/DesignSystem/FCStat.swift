//
//  FCStat.swift
//  FinnaCalcIOS
//
//  Stat / ResultRow — the calculator output components from the renovated design
//  system. `FCStat` is the headline figure; `FCResultRow` is one labeled line in
//  the breakdown. Both render values in the mono figure font with green/red tone
//  for gains/costs — the design's signature ("figures are the heroes").
//

import SwiftUI

/// Result tone — gains/payments (positive) vs costs/interest (negative).
enum FCResultTone {
    case neutral, positive, negative
    var color: Color {
        switch self {
        case .neutral:  return Theme.foreground
        case .positive: return Theme.positive
        case .negative: return Theme.negative
        }
    }
}

/// The headline calculator figure (monthly payment, true APR, …).
struct FCStat: View {
    enum Size {
        case small, medium, large
        var point: CGFloat {
            switch self {
            case .small:  return Theme.FontSize.xl2  // 24 — compact KPI tiles
            case .medium: return Theme.FontSize.xl3  // 30
            case .large:  return Theme.FontSize.xl4  // 36 — headline
            }
        }
    }

    let label: String
    let value: String
    var tone: FCResultTone = .neutral
    var size: Size = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Theme.sans(Theme.FontSize.xs, weight: .semibold))
                .tracking(0.6) // overline: uppercase, wide-tracked
                .foregroundStyle(Theme.mutedForeground)
            Text(value)
                .font(Theme.figure(size.point, weight: .bold))
                .foregroundStyle(tone.color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One labeled line in a result breakdown — label left, mono figure right.
struct FCResultRow: View {
    let label: String
    let value: String
    var tone: FCResultTone = .neutral
    var emphasized: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Theme.sans(Theme.FontSize.sm))
                .foregroundStyle(Theme.mutedForeground)
            Spacer(minLength: 12)
            Text(value)
                .font(Theme.figure(Theme.FontSize.sm, weight: emphasized ? .bold : .medium))
                .foregroundStyle(tone == .neutral && emphasized ? Theme.foreground : tone.color)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        FCStat(label: "Payment per period", value: "$1,204.55", tone: .positive, size: .large)
        FCResultRow(label: "Total interest cost", value: "$12,273.00", tone: .negative)
        FCResultRow(label: "Principal financed", value: "$50,000.00", emphasized: true)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Theme.background)
}
