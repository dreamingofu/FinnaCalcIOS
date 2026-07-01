//
//  InvestingView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of the Investing tab root. The web reference
//  (components/investing-options.tsx + app/investing/page.tsx) is a dashboard
//  that groups live markets, the user's portfolio, and stock research behind a
//  set of view tabs ("Market Overview" / "Portfolio" / "Screener"), with a
//  universal stock search below the title and drill-down entry points.
//
//  On iOS the same grouping is preserved:
//    • A header + universal search box (live typeahead via MarketService.search)
//    • A segmented Picker for the three web "View tabs":
//        – Market Overview → MarketsDashboardView
//        – Portfolio       → BrokerageConnectView + DashboardWatchlistView
//        – Screener        → DashboardScreenerView
//    • A "Research & Learn" section of NavigationLink entry points to
//      StocksPageView, BondsPageView, SafeInvestmentsView, InvestmentEducationView.
//
//  RootView already wraps this tab in a NavigationStack, so drill-downs use
//  NavigationLink directly. Kept as a ScrollView over Theme.background.
//
//  iOS 16: post-await @State writes are wrapped in `Task { @MainActor in … }`;
//  colored +/- text uses .foregroundColor.
//

import SwiftUI

struct InvestingView: View {

    // MARK: View tabs (mirror the web "VIEW_TABS")

    private enum InvestingTab: String, CaseIterable, Identifiable {
        case overview  = "Market Overview"
        case portfolio = "Portfolio"
        case screener  = "Screener"
        var id: String { rawValue }
    }

    @State private var activeTab: InvestingTab = .overview

    // MARK: Universal search state

    @State private var searchTerm = ""
    @State private var searchResults: [StockSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedSymbol: String?
    @State private var navigateToSymbol = false

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                searchSection
                tabPicker

                switch activeTab {
                case .overview:  overviewSection
                case .portfolio: portfolioSection
                case .screener:  screenerSection
                }

                researchSection
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Investing")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            NavigationLink(isActive: $navigateToSymbol) {
                StocksPageView(initialSymbol: selectedSymbol)
            } label: { EmptyView() }
            .hidden()
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Investing")
                .font(Theme.sans(Theme.FontSize.xl2, weight: .bold))
                .foregroundColor(Theme.foreground)
            Text("Live markets, your portfolio, and stock research in one place.")
                .font(Theme.sans(Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Universal search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(Theme.sans(14))
                        .foregroundColor(Theme.mutedForeground)
                    TextField("Search any stock — e.g. Apple, TSLA", text: $searchTerm)
                        .font(Theme.sans(Theme.FontSize.base))
                        .foregroundColor(Theme.foreground)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .submitLabel(.search)
                        .onSubmit { onSubmitSearch() }
                        .onChange(of: searchTerm) { newValue in runTypeahead(newValue) }
                    if !searchTerm.isEmpty {
                        Button {
                            searchTerm = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.muted.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }

            if isSearching {
                Text("Searching…")
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
                    .padding(.horizontal, 4)
            } else if !searchResults.isEmpty {
                searchResultsList
            } else if searchTerm.trimmingCharacters(in: .whitespaces).count >= 2 {
                Text("No results found.")
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(searchResults.prefix(8).enumerated()), id: \.element.id) { index, result in
                Button {
                    selectStock(result.symbol)
                } label: {
                    HStack(spacing: 12) {
                        logoBadge(result.symbol)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.symbol)
                                .font(Theme.sans(Theme.FontSize.sm, weight: .bold))
                                .foregroundColor(Theme.foreground)
                            Text(result.name)
                                .font(Theme.sans(Theme.FontSize.xs))
                                .foregroundColor(Theme.mutedForeground)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundColor(Theme.mutedForeground)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < min(searchResults.count, 8) - 1 {
                    Divider().background(Theme.border)
                }
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Colored circular initial — the web `Logo` fallback.
    private func logoBadge(_ symbol: String) -> some View {
        let palette: [Color] = [Theme.primary, Theme.positive, Theme.negative]
        let first = symbol.first.map(String.init) ?? "?"
        let color = palette[Int(symbol.utf8.first ?? 0) % palette.count]
        return Text(first)
            .font(Theme.sans(15, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(color)
            .clipShape(Circle())
    }

    // MARK: - View-tab picker

    private var tabPicker: some View {
        Picker("View", selection: $activeTab) {
            ForEach(InvestingTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tab content

    /// Market Overview tab — the web embeds the live markets dashboard here.
    private var overviewSection: some View {
        MarketsDashboardView()
    }

    /// Portfolio tab — the web stacks BrokerageConnect then the markets
    /// dashboard. On iOS the brokerage connection sits above the watchlist so
    /// connected positions and a personal watchlist live together.
    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            BrokerageConnectView()
            DashboardWatchlistView()
        }
    }

    /// Screener tab — the web embeds the screener table.
    private var screenerSection: some View {
        DashboardScreenerView()
    }

    // MARK: - Research & Learn entry points

    private var researchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Research & Learn")
                .font(Theme.sans(Theme.FontSize.base, weight: .bold))
                .foregroundColor(Theme.foreground)
                .padding(.top, 4)

            entryLink(
                icon: "chart.line.uptrend.xyaxis",
                title: "Stocks",
                subtitle: "Quotes, charts, and company research",
                iconTone: .neutral
            ) { StocksPageView() }

            entryLink(
                icon: "building.columns",
                title: "Bonds",
                subtitle: "Treasury yields and fixed income",
                iconTone: .positive
            ) { BondsPageView() }

            entryLink(
                icon: "shield.lefthalf.filled",
                title: "Safe Investments",
                subtitle: "CDs, savings, and money-market options",
                iconTone: .neutral
            ) { SafeInvestmentsView() }

            entryLink(
                icon: "graduationcap",
                title: "Investing 101",
                subtitle: "Learn the fundamentals of investing",
                iconTone: .negative
            ) { InvestmentEducationView() }
        }
    }

    private func entryLink<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        iconTone: FCResultTone,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            FCCard(interactive: true) {
                FCListRow(icon: icon, iconTone: iconTone, title: title, subtitle: subtitle)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search actions

    /// Live typeahead — debounced, fires as the user types (≥2 chars).
    private func runTypeahead(_ raw: String) {
        let term = raw.trimmingCharacters(in: .whitespaces)
        searchTask?.cancel()
        guard term.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await performSearch(term)
        }
    }

    /// Immediate search on Enter (bypasses the debounce); jumps straight to the
    /// top result if one exists.
    private func onSubmitSearch() {
        let term = searchTerm.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        if let first = searchResults.first {
            selectStock(first.symbol)
        } else {
            searchTask?.cancel()
            isSearching = true
            searchTask = Task { await performSearch(term) }
        }
    }

    private func performSearch(_ term: String) async {
        do {
            let results = try await MarketService.search(keywords: term)
            if Task.isCancelled { return }
            Task { @MainActor in
                searchResults = results
                isSearching = false
            }
        } catch {
            if Task.isCancelled { return }
            Task { @MainActor in
                searchResults = []
                isSearching = false
            }
        }
    }

    private func selectStock(_ symbol: String) {
        searchTask?.cancel()
        searchTerm = ""
        searchResults = []
        isSearching = false
        selectedSymbol = symbol
        navigateToSymbol = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InvestingView()
    }
}
