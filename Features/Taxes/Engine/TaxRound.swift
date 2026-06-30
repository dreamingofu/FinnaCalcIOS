/**
 * TaxRound.swift
 *
 * IRS rounding helpers.
 *
 * The IRS lets filers round to whole dollars: amounts under 50 cents round down,
 * 50 cents and over round up (away from zero for negatives). Apply `dollar()`
 * only at the 1040 line boundaries the IRS rounds at — keep cents internally.
 *
 * Pure-Swift port of components/tax-engine/engine/round.ts. Foundation-only.
 * Faithful 1:1 mirror of the TypeScript: same exported names, same formulas,
 * same rounding. TS `number` -> Swift `Double`.
 */

import Foundation

/// Round to a whole dollar, half away from zero (IRS convention).
public func dollar(_ x: Double) -> Double {
    if !x.isFinite { return 0 }
    // Math.sign(x) * Math.round(Math.abs(x))
    // JS Math.round rounds half up (toward +Infinity); applied to a non-negative
    // value (abs) this is "round half up" == round half away from zero overall.
    let sign: Double = (x > 0) ? 1 : (x < 0 ? -1 : 0)
    return sign * (Foundation.floor(Swift.abs(x) + 0.5))
}

/// Clamp to non-negative (many 1040 lines are floored at zero).
public func nonNeg(_ x: Double) -> Double {
    return x > 0 ? x : 0
}

/// Sum a numeric field across a list.
public func sumBy<T>(_ items: [T], _ fn: (T) -> Double) -> Double {
    return items.reduce(0) { acc, it in
        let v = fn(it)
        // TS: `acc + (fn(it) || 0)` — JS `|| 0` coerces NaN (a falsy value) to 0.
        return acc + (v.isNaN ? 0 : v)
    }
}
