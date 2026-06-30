//
//  MarketModels.swift
//  FinnaCalcIOS
//
//  Codable mirrors of the market-data routes (app/api/{stock,stock-search,
//  screener,top-movers,market-overview}/route.ts). Note /api/stock and
//  /api/stock-search use AlphaVantage-style numbered keys.
//

import Foundation

// MARK: - /api/stock?symbol=

struct StockQuoteFields: Decodable {
    let symbol: String
    let price: String
    let change: String
    let changePercent: String
    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case price = "05. price"
        case change = "09. change"
        case changePercent = "10. change percent"
    }
}

struct StockOverviewFields: Decodable {
    let name: String
    let marketCapitalization: String
    let description: String
    let logo: String
    let peRatio: String
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case marketCapitalization = "MarketCapitalization"
        case description = "Description"
        case logo = "Logo"
        case peRatio = "PERatio"
    }
}

struct StockResponse: Decodable {
    let quote: StockQuoteFields
    let overview: StockOverviewFields
}

// MARK: - /api/stock-search?keywords=

struct StockSearchResult: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let region: String
    enum CodingKeys: String, CodingKey {
        case symbol = "1. symbol"
        case name = "2. name"
        case region = "4. region"
    }
}

// MARK: - /api/screener

struct ScreenerRow: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let company: String
    let sector: String
    let price: Double
    let changePercent: Double
    let marketCap: Double?
    let peRatio: Double?
    let dividendYield: Double?
    let beta: Double?
}

struct ScreenerResponse: Decodable { let rows: [ScreenerRow] }

// MARK: - /api/top-movers

struct Mover: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changesPercentage: Double
}

struct TopMoversResponse: Decodable {
    let topGainers: [Mover]
    let topLosers: [Mover]
}

// MARK: - /api/market-overview

struct MarketQuote: Decodable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let sector: String
    let sectorColor: String
    let price: Double
    let change: Double
    let changesPercentage: Double
    let high: Double
    let low: Double
    let open: Double
    let previousClose: Double
    let logo: String
}

struct SectorSummary: Decodable, Identifiable {
    let id: String
    let name: String
    let color: String
    let avgChange: Double
    let stockCount: Int
}

struct MarketOverviewResponse: Decodable {
    let stocks: [MarketQuote]
    let gainers: [MarketQuote]
    let losers: [MarketQuote]
    let mostActive: [MarketQuote]
    let sectorSummary: [SectorSummary]
    let timestamp: Double
}
