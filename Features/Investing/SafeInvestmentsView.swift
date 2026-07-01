//
//  SafeInvestmentsView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/components/safe-investment-options.tsx`.
//
//  An informational list of safe investment options (index funds, high-yield
//  savings, etc.) with their average return, risk level, minimum investment,
//  and an "Invest Now" link out to the provider. Drives no calculation — it is
//  a static reference list, matching the web component faithfully.
//
//  The `onBack` prop from the web is intentionally dropped: drill-down here is
//  driven by the surrounding NavigationStack (RootView wraps the Investing tab).
//

import SwiftUI

// MARK: - Model

/// One row of the safe-investments list — mirrors the `safeInvestments` array
/// literal in safe-investment-options.tsx.
private struct SafeInvestment: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let avgReturn: String
    let risk: String
    let description: String
    let minInvestment: String
    let link: String
}

// MARK: - SafeInvestmentsView

struct SafeInvestmentsView: View {

    // Ported 1:1 from the `safeInvestments` array in the web component.
    private let safeInvestments: [SafeInvestment] = [
        SafeInvestment(
            name: "S&P 500 Index Fund (IVV)",
            symbol: "IVV",
            avgReturn: "10.5%",
            risk: "Low-Medium",
            description: "Tracks the 500 largest US companies.",
            minInvestment: "$1",
            link: "https://www.ishares.com/us/products/239726/ishares-core-sp-500-etf"
        ),
        SafeInvestment(
            name: "Total Stock Market (VTI)",
            symbol: "VTI",
            avgReturn: "10.2%",
            risk: "Low-Medium",
            description: "Owns the entire US stock market.",
            minInvestment: "$1",
            link: "https://investor.vanguard.com/investment-products/etfs/profile/vti"
        ),
        SafeInvestment(
            name: "High-Yield Savings",
            symbol: "HYSA",
            avgReturn: "4.5%+",
            risk: "None",
            description: "FDIC insured savings account.",
            minInvestment: "$0",
            link: "https://www.nerdwallet.com/best/banking/high-yield-online-savings-accounts"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { // space-y-6

                // ── Header ──
                VStack(alignment: .leading, spacing: 4) {
                    Text("Safe Investment Options") // text-2xl font-bold
                        .font(Theme.sans(Theme.FontSize.xl2, weight: .bold))
                        .foregroundColor(Theme.foreground)
                    Text("Top safest investments with consistent returns")
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                }

                // ── Disclaimer ──
                disclaimerCard

                // ── Investment list ──
                FCCard {
                    // CardContent p-0 — rows handle their own padding, divided by
                    // hairline separators (divide-y).
                    VStack(spacing: 0) {
                        ForEach(Array(safeInvestments.enumerated()), id: \.element.id) { index, investment in
                            investmentRow(investment)
                            if index < safeInvestments.count - 1 {
                                Divider().background(Theme.border)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .navigationTitle("Safe Investments")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Disclaimer card

    // Stands in for the web "{/* ... (Disclaimer cards) ... */}" block: an
    // informational note that this list is educational, not financial advice.
    private var disclaimerCard: some View {
        FCCard {
            FCCardContent {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "shield.fill") // Shield (lucide)
                        .font(Theme.sans(18))
                        .foregroundColor(Theme.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Educational, not financial advice")
                            .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                            .foregroundColor(Theme.foreground)
                        Text("Average returns are historical and not guaranteed. All investing carries risk, including the possible loss of principal. Do your own research before investing.")
                            .font(Theme.sans(Theme.FontSize.xs))
                            .foregroundColor(Theme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 24) // restore the p-6 top padding (FCCardContent has pt-0)
            }
        }
    }

    // MARK: - Investment row

    @ViewBuilder
    private func investmentRow(_ investment: SafeInvestment) -> some View {
        HStack(alignment: .top, spacing: 16) {

            // Left: icon + info
            HStack(alignment: .top, spacing: 16) {
                // w-10 h-10 bg-blue-100 rounded-full + TrendingUp blue icon
                ZStack {
                    Circle()
                        .fill(Theme.primary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.line.uptrend.xyaxis") // TrendingUp
                        .font(Theme.sans(18, weight: .semibold))
                        .foregroundColor(Theme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(investment.name) // font-semibold
                        .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                        .foregroundColor(Theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(investment.description) // text-sm text-muted-foreground
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) { // gap-3 mt-1
                        riskBadge(investment.risk)
                        Text("Min: \(investment.minInvestment)")
                            .font(Theme.sans(Theme.FontSize.xs))
                            .foregroundColor(Theme.mutedForeground)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: avg return + Invest Now
            VStack(alignment: .trailing, spacing: 8) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(investment.avgReturn) // text-lg font-bold text-green-600
                        .font(Theme.sans(18, weight: .bold))
                        .foregroundColor(Theme.positive)
                    Text("avg return")
                        .font(Theme.sans(Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                }

                if let url = URL(string: investment.link) {
                    Link(destination: url) {
                        FCButtonLabel(title: "Invest Now")
                    }
                }
            }
        }
        .padding(16) // p-4
    }

    // MARK: - Risk badge

    // Mirrors `getRiskColor` in the web component, which renders each risk level
    // as a soft tinted badge (`bg-*-100 text-*-700`). FCBadge fixes its own
    // foreground per variant, so the colored cases are rendered as a custom
    // capsule (tinted fill + colored text); the default falls back to FCBadge.
    @ViewBuilder
    private func riskBadge(_ risk: String) -> some View {
        if let color = riskColor(risk) {
            Text(risk)
                .font(Theme.sans(Theme.FontSize.xs, weight: .semibold)) // text-xs font-semibold
                .foregroundColor(color)          // text-*-700
                .padding(.horizontal, 10)        // px-2.5
                .padding(.vertical, 2)           // py-0.5
                .background(color.opacity(0.15)) // bg-*-100
                .clipShape(Capsule())            // rounded-full
        } else {
            FCBadge(risk, variant: .secondary)
        }
    }

    /// `getRiskColor` hue mapping:
    /// None / Very Low → green, Low → blue, Low-Medium → amber, Medium → orange.
    /// Returns nil for the default (muted) case.
    private func riskColor(_ risk: String) -> Color? {
        switch risk {
        case "None", "Very Low": return Theme.positive       // green
        case "Low":              return Theme.primary         // blue
        case "Low-Medium":       return Self.amber            // yellow/amber
        case "Medium":           return Self.orange           // orange
        default:                 return nil
        }
    }

    // Local hue approximations for Tailwind amber/orange (no Theme token exists).
    private static let amber  = Color(red: 0.71, green: 0.49, blue: 0.04) // amber-700
    private static let orange = Color(red: 0.76, green: 0.34, blue: 0.05) // orange-700
}

// MARK: - Invest Now button label

/// A non-interactive view styled like a small primary `FCButton`, used as the
/// content of a `Link` (so the tap opens the URL rather than running an action).
/// The web wraps `<Button size="sm">` in an `<a target="_blank">`.
private struct FCButtonLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) { // gap-2
            Text(title)
            Image(systemName: "arrow.up.right.square") // ExternalLink
                .imageScale(.small)
        }
        .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
        .foregroundColor(Theme.primaryForeground)
        .frame(height: 36) // h-9 (size="sm")
        .padding(.horizontal, 12) // px-3
        .background(Theme.primary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SafeInvestmentsView()
    }
}
