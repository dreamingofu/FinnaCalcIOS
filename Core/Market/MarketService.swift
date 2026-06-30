//
//  MarketService.swift
//  FinnaCalcIOS
//
//  Market-data API calls (Finnhub-backed routes on the FinnaCalc server).
//

import Foundation

enum MarketService {
    static func stock(symbol: String) async throws -> StockResponse {
        try await APIClient.shared.getJSON("/api/stock", query: ["symbol": symbol])
    }

    static func search(keywords: String) async throws -> [StockSearchResult] {
        try await APIClient.shared.getJSON("/api/stock-search", query: ["keywords": keywords])
    }

    static func screener() async throws -> [ScreenerRow] {
        let response: ScreenerResponse = try await APIClient.shared.getJSON("/api/screener")
        return response.rows
    }

    static func topMovers() async throws -> TopMoversResponse {
        try await APIClient.shared.getJSON("/api/top-movers")
    }

    static func marketOverview() async throws -> MarketOverviewResponse {
        try await APIClient.shared.getJSON("/api/market-overview")
    }
}
