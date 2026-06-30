/**
 * EfileBundle.swift
 *
 * Pure-Swift port of:
 *   - components/tax-engine/export/efile/EfileProvider.ts   (the EfileBundle type
 *     + the EfileSubmissionResult / provider contract)
 *   - components/tax-engine/export/efile/buildEfileBundle.ts (buildEfileBundle)
 *
 * Provider-agnostic e-file contract. A neutral, serializable payload mapped from
 * a computed return. The actual network call happens server-side (POST /api/efile)
 * so the provider API key never reaches the client. Foundation-only.
 *
 * Faithful 1:1 mirror of the TypeScript types and mapping.
 */

import Foundation

/// One line for the transmitter to map into its own schema.
/// TS: `{ id: string; label: string; amount: number }`.
public struct EfileLine: Codable, Equatable {
    public var id: String
    public var label: String
    public var amount: Double

    public init(id: String, label: String, amount: Double) {
        self.id = id
        self.label = label
        self.amount = amount
    }
}

/// Optional state block on the bundle.
/// TS: `{ code: StateCode; tax: number; refundOrOwed: number }`.
public struct EfileBundleState: Codable, Equatable {
    public var code: StateCode
    public var tax: Double
    public var refundOrOwed: Double

    public init(code: StateCode, tax: Double, refundOrOwed: Double) {
        self.code = code
        self.tax = tax
        self.refundOrOwed = refundOrOwed
    }
}

/// A neutral, serializable payload mapped from a computed return.
/// TS: `interface EfileBundle`.
public struct EfileBundle: Codable, Equatable {
    /// TS literal type `2024`.
    public var taxYear: Int
    public var filingStatus: FilingStatus
    public var agi: Double
    public var taxableIncome: Double
    public var totalTax: Double
    public var totalPayments: Double
    public var refundOrOwed: Double
    public var state: EfileBundleState?
    /// Line-by-line trace for the transmitter to map into its own schema.
    public var lines: [EfileLine]

    public init(
        taxYear: Int = 2024,
        filingStatus: FilingStatus,
        agi: Double,
        taxableIncome: Double,
        totalTax: Double,
        totalPayments: Double,
        refundOrOwed: Double,
        state: EfileBundleState? = nil,
        lines: [EfileLine]
    ) {
        self.taxYear = taxYear
        self.filingStatus = filingStatus
        self.agi = agi
        self.taxableIncome = taxableIncome
        self.totalTax = totalTax
        self.totalPayments = totalPayments
        self.refundOrOwed = refundOrOwed
        self.state = state
        self.lines = lines
    }
}

/// Result status from the transmitter.
/// TS: `"accepted" | "rejected" | "queued" | "unsupported"`.
public enum EfileSubmissionStatus: String, Codable, Equatable {
    case accepted
    case rejected
    case queued
    case unsupported
}

/// TS: `interface EfileSubmissionResult`.
public struct EfileSubmissionResult: Codable, Equatable {
    public var status: EfileSubmissionStatus
    public var providerRef: String?
    public var message: String

    public init(status: EfileSubmissionStatus, providerRef: String? = nil, message: String) {
        self.status = status
        self.providerRef = providerRef
        self.message = message
    }
}

/// TS: `buildEfileBundle(result: TaxCalculationResult): EfileBundle`.
public func buildEfileBundle(_ result: TaxCalculationResult) -> EfileBundle {
    let stateBlock: EfileBundleState?
    if let s = result.state, s.supported, s.hasIncomeTax {
        stateBlock = EfileBundleState(code: s.code, tax: s.tax, refundOrOwed: s.refundOrOwed)
    } else {
        stateBlock = nil
    }

    return EfileBundle(
        taxYear: 2024,
        filingStatus: result.filingStatus,
        agi: result.agi,
        taxableIncome: result.taxableIncome,
        totalTax: result.totalTax,
        totalPayments: result.totalPayments,
        refundOrOwed: result.refundOrOwed,
        state: stateBlock,
        lines: result.trace.map { EfileLine(id: $0.id, label: $0.label, amount: $0.amount) }
    )
}
