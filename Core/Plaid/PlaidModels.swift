//
//  PlaidModels.swift
//  FinnaCalcIOS
//
//  Codable mirrors of the JSON returned by the /api/plaid/* routes
//  (see ../FinnaCalc/app/api/plaid/{transactions,liabilities,holdings}/route.ts).
//  Keys are already camelCase server-side, so default Codable maps 1:1.
//

import Foundation

/// /api/plaid/transactions → { transactions: BankTransaction[] }
/// Plaid convention: positive amount = money out (expense), negative = money in.
struct BankTransaction: Codable, Identifiable, Equatable {
    var id: String { "\(date)-\(name)-\(amount)" }
    let date: String
    let name: String
    let amount: Double
    let category: String
    let currency: String
}

// MARK: - Liabilities (/api/plaid/liabilities)

struct CreditLine: Codable, Identifiable, Equatable {
    var id: String { accountId.isEmpty ? name : accountId }
    let accountId: String
    let name: String
    let mask: String?
    let balance: Double
    let limit: Double?
    let utilization: Double?
    let apr: Double?
    let minimumPayment: Double?
    let lastStatementBalance: Double?
    let nextDueDate: String?
    let isOverdue: Bool
}

struct OtherDebt: Codable, Identifiable, Equatable {
    var id: String { accountId.isEmpty ? name : accountId }
    let accountId: String
    let type: String   // "student" | "mortgage"
    let name: String
    let balance: Double
    let apr: Double?
    let minimumPayment: Double?
    let nextDueDate: String?
}

struct LiabilitiesResponse: Codable, Equatable {
    let creditLines: [CreditLine]
    let otherDebts: [OtherDebt]
    let totalCreditBalance: Double
    let totalCreditLimit: Double
    let overallUtilization: Double?
    let totalMinimumPayments: Double
    let totalDebt: Double
    let currency: String
}

// MARK: - Holdings (/api/plaid/holdings) — used by the portfolio card (Phase 5)

struct PortfolioHolding: Codable, Identifiable, Equatable {
    var id: String { securityId }
    let securityId: String
    let name: String
    let fullName: String
    let type: String
    let value: Double
    let quantity: Double
    let price: Double
    let avgCost: Double
    let costBasis: Double
    let totalReturn: Double
    let totalReturnPct: Double?
    let weight: Double
}

struct AllocationSlice: Codable, Identifiable, Equatable {
    var id: String { type }
    let type: String
    let value: Double
}

struct PortfolioResponse: Codable, Equatable {
    let holdings: [PortfolioHolding]
    let allocation: [AllocationSlice]
    let totalValue: Double
    let totalCostBasis: Double
    let totalReturn: Double
    let totalReturnPct: Double?
    let accountCount: Int
    let currency: String
}
