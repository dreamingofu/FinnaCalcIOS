//
//  MarketsDashboardView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of the markets dashboard. The web reference
//  (components/markets-dashboard.tsx) is a Plaid portfolio view; on iOS this
//  screen is wired to MarketService.marketOverview() per the port spec — it
//  renders a sector-performance chart, market stats, and gainers / losers /
//  most-active lists. Tapping a row drills into StocksPageView for that symbol.
//
//  iOS 16: Swift Charts has no SectorMark/pie, so sector performance uses
//  BarMark (avg change per sector). Colored +/- text uses .foregroundColor.
//

import SwiftUI
import Charts

struct MarketsDashboardView: View {

    private enum Status { case loading, ready, error }

    @State private var status: Status = .loading
    @State private var overview: MarketOverviewResponse?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                switch status {
                case .loading:
                    loadingCard
                case .error:
                    errorCard
                case .ready:
                    if let overview {
                        marketStats(overview)
                        sectorCard(overview.sectorSummary)
                        moverCard(title: "Top Gainers",
                                  subtitle: "Biggest moves up today",
                                  stocks: overview.gainers)
                        moverCard(title: "Top Losers",
                                  subtitle: "Biggest moves down today",
                                  stocks: overview.losers)
                        moverCard(title: "Most Active",
                                  subtitle: "Highest trading volume",
                                  stocks: overview.mostActive)
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Markets")
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Market Overview")
                    .font(Theme.sans(Theme.FontSize.xl2, weight: .bold))
                    .foregroundColor(Theme.foreground)
                Text(timestampLabel)
                    .font(Theme.sans(Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
            Spacer()
            FCButton(variant: .outline, size: .sm) {
                Label("Refresh", systemImage: "arrow.clockwise")
            } action: {
                Task { await load() }
            }
        }
    }

    private var timestampLabel: String {
        guard let ts = overview?.timestamp else { return "Live market data" }
        let date = Date(timeIntervalSince1970: ts > 1_000_000_000_000 ? ts / 1000 : ts)
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return "As of \(fmt.string(from: date))"
    }

    // MARK: - Loading / Error

    private var loadingCard: some View {
        FCCard {
            FCCardContent {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading market data…")
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var errorCard: some View {
        FCCard {
            FCCardContent {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(Theme.sans(28))
                        .foregroundColor(Theme.destructive)
                    Text("Could not load market data")
                        .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                        .foregroundColor(Theme.foreground)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.sans(Theme.FontSize.xs))
                            .foregroundColor(Theme.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    FCButton("Try again", variant: .outline, size: .sm) {
                        Task { await load() }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }

    // MARK: - Market stats

    private func marketStats(_ o: MarketOverviewResponse) -> some View {
        let total = o.stocks.count
        let up = o.stocks.filter { $0.changesPercentage > 0 }.count
        let down = o.stocks.filter { $0.changesPercentage < 0 }.count
        let avg = total > 0 ? o.stocks.map(\.changesPercentage).reduce(0, +) / Double(total) : 0

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(label: "Tracked", value: "\(total)", tint: Theme.primary)
            statTile(label: "Avg Change", value: signedPercent(avg), tint: changeColor(avg))
            statTile(label: "Advancing", value: "\(up)", tint: Theme.positive)
            statTile(label: "Declining", value: "\(down)", tint: Theme.negative)
        }
    }

    private func statTile(label: String, value: String, tint: Color) -> some View {
        FCCard {
            FCCardContent {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(Theme.sans(Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                    Text(value)
                        .font(Theme.sans(Theme.FontSize.xl2, weight: .bold))
                        .foregroundColor(tint)
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Sector performance (BarMark — no pie)

    private func sectorCard(_ sectors: [SectorSummary]) -> some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Sector Performance")
                FCCardDescription("Average change by sector")
            }
            FCCardContent {
                if sectors.isEmpty {
                    Text("No sector data available.")
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                        .padding(.vertical, 12)
                } else {
                    Chart(sectors) { sector in
                        BarMark(
                            x: .value("Change", sector.avgChange),
                            y: .value("Sector", sector.name)
                        )
                        .foregroundStyle(changeColor(sector.avgChange))
                        .annotation(position: sector.avgChange >= 0 ? .trailing : .leading) {
                            Text(signedPercent(sector.avgChange))
                                .font(Theme.sans(10))
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text(CalcFormat.fixed(d, 1) + "%")
                                }
                            }
                        }
                    }
                    .frame(height: CGFloat(max(sectors.count, 1)) * 34 + 24)
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Mover lists

    private func moverCard(title: String, subtitle: String, stocks: [MarketQuote]) -> some View {
        FCCard {
            FCCardHeader {
                FCCardTitle(title)
                FCCardDescription(subtitle)
            }
            FCCardContent {
                if stocks.isEmpty {
                    Text("No data available.")
                        .font(Theme.sans(Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(stocks.enumerated()), id: \.element.id) { index, stock in
                            NavigationLink {
                                StocksPageView(initialSymbol: stock.symbol)
                            } label: {
                                moverRow(stock)
                            }
                            .buttonStyle(.plain)
                            if index < stocks.count - 1 {
                                Divider().background(Theme.border)
                            }
                        }
                    }
                }
            }
        }
    }

    private func moverRow(_ stock: MarketQuote) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stock.symbol)
                    .font(Theme.sans(Theme.FontSize.sm, weight: .bold))
                    .foregroundColor(Theme.foreground)
                Text(stock.name)
                    .font(Theme.sans(Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(CalcFormat.currency(stock.price))
                    .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                    .foregroundColor(Theme.foreground)
                Text(signedPercent(stock.changesPercentage))
                    .font(Theme.sans(Theme.FontSize.xs, weight: .semibold))
                    .foregroundColor(changeColor(stock.changesPercentage))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func changeColor(_ n: Double) -> Color {
        n > 0 ? Theme.positive : n < 0 ? Theme.negative : Theme.mutedForeground
    }

    private func signedPercent(_ n: Double) -> String {
        (n >= 0 ? "+" : "") + CalcFormat.fixed(n, 2) + "%"
    }

    // MARK: - Data

    private func load() async {
        Task { @MainActor in
            status = .loading
            errorMessage = nil
        }
        do {
            let result = try await MarketService.marketOverview()
            Task { @MainActor in
                overview = result
                status = .ready
            }
        } catch {
            let message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            Task { @MainActor in
                errorMessage = message
                status = .error
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MarketsDashboardView()
    }
}
