//
//  DashboardScreenerView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/components/dashboard-screener.tsx`
//  (the "Stock Screener" card). Fetches MarketService.screener() on appear and
//  renders a sortable, filterable list of ScreenerRow with sector / market-cap /
//  performance filters, price range, max P/E and min dividend-yield controls.
//
//  Mobile adaptation: the web's wide HTML table becomes a horizontally
//  scrollable grid with a sticky-feel header row of sort buttons; each data row
//  is a NavigationLink into StocksPageView for the full chart (the web's
//  onSelectSymbol / ChevronRight affordance).
//

import SwiftUI

struct DashboardScreenerView: View {

    // MARK: Sort

    private enum SortKey: String, CaseIterable {
        case symbol, price, changePercent, marketCap, peRatio, dividendYield, beta
    }
    private enum SortDir { case asc, desc }

    // MARK: Filter option lists (mirror the web constants)

    private static let sectors = [
        "All", "Technology", "Communication", "Consumer",
        "Financials", "Healthcare", "Energy", "Industrials",
    ]
    private static let capBuckets = ["All", "Mega (>$200B)", "Large ($10B–$200B)", "Mid (<$10B)"]
    private static let perfOptions = ["All", "Gainers", "Losers"]

    // MARK: Data state

    @State private var rows: [ScreenerRow] = []
    @State private var loading = true
    @State private var error: String?

    // MARK: Filter / sort state

    @State private var sector = "All"
    @State private var cap = "All"
    @State private var perf = "All"
    @State private var minPrice = ""
    @State private var maxPrice = ""
    @State private var maxPe = ""
    @State private var minYield: Double = 0
    @State private var sortKey: SortKey = .marketCap
    @State private var sortDir: SortDir = .desc

    // MARK: Body

    var body: some View {
        ScrollView {
            FCCard {
                header
                FCCardContent {
                    content
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Stock Screener")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .task {
            await load()
        }
    }

    // MARK: Header (title + reset + filter controls)

    private var header: some View {
        FCCardHeader {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                FCCardTitle("Stock Screener")
                Spacer()
                FCButton("Reset filters", variant: .outline, size: .sm) { reset() }
            }

            filters
                .padding(.top, 4)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 16) {
            CalcPicker(
                label: "Sector",
                selection: $sector,
                options: Self.sectors.map { (value: $0, label: $0) }
            )
            CalcPicker(
                label: "Market Cap",
                selection: $cap,
                options: Self.capBuckets.map { (value: $0, label: $0) }
            )
            CalcPicker(
                label: "Performance",
                selection: $perf,
                options: Self.perfOptions.map { (value: $0, label: $0) }
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Price range")
                    .font(.system(size: Theme.FontSize.sm, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                HStack(spacing: 8) {
                    FCTextField("Min", text: $minPrice, keyboardType: .decimalPad)
                    Text("–").foregroundStyle(Theme.mutedForeground)
                    FCTextField("Max", text: $maxPrice, keyboardType: .decimalPad)
                }
            }

            CalcField(label: "Max P/E", placeholder: "Any", text: $maxPe)

            VStack(alignment: .leading, spacing: 6) {
                Text("Min Div Yield: \(CalcFormat.raw(minYield))%")
                    .font(.system(size: Theme.FontSize.sm, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                Slider(value: $minYield, in: 0...5, step: 0.5)
                    .tint(Theme.primary)
            }
        }
    }

    // MARK: Content (loading / error / table)

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if loading {
                VStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .fill(Theme.muted)
                            .frame(height: 40)
                    }
                }
                .padding(.vertical, 8)
            } else if let error {
                Text(error)
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundStyle(Theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                table
            }

            Divider().overlay(Theme.border.opacity(0.6))

            HStack {
                Text(footerLeft)
                Spacer()
                Text("Prices delayed ~15 min · Source: Finnhub")
                    .multilineTextAlignment(.trailing)
            }
            .font(.system(size: Theme.FontSize.xs))
            .foregroundStyle(Theme.mutedForeground)
            .padding(.vertical, 10)
        }
    }

    private var footerLeft: String {
        loading
            ? "Loading…"
            : "\(filtered.count) of \(rows.count) stocks · tap a row for the full chart"
    }

    // MARK: Table

    // Column widths (mobile horizontal scroll).
    private let wTicker: CGFloat = 70
    private let wCompany: CGFloat = 150
    private let wSector: CGFloat = 110
    private let wPrice: CGFloat = 80
    private let wChg: CGFloat = 80
    private let wCap: CGFloat = 80
    private let wPe: CGFloat = 60
    private let wYield: CGFloat = 80
    private let wBeta: CGFloat = 60
    private let wChevron: CGFloat = 24

    private var table: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider().overlay(Theme.border)

                if filtered.isEmpty {
                    Text("No stocks match these filters.")
                        .font(.system(size: Theme.FontSize.sm))
                        .foregroundStyle(Theme.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                } else {
                    ForEach(filtered) { row in
                        NavigationLink {
                            StocksPageView(initialSymbol: row.symbol)
                        } label: {
                            dataRow(row)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Theme.border.opacity(0.6))
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            sortHeader("Ticker", .symbol, width: wTicker, alignment: .leading)
            plainHeader("Company", width: wCompany, alignment: .leading)
            plainHeader("Sector", width: wSector, alignment: .leading)
            sortHeader("Price", .price, width: wPrice, alignment: .trailing)
            sortHeader("% Chg", .changePercent, width: wChg, alignment: .trailing)
            sortHeader("Mkt Cap", .marketCap, width: wCap, alignment: .trailing)
            sortHeader("P/E", .peRatio, width: wPe, alignment: .trailing)
            sortHeader("Div Yield", .dividendYield, width: wYield, alignment: .trailing)
            sortHeader("Beta", .beta, width: wBeta, alignment: .trailing)
            Color.clear.frame(width: wChevron)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Theme.muted.opacity(0.3))
    }

    private func plainHeader(_ label: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(label)
            .font(.system(size: Theme.FontSize.xs, weight: .semibold))
            .foregroundStyle(Theme.mutedForeground)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 6)
    }

    private func sortHeader(_ label: String, _ key: SortKey, width: CGFloat, alignment: Alignment) -> some View {
        Button { toggleSort(key) } label: {
            HStack(spacing: 3) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(label)
                    .font(.system(size: Theme.FontSize.xs, weight: .semibold))
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                    .opacity(0.5)
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .foregroundStyle(sortKey == key ? Theme.foreground : Theme.mutedForeground)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dataRow(_ r: ScreenerRow) -> some View {
        HStack(spacing: 0) {
            Text(r.symbol)
                .font(.system(size: Theme.FontSize.sm, weight: .bold))
                .foregroundStyle(Theme.foreground)
                .frame(width: wTicker, alignment: .leading)
                .padding(.horizontal, 6)

            Text(r.company)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.mutedForeground)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: wCompany, alignment: .leading)
                .padding(.horizontal, 6)

            Text(r.sector)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.mutedForeground)
                .lineLimit(1)
                .frame(width: wSector, alignment: .leading)
                .padding(.horizontal, 6)

            Text("$" + CalcFormat.fixed(r.price, 2))
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundStyle(Theme.foreground)
                .frame(width: wPrice, alignment: .trailing)
                .padding(.horizontal, 6)

            Text(changeText(r.changePercent))
                .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                .foregroundColor(r.changePercent >= 0 ? Theme.positive : Theme.negative)
                .frame(width: wChg, alignment: .trailing)
                .padding(.horizontal, 6)

            Text(Self.fmtCap(r.marketCap))
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.foreground)
                .frame(width: wCap, alignment: .trailing)
                .padding(.horizontal, 6)

            Text(r.peRatio != nil ? CalcFormat.fixed(r.peRatio!, 1) : "—")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.foreground)
                .frame(width: wPe, alignment: .trailing)
                .padding(.horizontal, 6)

            Text(r.dividendYield != nil ? CalcFormat.fixed(r.dividendYield!, 2) + "%" : "—")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.foreground)
                .frame(width: wYield, alignment: .trailing)
                .padding(.horizontal, 6)

            Text(r.beta != nil ? CalcFormat.fixed(r.beta!, 2) : "—")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundStyle(Theme.foreground)
                .frame(width: wBeta, alignment: .trailing)
                .padding(.horizontal, 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mutedForeground)
                .frame(width: wChevron)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func changeText(_ pct: Double) -> String {
        (pct >= 0 ? "+" : "") + CalcFormat.fixed(pct, 2) + "%"
    }

    // MARK: Filtering + sorting (mirrors the web `filtered` memo)

    private var filtered: [ScreenerRow] {
        let lo = Double(minPrice.trimmingCharacters(in: .whitespaces))
        let hi = Double(maxPrice.trimmingCharacters(in: .whitespaces))
        let pe = Double(maxPe.trimmingCharacters(in: .whitespaces))

        var r = rows.filter { row in
            if sector != "All" && row.sector != sector { return false }
            if perf == "Gainers" && row.changePercent <= 0 { return false }
            if perf == "Losers" && row.changePercent >= 0 { return false }
            if let lo, row.price < lo { return false }
            if let hi, row.price > hi { return false }
            if let pe, (row.peRatio == nil || row.peRatio! > pe) { return false }
            if minYield > 0 && (row.dividendYield ?? 0) < minYield { return false }
            if cap != "All", let mc = row.marketCap {
                if cap.hasPrefix("Mega") && mc < 200e9 { return false }
                if cap.hasPrefix("Large") && (mc < 10e9 || mc >= 200e9) { return false }
                if cap.hasPrefix("Mid") && mc >= 10e9 { return false }
            }
            return true
        }

        r.sort { a, b in
            let cmp = compare(a, b, by: sortKey)
            return sortDir == .asc ? cmp < 0 : cmp > 0
        }
        return r
    }

    /// Returns -1 / 0 / 1. Nil numerics sort as -Infinity (web `av == null ? -Infinity`).
    private func compare(_ a: ScreenerRow, _ b: ScreenerRow, by key: SortKey) -> Int {
        switch key {
        case .symbol:
            return a.symbol == b.symbol ? 0 : (a.symbol < b.symbol ? -1 : 1)
        case .price:
            return num(a.price, b.price)
        case .changePercent:
            return num(a.changePercent, b.changePercent)
        case .marketCap:
            return num(a.marketCap, b.marketCap)
        case .peRatio:
            return num(a.peRatio, b.peRatio)
        case .dividendYield:
            return num(a.dividendYield, b.dividendYield)
        case .beta:
            return num(a.beta, b.beta)
        }
    }

    private func num(_ a: Double?, _ b: Double?) -> Int {
        let av = a ?? -.infinity
        let bv = b ?? -.infinity
        if av < bv { return -1 }
        if av > bv { return 1 }
        return 0
    }

    private func toggleSort(_ key: SortKey) {
        if sortKey == key {
            sortDir = (sortDir == .asc) ? .desc : .asc
        } else {
            sortKey = key
            sortDir = .desc
        }
    }

    private func reset() {
        sector = "All"; cap = "All"; perf = "All"
        minPrice = ""; maxPrice = ""; maxPe = ""; minYield = 0
        sortKey = .marketCap; sortDir = .desc
    }

    // MARK: Market-cap formatting (web `fmtCap`)

    private static func fmtCap(_ n: Double?) -> String {
        guard let n else { return "—" }
        if n >= 1e12 { return "$" + CalcFormat.fixed(n / 1e12, 2) + "T" }
        if n >= 1e9 { return "$" + CalcFormat.fixed(n / 1e9, 1) + "B" }
        if n >= 1e6 { return "$" + CalcFormat.fixed(n / 1e6, 0) + "M" }
        return "$" + CalcFormat.raw(n)
    }

    // MARK: Load

    private func load() async {
        do {
            let result = try await MarketService.screener()
            await MainActor.run {
                rows = result
                error = nil
                loading = false
            }
        } catch {
            let message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            await MainActor.run {
                self.error = message
                loading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardScreenerView()
    }
}
