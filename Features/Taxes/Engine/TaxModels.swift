/**
 * TaxModels.swift
 *
 * Pure-Swift port of the FinnaCalc tax-engine type surface
 * (components/tax-engine/types). Foundation-only — no SwiftUI/UIKit/Combine.
 *
 * Faithful 1:1 mirror of the TypeScript types: same names, same fields, same
 * defaults. TS `number` -> `Double`, TS optional (`?` / `| undefined`) -> Swift
 * `Optional`, TS `Record<string, T>` -> `[String: T]`, TS string-literal unions
 * -> Swift enums with `String` raw values.
 */

import Foundation

// MARK: - filing.ts

/// Form 1040 filing status checkboxes.
public enum FilingStatus: String, Codable, Equatable, CaseIterable {
    case single  // Single
    case mfj     // Married filing jointly
    case mfs     // Married filing separately
    case hoh     // Head of household
    case qss     // Qualifying surviving spouse
}

/// Two-letter USPS state codes (+ DC). Residency drives the state engine (later phase).
public enum StateCode: String, Codable, Equatable, CaseIterable {
    case AL, AK, AZ, AR, CA, CO, CT, DE, DC, FL
    case GA, HI, ID, IL, IN, IA, KS, KY, LA, ME
    case MD, MA, MI, MN, MS, MO, MT, NE, NV, NH
    case NJ, NM, NY, NC, ND, OH, OK, OR, PA, RI
    case SC, SD, TN, TX, UT, VT, VA, WA, WV, WI, WY
}

/// Individual identity block (taxpayer or spouse). SSN is sensitive — never persisted.
public struct TaxpayerInfo: Codable, Equatable {
    public var firstName: String
    public var lastName: String
    /// SSN — SENSITIVE: held in memory only, never written to localStorage.
    public var ssn: String
    /// ISO date string (YYYY-MM-DD). Used to derive the 65+ additional standard deduction.
    public var dateOfBirth: String
    public var occupation: String
    /// Legally blind — adds an additional standard deduction amount (Form 1040 std-ded chart).
    public var blind: Bool
    /// Can be claimed as a dependent on someone else's return — caps the standard deduction.
    public var claimedAsDependentByAnother: Bool

    public init(
        firstName: String,
        lastName: String,
        ssn: String,
        dateOfBirth: String,
        occupation: String,
        blind: Bool,
        claimedAsDependentByAnother: Bool
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.ssn = ssn
        self.dateOfBirth = dateOfBirth
        self.occupation = occupation
        self.blind = blind
        self.claimedAsDependentByAnother = claimedAsDependentByAnother
    }
}

/// Mailing address (Form 1040 header).
public struct Address: Codable, Equatable {
    public var line1: String
    public var line2: String?
    public var city: String
    /// TS: `StateCode | ""` — empty represented by `nil`.
    public var state: StateCode?
    public var zip: String

    public init(
        line1: String,
        line2: String? = nil,
        city: String,
        state: StateCode? = nil,
        zip: String
    ) {
        self.line1 = line1
        self.line2 = line2
        self.city = city
        self.state = state
        self.zip = zip
    }
}

/// Relationship type for a dependent. TS: `"child" | "relative"`.
public enum DependentRelationshipType: String, Codable, Equatable {
    case child
    case relative
}

/**
 * A dependent claimed on the return.
 * Qualification follows the IRS qualifying-child / qualifying-relative tests
 * (Pub 17 ch. 3). The booleans below are the engine inputs that gate CTC/ODC,
 * the Child & Dependent Care Credit, and EITC.
 */
public struct Dependent: Codable, Equatable {
    public var id: String
    public var firstName: String
    public var lastName: String
    /// SENSITIVE.
    public var ssn: String
    public var dateOfBirth: String
    /// "child" = qualifying child; "relative" = qualifying relative.
    public var relationshipType: DependentRelationshipType
    public var relationship: String // e.g. "son", "daughter", "parent"
    /// Months the dependent lived with the taxpayer in 2024 (residency test).
    public var monthsLivedWithTaxpayer: Double
    /// Taxpayer provided > half of the dependent's support.
    public var taxpayerProvidedOverHalfSupport: Bool
    /// Qualifies for the $2,000 Child Tax Credit (under 17 at year end, has SSN, etc.).
    public var qualifiesForCTC: Bool
    /// Qualifies for the $500 Credit for Other Dependents (ODC) instead of CTC.
    public var qualifiesForODC: Bool
    /// Counts as a qualifying child for EITC purposes (relationship/age/residency).
    public var qualifiesForEITC: Bool
    /// Under 13 (or disabled) — gates the Child & Dependent Care Credit (Form 2441).
    public var qualifiesForCareCredit: Bool

    public init(
        id: String,
        firstName: String,
        lastName: String,
        ssn: String,
        dateOfBirth: String,
        relationshipType: DependentRelationshipType,
        relationship: String,
        monthsLivedWithTaxpayer: Double,
        taxpayerProvidedOverHalfSupport: Bool,
        qualifiesForCTC: Bool,
        qualifiesForODC: Bool,
        qualifiesForEITC: Bool,
        qualifiesForCareCredit: Bool
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.ssn = ssn
        self.dateOfBirth = dateOfBirth
        self.relationshipType = relationshipType
        self.relationship = relationship
        self.monthsLivedWithTaxpayer = monthsLivedWithTaxpayer
        self.taxpayerProvidedOverHalfSupport = taxpayerProvidedOverHalfSupport
        self.qualifiesForCTC = qualifiesForCTC
        self.qualifiesForODC = qualifiesForODC
        self.qualifiesForEITC = qualifiesForEITC
        self.qualifiesForCareCredit = qualifiesForCareCredit
    }
}

// MARK: - income.ts

/// Owner of an income item. TS: `"taxpayer" | "spouse"`.
public enum IncomeOwner: String, Codable, Equatable {
    case taxpayer
    case spouse
}

/// One Box 12 code/amount pair on a W-2. TS: `{ code: string; amount: number }`.
public struct W2Box12Entry: Codable, Equatable {
    public var code: String
    public var amount: Double

    public init(code: String, amount: Double) {
        self.code = code
        self.amount = amount
    }
}

/// A W-2 (wage statement). Box numbers per the 2024 W-2.
public struct W2: Codable, Equatable {
    public var id: String
    /// "taxpayer" or "spouse" — relevant for MFJ Additional Medicare Tax per-person wage base.
    public var owner: IncomeOwner
    public var employerName: String
    /// Box 1 — wages, tips, other compensation.
    public var box1Wages: Double
    /// Box 2 — federal income tax withheld.
    public var box2FederalWithholding: Double
    /// Box 3 — Social Security wages.
    public var box3SsWages: Double
    /// Box 4 — Social Security tax withheld.
    public var box4SsWithheld: Double
    /// Box 5 — Medicare wages and tips (basis for Additional Medicare Tax).
    public var box5MedicareWages: Double
    /// Box 6 — Medicare tax withheld (includes any Additional Medicare withheld).
    public var box6MedicareWithheld: Double
    /// Box 12 codes that matter to the engine (D=401k, W=HSA employer/employee, etc.).
    public var box12: [W2Box12Entry]
    /// Box 13 "Statutory employee" — moves wages to Schedule C.
    public var statutoryEmployee: Bool
    /// Box 17 — state income tax withheld (state engine, later phase).
    public var box17StateWithholding: Double

    public init(
        id: String,
        owner: IncomeOwner,
        employerName: String,
        box1Wages: Double,
        box2FederalWithholding: Double,
        box3SsWages: Double,
        box4SsWithheld: Double,
        box5MedicareWages: Double,
        box6MedicareWithheld: Double,
        box12: [W2Box12Entry],
        statutoryEmployee: Bool,
        box17StateWithholding: Double
    ) {
        self.id = id
        self.owner = owner
        self.employerName = employerName
        self.box1Wages = box1Wages
        self.box2FederalWithholding = box2FederalWithholding
        self.box3SsWages = box3SsWages
        self.box4SsWithheld = box4SsWithheld
        self.box5MedicareWages = box5MedicareWages
        self.box6MedicareWithheld = box6MedicareWithheld
        self.box12 = box12
        self.statutoryEmployee = statutoryEmployee
        self.box17StateWithholding = box17StateWithholding
    }
}

/// 1099-INT — interest income.
public struct Form1099Int: Codable, Equatable {
    public var id: String
    public var payer: String
    /// Box 1 — taxable interest.
    public var box1Interest: Double
    /// Box 3 — interest on U.S. savings bonds / Treasury obligations (state-exempt).
    public var box3UsTreasuryInterest: Double
    /// Box 8 — tax-exempt interest (feeds SS taxability & some MAGIs, not taxable income).
    public var box8TaxExemptInterest: Double
    /// Box 4 — federal income tax withheld (backup withholding).
    public var box4FederalWithholding: Double

    public init(
        id: String,
        payer: String,
        box1Interest: Double,
        box3UsTreasuryInterest: Double,
        box8TaxExemptInterest: Double,
        box4FederalWithholding: Double
    ) {
        self.id = id
        self.payer = payer
        self.box1Interest = box1Interest
        self.box3UsTreasuryInterest = box3UsTreasuryInterest
        self.box8TaxExemptInterest = box8TaxExemptInterest
        self.box4FederalWithholding = box4FederalWithholding
    }
}

/// 1099-DIV — dividends. Qualified portion is taxed at capital-gains rates.
public struct Form1099Div: Codable, Equatable {
    public var id: String
    public var payer: String
    /// Box 1a — total ordinary dividends.
    public var box1aOrdinaryDividends: Double
    /// Box 1b — qualified dividends (subset of 1a, capital-gain rates).
    public var box1bQualifiedDividends: Double
    /// Box 2a — total capital gain distributions (long-term).
    public var box2aCapitalGainDistributions: Double
    /// Box 4 — federal income tax withheld.
    public var box4FederalWithholding: Double

    public init(
        id: String,
        payer: String,
        box1aOrdinaryDividends: Double,
        box1bQualifiedDividends: Double,
        box2aCapitalGainDistributions: Double,
        box4FederalWithholding: Double
    ) {
        self.id = id
        self.payer = payer
        self.box1aOrdinaryDividends = box1aOrdinaryDividends
        self.box1bQualifiedDividends = box1bQualifiedDividends
        self.box2aCapitalGainDistributions = box2aCapitalGainDistributions
        self.box4FederalWithholding = box4FederalWithholding
    }
}

/// One sale lot from a 1099-B / Form 8949 capital transaction.
public struct CapitalTransaction: Codable, Equatable {
    public var id: String
    public var description: String
    public var proceeds: Double
    public var costBasis: Double
    /// true = held > 1 year (long-term); false = short-term (ordinary rates).
    public var longTerm: Bool
    /// Wash-sale disallowed loss adjustment (8949 col g), if any.
    public var washSaleAdjustment: Double?

    public init(
        id: String,
        description: String,
        proceeds: Double,
        costBasis: Double,
        longTerm: Bool,
        washSaleAdjustment: Double? = nil
    ) {
        self.id = id
        self.description = description
        self.proceeds = proceeds
        self.costBasis = costBasis
        self.longTerm = longTerm
        self.washSaleAdjustment = washSaleAdjustment
    }
}

/// 1099-R — distributions from pensions, annuities, retirement, IRAs.
public struct Form1099R: Codable, Equatable {
    public var id: String
    public var payer: String
    /// Box 1 — gross distribution.
    public var box1GrossDistribution: Double
    /// Box 2a — taxable amount.
    public var box2aTaxableAmount: Double
    /// Box 4 — federal income tax withheld.
    public var box4FederalWithholding: Double
    /// Box 7 — distribution code (e.g. "1" = early, no known exception → 10% penalty).
    public var box7DistributionCode: String
    /// IRA/SEP/SIMPLE checkbox.
    public var iraSepSimple: Bool

    public init(
        id: String,
        payer: String,
        box1GrossDistribution: Double,
        box2aTaxableAmount: Double,
        box4FederalWithholding: Double,
        box7DistributionCode: String,
        iraSepSimple: Bool
    ) {
        self.id = id
        self.payer = payer
        self.box1GrossDistribution = box1GrossDistribution
        self.box2aTaxableAmount = box2aTaxableAmount
        self.box4FederalWithholding = box4FederalWithholding
        self.box7DistributionCode = box7DistributionCode
        self.iraSepSimple = iraSepSimple
    }
}

/// 1099-SSA — Social Security benefits (taxability computed via worksheet).
public struct Form1099Ssa: Codable, Equatable {
    public var id: String
    public var owner: IncomeOwner
    /// Box 5 — net benefits for the year.
    public var box5NetBenefits: Double
    /// Federal income tax withheld (voluntary).
    public var federalWithholding: Double

    public init(
        id: String,
        owner: IncomeOwner,
        box5NetBenefits: Double,
        federalWithholding: Double
    ) {
        self.id = id
        self.owner = owner
        self.box5NetBenefits = box5NetBenefits
        self.federalWithholding = federalWithholding
    }
}

/// 1099-NEC — nonemployee compensation (flows to Schedule C).
public struct Form1099Nec: Codable, Equatable {
    public var id: String
    public var payer: String
    /// Box 1 — nonemployee compensation.
    public var box1Compensation: Double
    public var box4FederalWithholding: Double

    public init(
        id: String,
        payer: String,
        box1Compensation: Double,
        box4FederalWithholding: Double
    ) {
        self.id = id
        self.payer = payer
        self.box1Compensation = box1Compensation
        self.box4FederalWithholding = box4FederalWithholding
    }
}

/// 1099-MISC — miscellaneous income (rents, royalties, other).
public struct Form1099Misc: Codable, Equatable {
    public var id: String
    public var payer: String
    public var box1Rents: Double
    public var box2Royalties: Double
    public var box3OtherIncome: Double
    public var box4FederalWithholding: Double

    public init(
        id: String,
        payer: String,
        box1Rents: Double,
        box2Royalties: Double,
        box3OtherIncome: Double,
        box4FederalWithholding: Double
    ) {
        self.id = id
        self.payer = payer
        self.box1Rents = box1Rents
        self.box2Royalties = box2Royalties
        self.box3OtherIncome = box3OtherIncome
        self.box4FederalWithholding = box4FederalWithholding
    }
}

/// 1099-G — government payments (unemployment, state refunds).
public struct Form1099G: Codable, Equatable {
    public var id: String
    public var payer: String
    /// Box 1 — unemployment compensation (fully taxable for 2024).
    public var box1Unemployment: Double
    /// Box 2 — state/local income tax refunds (taxable only if itemized last year).
    public var box2StateRefund: Double
    public var box4FederalWithholding: Double

    public init(
        id: String,
        payer: String,
        box1Unemployment: Double,
        box2StateRefund: Double,
        box4FederalWithholding: Double
    ) {
        self.id = id
        self.payer = payer
        self.box1Unemployment = box1Unemployment
        self.box2StateRefund = box2StateRefund
        self.box4FederalWithholding = box4FederalWithholding
    }
}

/// 1099-SA — distributions from an HSA (Form 8889).
public struct Form1099Sa: Codable, Equatable {
    public var id: String
    /// Box 1 — gross distribution.
    public var box1GrossDistribution: Double
    /// Portion used for unqualified expenses (taxable + 20% penalty).
    public var unqualifiedAmount: Double

    public init(
        id: String,
        box1GrossDistribution: Double,
        unqualifiedAmount: Double
    ) {
        self.id = id
        self.box1GrossDistribution = box1GrossDistribution
        self.unqualifiedAmount = unqualifiedAmount
    }
}

/// A single Schedule C business.
public struct ScheduleC: Codable, Equatable {
    public var id: String
    public var owner: IncomeOwner
    public var businessName: String
    /// Principal business / activity description.
    public var description: String
    /// Line 1 — gross receipts.
    public var grossReceipts: Double
    /// Line 4 — cost of goods sold.
    public var costOfGoodsSold: Double
    /// Itemized expense lines (Part II), keyed by category.
    public var expenses: [String: Double]
    /// Home office deduction (Form 8829 or simplified $5/sqft up to 300 sqft).
    public var homeOfficeDeduction: Double
    /// Vehicle expenses (actual or standard mileage).
    public var vehicleExpense: Double
    /// Whether the activity is a specified service trade or business (QBI/SSTB).
    public var isSSTB: Bool

    public init(
        id: String,
        owner: IncomeOwner,
        businessName: String,
        description: String,
        grossReceipts: Double,
        costOfGoodsSold: Double,
        expenses: [String: Double],
        homeOfficeDeduction: Double,
        vehicleExpense: Double,
        isSSTB: Bool
    ) {
        self.id = id
        self.owner = owner
        self.businessName = businessName
        self.description = description
        self.grossReceipts = grossReceipts
        self.costOfGoodsSold = costOfGoodsSold
        self.expenses = expenses
        self.homeOfficeDeduction = homeOfficeDeduction
        self.vehicleExpense = vehicleExpense
        self.isSSTB = isSSTB
    }
}

/// A single Schedule E property / passthrough (rental, royalty, K-1).
public struct ScheduleE: Codable, Equatable {
    public var id: String
    public var description: String
    /// Net rental/royalty/passthrough income or loss for the property.
    public var netIncome: Double

    public init(id: String, description: String, netIncome: Double) {
        self.id = id
        self.description = description
        self.netIncome = netIncome
    }
}

/// Gating flags driven by the interview; the engine only reads gated sources.
/// TS: inline object literal on `IncomeData.flags`.
public struct IncomeFlags: Codable, Equatable {
    public var hasW2: Bool
    public var hasInterest: Bool
    public var hasDividends: Bool
    public var hasCapitalGains: Bool
    public var hasRetirementDistributions: Bool
    public var hasSocialSecurity: Bool
    public var hasSelfEmployment: Bool
    public var hasRental: Bool
    public var hasUnemployment: Bool
    public var hasOtherIncome: Bool

    public init(
        hasW2: Bool,
        hasInterest: Bool,
        hasDividends: Bool,
        hasCapitalGains: Bool,
        hasRetirementDistributions: Bool,
        hasSocialSecurity: Bool,
        hasSelfEmployment: Bool,
        hasRental: Bool,
        hasUnemployment: Bool,
        hasOtherIncome: Bool
    ) {
        self.hasW2 = hasW2
        self.hasInterest = hasInterest
        self.hasDividends = hasDividends
        self.hasCapitalGains = hasCapitalGains
        self.hasRetirementDistributions = hasRetirementDistributions
        self.hasSocialSecurity = hasSocialSecurity
        self.hasSelfEmployment = hasSelfEmployment
        self.hasRental = hasRental
        self.hasUnemployment = hasUnemployment
        self.hasOtherIncome = hasOtherIncome
    }
}

/// Container for all income on the return.
public struct IncomeData: Codable, Equatable {
    public var w2: [W2]
    public var f1099Int: [Form1099Int]
    public var f1099Div: [Form1099Div]
    public var f1099B: [CapitalTransaction]
    public var f1099R: [Form1099R]
    public var f1099Ssa: [Form1099Ssa]
    public var f1099Nec: [Form1099Nec]
    public var f1099Misc: [Form1099Misc]
    public var f1099G: [Form1099G]
    public var f1099Sa: [Form1099Sa]
    public var scheduleC: [ScheduleC]
    public var scheduleE: [ScheduleE]
    /// Catch-all other income (Schedule 1 line 8z).
    public var otherIncome: Double
    /// Prior-year capital loss carryover into 2024 (Schedule D).
    public var capitalLossCarryoverShort: Double
    public var capitalLossCarryoverLong: Double
    /// Gating flags driven by the interview; the engine only reads gated sources.
    public var flags: IncomeFlags

    public init(
        w2: [W2],
        f1099Int: [Form1099Int],
        f1099Div: [Form1099Div],
        f1099B: [CapitalTransaction],
        f1099R: [Form1099R],
        f1099Ssa: [Form1099Ssa],
        f1099Nec: [Form1099Nec],
        f1099Misc: [Form1099Misc],
        f1099G: [Form1099G],
        f1099Sa: [Form1099Sa],
        scheduleC: [ScheduleC],
        scheduleE: [ScheduleE],
        otherIncome: Double,
        capitalLossCarryoverShort: Double,
        capitalLossCarryoverLong: Double,
        flags: IncomeFlags
    ) {
        self.w2 = w2
        self.f1099Int = f1099Int
        self.f1099Div = f1099Div
        self.f1099B = f1099B
        self.f1099R = f1099R
        self.f1099Ssa = f1099Ssa
        self.f1099Nec = f1099Nec
        self.f1099Misc = f1099Misc
        self.f1099G = f1099G
        self.f1099Sa = f1099Sa
        self.scheduleC = scheduleC
        self.scheduleE = scheduleE
        self.otherIncome = otherIncome
        self.capitalLossCarryoverShort = capitalLossCarryoverShort
        self.capitalLossCarryoverLong = capitalLossCarryoverLong
        self.flags = flags
    }
}

// MARK: - adjustments.ts

/// HSA coverage type. TS: `"self-only" | "family" | "none"`.
public enum HsaCoverage: String, Codable, Equatable {
    case selfOnly = "self-only"
    case family = "family"
    case none = "none"
}

/**
 * Above-the-line adjustments to income — Schedule 1 Part II.
 * These reduce gross income to arrive at AGI.
 */
public struct Adjustments: Codable, Equatable {
    /// Educator expenses — up to $300 ($600 MFJ if both educators). Sch 1 line 11.
    public var educatorExpenses: Double
    /// HSA contributions (Form 8889), excluding employer/cafeteria-plan amounts. Sch 1 line 13.
    public var hsaContribution: Double
    /// Whether HSA coverage is self-only or family (limits differ).
    public var hsaCoverage: HsaCoverage
    /// Deductible self-employed SEP/SIMPLE/qualified plan contributions. Sch 1 line 16.
    public var sepSimpleContribution: Double
    /// Self-employed health insurance premiums. Sch 1 line 17.
    public var selfEmployedHealthInsurance: Double
    /// Traditional IRA contributions the filer wants to deduct. Sch 1 line 20.
    public var traditionalIraContribution: Double
    /// Whether the taxpayer is covered by a workplace retirement plan (affects IRA deductibility).
    public var coveredByWorkplacePlan: Bool
    /// Whether the spouse is covered by a workplace plan (MFJ).
    public var spouseCoveredByWorkplacePlan: Bool
    /// Student loan interest paid — up to $2,500, MAGI phaseout. Sch 1 line 21.
    public var studentLoanInterest: Double

    public init(
        educatorExpenses: Double,
        hsaContribution: Double,
        hsaCoverage: HsaCoverage,
        sepSimpleContribution: Double,
        selfEmployedHealthInsurance: Double,
        traditionalIraContribution: Double,
        coveredByWorkplacePlan: Bool,
        spouseCoveredByWorkplacePlan: Bool,
        studentLoanInterest: Double
    ) {
        self.educatorExpenses = educatorExpenses
        self.hsaContribution = hsaContribution
        self.hsaCoverage = hsaCoverage
        self.sepSimpleContribution = sepSimpleContribution
        self.selfEmployedHealthInsurance = selfEmployedHealthInsurance
        self.traditionalIraContribution = traditionalIraContribution
        self.coveredByWorkplacePlan = coveredByWorkplacePlan
        self.spouseCoveredByWorkplacePlan = spouseCoveredByWorkplacePlan
        self.studentLoanInterest = studentLoanInterest
    }
}

// MARK: - deductions.ts

/**
 * Itemized deductions — Schedule A.
 * The engine compares the itemized total (with all IRS limits applied) against
 * the standard deduction and uses the larger, unless MFS forces a match.
 */
public struct ItemizedDeductions: Codable, Equatable {
    /// Unreimbursed medical/dental expenses (subject to 7.5%-of-AGI floor). Sch A line 1.
    public var medicalExpenses: Double
    /// State & local income (or sales) taxes paid. Part of the SALT cap. Sch A line 5a.
    public var stateLocalIncomeOrSalesTax: Double
    /// Real estate (property) taxes. Part of the SALT cap. Sch A line 5b.
    public var realEstateTaxes: Double
    /// Personal property taxes. Part of the SALT cap. Sch A line 5c.
    public var personalPropertyTaxes: Double
    /// Home mortgage interest (subject to the $750k acquisition-debt limit). Sch A line 8.
    public var mortgageInterest: Double
    /// Mortgage balance — used to apply the $750k interest-deductibility limit.
    public var mortgageBalance: Double
    /// Whether the mortgage originated after 12/15/2017 ($750k limit vs $1M grandfathered).
    public var mortgageAfterDec2017: Bool
    /// Cash charitable contributions (60%-of-AGI limit). Sch A line 11.
    public var charitableCash: Double
    /// Non-cash / appreciated-property contributions (30%-of-AGI limit). Sch A line 12.
    public var charitableNonCash: Double
    /// Casualty/theft losses from a federally declared disaster. Sch A line 15.
    public var casualtyLosses: Double

    public init(
        medicalExpenses: Double,
        stateLocalIncomeOrSalesTax: Double,
        realEstateTaxes: Double,
        personalPropertyTaxes: Double,
        mortgageInterest: Double,
        mortgageBalance: Double,
        mortgageAfterDec2017: Bool,
        charitableCash: Double,
        charitableNonCash: Double,
        casualtyLosses: Double
    ) {
        self.medicalExpenses = medicalExpenses
        self.stateLocalIncomeOrSalesTax = stateLocalIncomeOrSalesTax
        self.realEstateTaxes = realEstateTaxes
        self.personalPropertyTaxes = personalPropertyTaxes
        self.mortgageInterest = mortgageInterest
        self.mortgageBalance = mortgageBalance
        self.mortgageAfterDec2017 = mortgageAfterDec2017
        self.charitableCash = charitableCash
        self.charitableNonCash = charitableNonCash
        self.casualtyLosses = casualtyLosses
    }
}

// MARK: - credits.ts

/// A student for education credits (Form 8863).
public struct EducationStudent: Codable, Equatable {
    public var id: String
    public var name: String
    /// Qualified tuition & related expenses paid in 2024.
    public var qualifiedExpenses: Double
    /// At least half-time, in a degree program, first 4 years → AOTC eligible.
    public var aotcEligible: Bool
    /// Number of prior years AOTC has been claimed (4-year lifetime limit).
    public var priorAotcYears: Double
    /// Has a felony drug conviction (disqualifies AOTC).
    public var felonyDrugConviction: Bool

    public init(
        id: String,
        name: String,
        qualifiedExpenses: Double,
        aotcEligible: Bool,
        priorAotcYears: Double,
        felonyDrugConviction: Bool
    ) {
        self.id = id
        self.name = name
        self.qualifiedExpenses = qualifiedExpenses
        self.aotcEligible = aotcEligible
        self.priorAotcYears = priorAotcYears
        self.felonyDrugConviction = felonyDrugConviction
    }
}

/// Child & Dependent Care Credit inputs (Form 2441).
public struct CareCredit: Codable, Equatable {
    /// Total qualifying care expenses paid.
    public var expenses: Double
    /// Taxpayer's earned income (limits the credit).
    public var taxpayerEarnedIncome: Double
    /// Spouse's earned income (MFJ; both must have earned income).
    public var spouseEarnedIncome: Double
    /// Dependent care benefits received from an employer (W-2 box 10).
    public var employerBenefits: Double

    public init(
        expenses: Double,
        taxpayerEarnedIncome: Double,
        spouseEarnedIncome: Double,
        employerBenefits: Double
    ) {
        self.expenses = expenses
        self.taxpayerEarnedIncome = taxpayerEarnedIncome
        self.spouseEarnedIncome = spouseEarnedIncome
        self.employerBenefits = employerBenefits
    }
}

/// Container for all credit-specific inputs.
public struct CreditInputs: Codable, Equatable {
    /// Education credits.
    public var students: [EducationStudent]
    public var hasEducationExpenses: Bool
    /// Child & dependent care.
    public var care: CareCredit
    public var hasCareExpenses: Bool
    /// Retirement Savings Contributions Credit (Form 8880) — voluntary contributions.
    public var retirementContributions: Double
    public var isFullTimeStudent: Bool
    /// Residential Clean Energy Credit (Form 5695) — qualified property cost.
    public var cleanEnergyCost: Double
    /// New clean vehicle / EV credit (Form 8936).
    public var evCreditAmount: Double
    /// Foreign tax paid (Form 1116 / direct credit).
    public var foreignTaxPaid: Double
    /// ACA marketplace: advance Premium Tax Credit reconciliation (Form 8962 / 1095-A).
    public var hasMarketplaceCoverage: Bool
    public var advancePremiumTaxCredit: Double
    public var premiumTaxCreditAllowed: Double

    public init(
        students: [EducationStudent],
        hasEducationExpenses: Bool,
        care: CareCredit,
        hasCareExpenses: Bool,
        retirementContributions: Double,
        isFullTimeStudent: Bool,
        cleanEnergyCost: Double,
        evCreditAmount: Double,
        foreignTaxPaid: Double,
        hasMarketplaceCoverage: Bool,
        advancePremiumTaxCredit: Double,
        premiumTaxCreditAllowed: Double
    ) {
        self.students = students
        self.hasEducationExpenses = hasEducationExpenses
        self.care = care
        self.hasCareExpenses = hasCareExpenses
        self.retirementContributions = retirementContributions
        self.isFullTimeStudent = isFullTimeStudent
        self.cleanEnergyCost = cleanEnergyCost
        self.evCreditAmount = evCreditAmount
        self.foreignTaxPaid = foreignTaxPaid
        self.hasMarketplaceCoverage = hasMarketplaceCoverage
        self.advancePremiumTaxCredit = advancePremiumTaxCredit
        self.premiumTaxCreditAllowed = premiumTaxCreditAllowed
    }
}

// MARK: - payments.ts

/**
 * Tax payments and prior-year data (Form 1040 lines 25–26 + Form 2210 safe harbor).
 */
public struct Payments: Codable, Equatable {
    /**
     * Additional federal income tax withheld NOT already captured on W-2 box 2 or
     * 1099 withholding boxes (the engine sums those from the income forms). Use this
     * for any withholding the user enters directly. Sch line / 1040 line 25.
     */
    public var additionalWithholding: Double
    /// 2024 estimated tax payments made (Form 1040-ES). Line 26.
    public var estimatedPayments: Double
    /// Prior-year (2023) total tax — for the 2210 safe harbor (100%/110%).
    public var priorYearTax: Double?
    /// Prior-year (2023) AGI — determines whether the 110% safe harbor applies.
    public var priorYearAgi: Double?

    public init(
        additionalWithholding: Double,
        estimatedPayments: Double,
        priorYearTax: Double? = nil,
        priorYearAgi: Double? = nil
    ) {
        self.additionalWithholding = additionalWithholding
        self.estimatedPayments = estimatedPayments
        self.priorYearTax = priorYearTax
        self.priorYearAgi = priorYearAgi
    }
}

/// Account type for direct deposit. TS: `"checking" | "savings"`.
public enum BankAccountType: String, Codable, Equatable {
    case checking
    case savings
}

/// Bank info for direct deposit / payment. SENSITIVE — never persisted.
public struct BankInfo: Codable, Equatable {
    public var routingNumber: String
    public var accountNumber: String
    public var accountType: BankAccountType

    public init(
        routingNumber: String,
        accountNumber: String,
        accountType: BankAccountType
    ) {
        self.routingNumber = routingNumber
        self.accountNumber = accountNumber
        self.accountType = accountType
    }
}

// MARK: - taxReturn.ts

/// `meta` block on TaxReturn2024. TS: `{ taxYear: 2024; lastEdited: string }`.
public struct TaxReturnMeta: Codable, Equatable {
    /// TS literal type `2024`. Defaults to 2024.
    public var taxYear: Int
    public var lastEdited: String

    public init(taxYear: Int = 2024, lastEdited: String) {
        self.taxYear = taxYear
        self.lastEdited = lastEdited
    }
}

/// `residency` block on TaxReturn2024.
/// TS: `{ state: StateCode | ""; partYearResident: boolean; stateWithholding: number }`.
public struct Residency: Codable, Equatable {
    /// TS: `StateCode | ""` — empty represented by `nil`.
    public var state: StateCode?
    public var partYearResident: Bool
    public var stateWithholding: Double

    public init(state: StateCode? = nil, partYearResident: Bool, stateWithholding: Double) {
        self.state = state
        self.partYearResident = partYearResident
        self.stateWithholding = stateWithholding
    }
}

/// The single source of truth that flows through the entire engine.
public struct TaxReturn2024: Codable, Equatable {
    public var meta: TaxReturnMeta
    public var taxpayer: TaxpayerInfo
    public var spouse: TaxpayerInfo?
    public var address: Address
    public var filingStatus: FilingStatus
    public var dependents: [Dependent]
    public var residency: Residency
    /// MFS only: lived apart from spouse for ALL of 2024 (affects SS taxability base amounts).
    public var livedApartFromSpouse: Bool
    public var income: IncomeData
    public var adjustments: Adjustments
    public var itemized: ItemizedDeductions
    /// Force itemizing even when standard is larger (e.g. MFS spouse itemized).
    public var forceItemize: Bool
    public var credits: CreditInputs
    public var payments: Payments
    /// SENSITIVE — never persisted.
    public var bank: BankInfo?

    public init(
        meta: TaxReturnMeta,
        taxpayer: TaxpayerInfo,
        spouse: TaxpayerInfo? = nil,
        address: Address,
        filingStatus: FilingStatus,
        dependents: [Dependent],
        residency: Residency,
        livedApartFromSpouse: Bool,
        income: IncomeData,
        adjustments: Adjustments,
        itemized: ItemizedDeductions,
        forceItemize: Bool,
        credits: CreditInputs,
        payments: Payments,
        bank: BankInfo? = nil
    ) {
        self.meta = meta
        self.taxpayer = taxpayer
        self.spouse = spouse
        self.address = address
        self.filingStatus = filingStatus
        self.dependents = dependents
        self.residency = residency
        self.livedApartFromSpouse = livedApartFromSpouse
        self.income = income
        self.adjustments = adjustments
        self.itemized = itemized
        self.forceItemize = forceItemize
        self.credits = credits
        self.payments = payments
        self.bank = bank
    }
}

/// TS: `emptyTaxpayer()` — private helper that returns a clean `TaxpayerInfo`.
private func emptyTaxpayer() -> TaxpayerInfo {
    return TaxpayerInfo(
        firstName: "",
        lastName: "",
        ssn: "",
        dateOfBirth: "",
        occupation: "",
        blind: false,
        claimedAsDependentByAnother: false
    )
}

/// Factory for a fresh, empty 2024 return.
public func makeEmptyReturn() -> TaxReturn2024 {
    return TaxReturn2024(
        meta: TaxReturnMeta(taxYear: 2024, lastEdited: ""),
        taxpayer: emptyTaxpayer(),
        spouse: nil,
        address: Address(line1: "", line2: nil, city: "", state: nil, zip: ""),
        filingStatus: .single,
        dependents: [],
        residency: Residency(state: nil, partYearResident: false, stateWithholding: 0),
        livedApartFromSpouse: false,
        income: IncomeData(
            w2: [],
            f1099Int: [],
            f1099Div: [],
            f1099B: [],
            f1099R: [],
            f1099Ssa: [],
            f1099Nec: [],
            f1099Misc: [],
            f1099G: [],
            f1099Sa: [],
            scheduleC: [],
            scheduleE: [],
            otherIncome: 0,
            capitalLossCarryoverShort: 0,
            capitalLossCarryoverLong: 0,
            flags: IncomeFlags(
                hasW2: false,
                hasInterest: false,
                hasDividends: false,
                hasCapitalGains: false,
                hasRetirementDistributions: false,
                hasSocialSecurity: false,
                hasSelfEmployment: false,
                hasRental: false,
                hasUnemployment: false,
                hasOtherIncome: false
            )
        ),
        adjustments: Adjustments(
            educatorExpenses: 0,
            hsaContribution: 0,
            hsaCoverage: .none,
            sepSimpleContribution: 0,
            selfEmployedHealthInsurance: 0,
            traditionalIraContribution: 0,
            coveredByWorkplacePlan: false,
            spouseCoveredByWorkplacePlan: false,
            studentLoanInterest: 0
        ),
        itemized: ItemizedDeductions(
            medicalExpenses: 0,
            stateLocalIncomeOrSalesTax: 0,
            realEstateTaxes: 0,
            personalPropertyTaxes: 0,
            mortgageInterest: 0,
            mortgageBalance: 0,
            mortgageAfterDec2017: true,
            charitableCash: 0,
            charitableNonCash: 0,
            casualtyLosses: 0
        ),
        forceItemize: false,
        credits: CreditInputs(
            students: [],
            hasEducationExpenses: false,
            care: CareCredit(
                expenses: 0,
                taxpayerEarnedIncome: 0,
                spouseEarnedIncome: 0,
                employerBenefits: 0
            ),
            hasCareExpenses: false,
            retirementContributions: 0,
            isFullTimeStudent: false,
            cleanEnergyCost: 0,
            evCreditAmount: 0,
            foreignTaxPaid: 0,
            hasMarketplaceCoverage: false,
            advancePremiumTaxCredit: 0,
            premiumTaxCreditAllowed: 0
        ),
        payments: Payments(
            additionalWithholding: 0,
            estimatedPayments: 0
        ),
        bank: nil
    )
}

// MARK: - result.ts

/// One line in the computed return — drives the Review screen and golden tests.
public struct LineTrace: Codable, Equatable {
    /// Stable key, e.g. "agi", "regularTax", "ctc".
    public var id: String
    /// Human label, e.g. "Adjusted gross income".
    public var label: String
    /// IRS form/line reference, e.g. "Form 1040, line 11".
    public var formRef: String
    /// Dollar amount (whole dollars after IRS rounding).
    public var amount: Double

    public init(id: String, label: String, formRef: String, amount: Double) {
        self.id = id
        self.label = label
        self.formRef = formRef
        self.amount = amount
    }
}

/// A user-facing warning for a path the engine does not fully model.
public struct Warning: Codable, Equatable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// Severity for an AuditFlag. TS: `"info" | "warn" | "high"`.
public enum AuditSeverity: String, Codable, Equatable {
    case info
    case warn
    case high
}

/// An audit-risk / data-quality flag surfaced in the UI.
public struct AuditFlag: Codable, Equatable {
    public var severity: AuditSeverity
    public var message: String
    /// Related trace line id, if any.
    public var relatedLine: String?

    public init(severity: AuditSeverity, message: String, relatedLine: String? = nil) {
        self.severity = severity
        self.message = message
        self.relatedLine = relatedLine
    }
}

/// The MAGI variants different rules require (they are NOT all the same number).
public struct MagiBreakdown: Codable, Equatable {
    public var niit: Double
    public var ira: Double
    public var studentLoan: Double
    public var ptc: Double
    public var ctc: Double
    public var aotc: Double

    public init(
        niit: Double,
        ira: Double,
        studentLoan: Double,
        ptc: Double,
        ctc: Double,
        aotc: Double
    ) {
        self.niit = niit
        self.ira = ira
        self.studentLoan = studentLoan
        self.ptc = ptc
        self.ctc = ctc
        self.aotc = aotc
    }
}

/// State result (absent for federal-only or states not yet supported).
public struct StateResult: Codable, Equatable {
    public var code: StateCode
    public var name: String
    /// False for no-income-tax states (TX, FL, WA, TN, …).
    public var hasIncomeTax: Bool
    /// False when the state isn't in the supported set yet (tax left at 0).
    public var supported: Bool
    public var stateAgi: Double
    public var taxableIncome: Double
    public var tax: Double
    public var withheld: Double
    /// Positive = refund; negative = balance due.
    public var refundOrOwed: Double
    public var note: String?

    public init(
        code: StateCode,
        name: String,
        hasIncomeTax: Bool,
        supported: Bool,
        stateAgi: Double,
        taxableIncome: Double,
        tax: Double,
        withheld: Double,
        refundOrOwed: Double,
        note: String? = nil
    ) {
        self.code = code
        self.name = name
        self.hasIncomeTax = hasIncomeTax
        self.supported = supported
        self.stateAgi = stateAgi
        self.taxableIncome = taxableIncome
        self.tax = tax
        self.withheld = withheld
        self.refundOrOwed = refundOrOwed
        self.note = note
    }
}

/// Which deduction the engine used. TS: `"standard" | "itemized"`.
public enum DeductionUsed: String, Codable, Equatable {
    case standard
    case itemized
}

/// Capital-loss carryover block. TS: `{ shortTerm: number; longTerm: number }`.
public struct CapitalLossCarryover: Codable, Equatable {
    public var shortTerm: Double
    public var longTerm: Double

    public init(shortTerm: Double, longTerm: Double) {
        self.shortTerm = shortTerm
        self.longTerm = longTerm
    }
}

/// Output of the pure calculation engine.
public struct TaxCalculationResult: Codable, Equatable {
    public var filingStatus: FilingStatus

    // Income & AGI
    public var totalIncome: Double
    public var totalAdjustments: Double
    public var agi: Double
    public var magi: MagiBreakdown

    // Deductions
    public var standardDeduction: Double
    public var itemizedDeduction: Double
    public var deductionUsed: DeductionUsed
    public var deductionAmount: Double
    /// Extra tax saved by itemizing vs standard (0 if standard chosen).
    public var itemizedSavings: Double

    // QBI & taxable income
    public var qbiDeduction: Double
    public var taxableIncomeBeforeQbi: Double
    public var taxableIncome: Double

    // Tax computation
    public var regularTax: Double
    public var usedTaxTable: Bool
    public var usedQualDivWorksheet: Bool
    public var amt: Double
    public var additionalMedicareTax: Double
    public var niit: Double
    public var seTax: Double

    // Credits
    public var nonrefundableCredits: [String: Double]
    public var totalNonrefundableCredits: Double
    public var refundableCredits: [String: Double]
    public var totalRefundableCredits: Double

    // Totals
    public var otherTaxes: Double
    public var totalTax: Double
    public var totalPayments: Double
    /// Positive = refund; negative = balance due.
    public var refundOrOwed: Double
    public var owes: Bool
    public var underpaymentPenalty: Double

    // Rates
    public var marginalRate: Double
    public var effectiveRate: Double

    // Carryovers & diagnostics
    public var capitalLossCarryover: CapitalLossCarryover
    public var trace: [LineTrace]
    public var warnings: [Warning]
    public var auditFlags: [AuditFlag]

    // State (optional)
    public var state: StateResult?

    public init(
        filingStatus: FilingStatus,
        totalIncome: Double,
        totalAdjustments: Double,
        agi: Double,
        magi: MagiBreakdown,
        standardDeduction: Double,
        itemizedDeduction: Double,
        deductionUsed: DeductionUsed,
        deductionAmount: Double,
        itemizedSavings: Double,
        qbiDeduction: Double,
        taxableIncomeBeforeQbi: Double,
        taxableIncome: Double,
        regularTax: Double,
        usedTaxTable: Bool,
        usedQualDivWorksheet: Bool,
        amt: Double,
        additionalMedicareTax: Double,
        niit: Double,
        seTax: Double,
        nonrefundableCredits: [String: Double],
        totalNonrefundableCredits: Double,
        refundableCredits: [String: Double],
        totalRefundableCredits: Double,
        otherTaxes: Double,
        totalTax: Double,
        totalPayments: Double,
        refundOrOwed: Double,
        owes: Bool,
        underpaymentPenalty: Double,
        marginalRate: Double,
        effectiveRate: Double,
        capitalLossCarryover: CapitalLossCarryover,
        trace: [LineTrace],
        warnings: [Warning],
        auditFlags: [AuditFlag],
        state: StateResult? = nil
    ) {
        self.filingStatus = filingStatus
        self.totalIncome = totalIncome
        self.totalAdjustments = totalAdjustments
        self.agi = agi
        self.magi = magi
        self.standardDeduction = standardDeduction
        self.itemizedDeduction = itemizedDeduction
        self.deductionUsed = deductionUsed
        self.deductionAmount = deductionAmount
        self.itemizedSavings = itemizedSavings
        self.qbiDeduction = qbiDeduction
        self.taxableIncomeBeforeQbi = taxableIncomeBeforeQbi
        self.taxableIncome = taxableIncome
        self.regularTax = regularTax
        self.usedTaxTable = usedTaxTable
        self.usedQualDivWorksheet = usedQualDivWorksheet
        self.amt = amt
        self.additionalMedicareTax = additionalMedicareTax
        self.niit = niit
        self.seTax = seTax
        self.nonrefundableCredits = nonrefundableCredits
        self.totalNonrefundableCredits = totalNonrefundableCredits
        self.refundableCredits = refundableCredits
        self.totalRefundableCredits = totalRefundableCredits
        self.otherTaxes = otherTaxes
        self.totalTax = totalTax
        self.totalPayments = totalPayments
        self.refundOrOwed = refundOrOwed
        self.owes = owes
        self.underpaymentPenalty = underpaymentPenalty
        self.marginalRate = marginalRate
        self.effectiveRate = effectiveRate
        self.capitalLossCarryover = capitalLossCarryover
        self.trace = trace
        self.warnings = warnings
        self.auditFlags = auditFlags
        self.state = state
    }
}

// MARK: - question.ts

/// TS: `type AnswerValue = string | number | boolean`.
/// Modeled as an enum since Swift has no untagged union.
public enum AnswerValue: Equatable {
    case string(String)
    case number(Double)
    case boolean(Bool)
}

/// TS: `type Answers = Record<string, AnswerValue>`.
public typealias Answers = [String: AnswerValue]

/// TS: `type InputType = "boolean" | "dollar" | "integer" | "select" | "text"`.
public enum InputType: String, Codable, Equatable {
    case boolean
    case dollar
    case integer
    case select
    case text
}

public struct QuestionOption: Codable, Equatable {
    public var value: String
    public var label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

/// An interview question. `dependsOn` is a pure predicate over the live answers —
/// ported as a Swift closure (not Codable/Equatable for that reason).
public struct Question {
    public var id: String
    public var sectionId: String
    /// Plain-English label, phrased like TurboTax — not government-form language.
    public var text: String
    /// "Why we ask" + the IRS form/line this feeds.
    public var helpText: String?
    public var inputType: InputType
    public var options: [QuestionOption]?
    public var placeholder: String?
    /// Pure predicate over the live answers — true means show this question.
    public var dependsOn: ((Answers) -> Bool)?
    /// SENSITIVE (SSN, bank) — never persisted to localStorage.
    public var sensitive: Bool?
    /// Allow negative values (e.g. capital gains/losses).
    public var allowNegative: Bool?

    public init(
        id: String,
        sectionId: String,
        text: String,
        helpText: String? = nil,
        inputType: InputType,
        options: [QuestionOption]? = nil,
        placeholder: String? = nil,
        dependsOn: ((Answers) -> Bool)? = nil,
        sensitive: Bool? = nil,
        allowNegative: Bool? = nil
    ) {
        self.id = id
        self.sectionId = sectionId
        self.text = text
        self.helpText = helpText
        self.inputType = inputType
        self.options = options
        self.placeholder = placeholder
        self.dependsOn = dependsOn
        self.sensitive = sensitive
        self.allowNegative = allowNegative
    }
}

/// An interview section. `dependsOn` is a closure (not Codable/Equatable).
public struct Section {
    public var id: String
    public var title: String
    public var description: String?
    /// lucide-react icon name.
    public var icon: String?
    /// Section-level gate — hidden entirely when false.
    public var dependsOn: ((Answers) -> Bool)?

    public init(
        id: String,
        title: String,
        description: String? = nil,
        icon: String? = nil,
        dependsOn: ((Answers) -> Bool)? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.dependsOn = dependsOn
    }
}
