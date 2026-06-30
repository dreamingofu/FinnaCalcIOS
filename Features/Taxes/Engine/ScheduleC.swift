/**
 * ScheduleC.swift
 *
 * Schedule C — net profit or loss from each business, split by owner
 * (taxpayer vs spouse) so self-employment tax can be figured per person.
 *
 * Pure-Swift port of
 * components/tax-engine/engine/pipeline/scheduleC.ts. Foundation-only — no
 * SwiftUI/UIKit/Combine. Faithful 1:1 mirror of the TypeScript: same exported
 * names, same constants, same formulas, same rounding, same conditionals and
 * order of operations. TS `number` -> Swift `Double`.
 */

import Foundation

/// TS: `interface ScheduleCResult`.
public struct ScheduleCResult: Equatable {
    /// TS: `netByOwner: { taxpayer: number; spouse: number }`.
    public struct NetByOwner: Equatable {
        public var taxpayer: Double
        public var spouse: Double

        public init(taxpayer: Double, spouse: Double) {
            self.taxpayer = taxpayer
            self.spouse = spouse
        }
    }

    public var netByOwner: NetByOwner
    public var totalNet: Double

    public init(netByOwner: NetByOwner, totalNet: Double) {
        self.netByOwner = netByOwner
        self.totalNet = totalNet
    }
}

public func computeScheduleC(_ r: TaxReturn2024) -> ScheduleCResult {
    if !r.income.flags.hasSelfEmployment {
        return ScheduleCResult(
            netByOwner: ScheduleCResult.NetByOwner(taxpayer: 0, spouse: 0),
            totalNet: 0
        )
    }

    var taxpayer = 0.0
    var spouse = 0.0
    for c in r.income.scheduleC {
        // TS: Object.values(c.expenses).reduce((a, b) => a + (b || 0), 0)
        // JS `b || 0` coerces NaN (falsy) to 0.
        let expenses = c.expenses.values.reduce(0.0) { a, b in
            a + (b.isNaN ? 0 : b)
        }
        let net =
            c.grossReceipts - c.costOfGoodsSold - expenses - c.homeOfficeDeduction - c.vehicleExpense
        if c.owner == .spouse {
            spouse += net
        } else {
            taxpayer += net
        }
    }

    return ScheduleCResult(
        netByOwner: ScheduleCResult.NetByOwner(taxpayer: taxpayer, spouse: spouse),
        totalNet: taxpayer + spouse
    )
}
