//
//  SnapTradeModels.swift
//  FinnaCalcIOS
//
//  Mirrors /api/snaptrade/{connect,accounts,disconnect}. The SnapTrade session
//  lives in an httpOnly cookie set on the connect response; URLSession.shared's
//  shared cookie storage carries it to the accounts call automatically.
//

import Foundation

struct BrokerageAccount: Decodable, Identifiable {
    let id: String
    let name: String
    let institution: String
    let number: String
    let totalValue: Double?
    let currency: String
}

struct BrokeragePosition: Decodable {
    let accountId: String
    let symbol: String
    let description: String
    let units: Double
    let price: Double?
    let marketValue: Double?
    let openPnl: Double?
}

struct SnapTradeAccountsResponse: Decodable {
    let configured: Bool
    let connected: Bool?
    let accounts: [BrokerageAccount]
    let positions: [BrokeragePosition]
    let totalValue: Double?
    let currency: String?
    let error: String?
}

struct SnapTradeConnectResponse: Decodable {
    let redirectURI: String
}
