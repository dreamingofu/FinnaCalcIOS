//
//  PlaidService.swift
//  FinnaCalcIOS
//
//  Plaid API calls, ported from the fetches in bank-connect.tsx / debt-card.tsx:
//  create a per-product link token, then exchange the public token on the server
//  for the requested data.
//

import Foundation

enum PlaidProduct: String {
    case transactions, liabilities, investments
}

enum PlaidService {
    /// POST /api/plaid/create-link-token { product } → link_token
    static func createLinkToken(product: PlaidProduct) async throws -> String {
        struct Request: Encodable { let product: String }
        struct Response: Decodable {
            let linkToken: String
            enum CodingKeys: String, CodingKey { case linkToken = "link_token" }
        }
        let response: Response = try await APIClient.shared.postJSON(
            "/api/plaid/create-link-token", body: Request(product: product.rawValue))
        return response.linkToken
    }

    /// POST /api/plaid/transactions { public_token } → 90 days of transactions
    static func importTransactions(publicToken: String) async throws -> [BankTransaction] {
        struct Response: Decodable { let transactions: [BankTransaction] }
        let response: Response = try await APIClient.shared.postJSON(
            "/api/plaid/transactions", body: PublicTokenBody(publicToken: publicToken))
        return response.transactions
    }

    /// POST /api/plaid/liabilities { public_token } → debts & utilization
    static func importLiabilities(publicToken: String) async throws -> LiabilitiesResponse {
        try await APIClient.shared.postJSON(
            "/api/plaid/liabilities", body: PublicTokenBody(publicToken: publicToken))
    }

    /// POST /api/plaid/holdings { public_token } → investment portfolio
    static func importHoldings(publicToken: String) async throws -> PortfolioResponse {
        try await APIClient.shared.postJSON(
            "/api/plaid/holdings", body: PublicTokenBody(publicToken: publicToken))
    }
}

private struct PublicTokenBody: Encodable {
    let publicToken: String
    enum CodingKeys: String, CodingKey { case publicToken = "public_token" }
}
