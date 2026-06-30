//
//  StocksPageView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/components/stocks-page.tsx`.
//  Ticker search with debounced typeahead + a selected-stock detail panel
//  (quote, overview, description, TradingView chart).
//

import SwiftUI

struct StocksPageView: View {

    // MARK: - Selected stock model (mirrors the web `StockData`)

    private struct StockData {
        let symbol: String
        let name: String
        let price: Double
        let change: Double
        let changePercent: Double
        let marketCap: String
        let peRatio: String
        let description: String
        let logo: String
    }

    let initialSymbol: String?

    @State private var searchTerm = ""
    @State private var searchResults: [StockSearchResult] = []
    @State private var selectedStock: StockData?
    @State private var isLoading = false
    @State private var error: String?

    // Debounce handle for the live typeahead lookups.
    @State private var searchTask: Task<Void, Never>?

    init(initialSymbol: String? = nil) {
        self.initialSymbol = initialSymbol
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchCard
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Stocks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let initialSymbol, selectedStock == nil {
                Task { await fetchStockDetails(symbol: initialSymbol) }
            }
        }
        // Live typeahead — show matches as the user types (debounced 250ms).
        .onChange(of: searchTerm) { newValue in
            scheduleTypeahead(newValue)
        }
    }

    // MARK: - Search card

    private var searchCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Search Stocks")
                HStack(spacing: 8) {
                    FCTextField("e.g., AAPL, Microsoft", text: $searchTerm)
                        .onSubmit { handleSubmit() }
                    FCButton(variant: .default, size: .default, label: {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                            Text(isLoading ? "Searching..." : "Search")
                        }
                    }, action: handleSearch)
                    .disabled(isLoading)
                }
                .padding(.top, 8)
            }

            FCCardContent {
                VStack(alignment: .leading, spacing: 16) {
                    if let error {
                        Text(error)
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundColor(Theme.negative)
                    }

                    if isLoading && selectedStock == nil && searchResults.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Loading...")
                                .font(.system(size: Theme.FontSize.sm))
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }

                    if !searchResults.isEmpty {
                        searchResultsList
                    }

                    if let stock = selectedStock {
                        stockDetail(stock)
                    }
                }
            }
        }
    }

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(searchResults) { result in
                Button {
                    Task { await fetchStockDetails(symbol: result.symbol) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.symbol)
                            .font(.system(size: Theme.FontSize.base, weight: .bold))
                            .foregroundColor(Theme.foreground)
                        Text(result.name)
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundColor(Theme.mutedForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.muted.opacity(0.5))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Selected stock detail

    @ViewBuilder
    private func stockDetail(_ stock: StockData) -> some View {
        let isUp = stock.change >= 0
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                AsyncImage(url: URL(string: stock.logo)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Image(systemName: "building.columns")
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
                .frame(width: 48, height: 48)
                .background(Theme.background)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(stock.name) (\(stock.symbol))")
                        .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                        .foregroundColor(Theme.foreground)
                    Text("$\(CalcFormat.fixed(stock.price, 2))")
                        .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                        .foregroundColor(Theme.foreground)
                    HStack(spacing: 4) {
                        Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        Text("\(CalcFormat.fixed(stock.change, 2)) (\(CalcFormat.fixed(stock.changePercent, 2))%)")
                    }
                    .font(.system(size: Theme.FontSize.sm, weight: .medium))
                    .foregroundColor(isUp ? Theme.positive : Theme.negative)
                }
                Spacer(minLength: 0)
            }

            // Key stats: market cap + P/E from overview.
            HStack(spacing: 12) {
                statTile(label: "Market Cap", value: formatMarketCap(stock.marketCap))
                statTile(label: "P/E Ratio", value: stock.peRatio.isEmpty || stock.peRatio == "None" ? "—" : stock.peRatio)
            }

            if !stock.description.isEmpty && stock.description != "None" {
                Text(stock.description)
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
                    .lineLimit(6)
            }

            TradingViewChart(symbol: stock.symbol, height: 420)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
            Text(value)
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundColor(Theme.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.muted.opacity(0.5))
        )
    }

    // MARK: - Actions

    private func handleSubmit() {
        if let first = searchResults.first {
            Task { await fetchStockDetails(symbol: first.symbol) }
        } else {
            handleSearch()
        }
    }

    private func handleSearch() {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searchTask?.cancel()
        Task { @MainActor in
            isLoading = true
            error = nil
            selectedStock = nil
            searchResults = []
            do {
                let results = try await MarketService.search(keywords: term)
                searchResults = results
            } catch {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
            isLoading = false
        }
    }

    private func fetchStockDetails(symbol: String) async {
        searchTask?.cancel()
        await MainActor.run {
            isLoading = true
            error = nil
            selectedStock = nil
            searchResults = []
        }
        do {
            let data = try await MarketService.stock(symbol: symbol)
            let changePct = data.quote.changePercent
                .replacingOccurrences(of: "%", with: "")
                .calcValue
            let stock = StockData(
                symbol: data.quote.symbol,
                name: data.overview.name,
                price: data.quote.price.calcValue,
                change: data.quote.change.calcValue,
                changePercent: changePct,
                marketCap: data.overview.marketCapitalization,
                peRatio: data.overview.peRatio,
                description: data.overview.description,
                logo: data.overview.logo
            )
            await MainActor.run {
                selectedStock = stock
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
                isLoading = false
            }
        }
    }

    private func scheduleTypeahead(_ value: String) {
        searchTask?.cancel()
        let term = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else {
            searchResults = []
            return
        }
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            do {
                let results = try await MarketService.search(keywords: term)
                if Task.isCancelled { return }
                // Don't clobber a selected stock's view with stale typeahead.
                if selectedStock == nil {
                    searchResults = results
                }
            } catch {
                // Ignore aborted/failed typeahead lookups.
            }
        }
    }

    // MARK: - Helpers

    /// AlphaVantage market cap arrives as a raw integer string; render it compactly.
    private func formatMarketCap(_ raw: String) -> String {
        let value = raw.calcValue
        guard value > 0 else {
            return raw.isEmpty || raw == "None" ? "—" : raw
        }
        let trillion = 1_000_000_000_000.0
        let billion = 1_000_000_000.0
        let million = 1_000_000.0
        if value >= trillion {
            return "$\(CalcFormat.fixed(value / trillion, 2))T"
        } else if value >= billion {
            return "$\(CalcFormat.fixed(value / billion, 2))B"
        } else if value >= million {
            return "$\(CalcFormat.fixed(value / million, 2))M"
        }
        return CalcFormat.currency(value)
    }
}

#Preview {
    NavigationStack {
        StocksPageView(initialSymbol: "AAPL")
    }
}
