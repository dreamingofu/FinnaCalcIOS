/**
 * Questions.swift
 *
 * Pure-Swift port of the FinnaCalc tax-engine interview data
 * (components/tax-engine/questions/{sections.ts, questionBank.ts,
 * questionRouter.ts, buildReturn.ts}). Foundation-only — no SwiftUI/UIKit.
 *
 * Faithful 1:1 mirror of the TypeScript: same section ids, question ids,
 * input types, options, dependsOn predicates, and the same answer->field
 * mapping in buildReturn. TS `AnswerValue = string | number | boolean` is the
 * `AnswerValue` enum from TaxModels.swift; reading helpers mirror the TS
 * `n`/`b`/`intOf` coercions exactly (only `.number` is numeric, only `.boolean`
 * true is truthy, only `.string` is a string).
 */

import Foundation

// MARK: - Answer-coercion helpers (mirror buildReturn.ts / questionBank.ts)

/// TS: `n(a, id) = typeof a[id] === "number" ? a[id] : 0`.
private func n(_ a: Answers, _ id: String) -> Double {
    if case let .number(v)? = a[id] { return v }
    return 0
}

/// TS: `b(a, id) = a[id] === true`.
private func b(_ a: Answers, _ id: String) -> Bool {
    if case .boolean(true)? = a[id] { return true }
    return false
}

/// TS: `intOf(a, id) = Math.max(0, Math.floor(n(a, id)))`.
private func intOf(_ a: Answers, _ id: String) -> Int {
    return max(0, Int(floor(n(a, id))))
}

/// TS: `typeof a[id] === "string" ? a[id] : nil`.
private func str(_ a: Answers, _ id: String) -> String? {
    if case let .string(v)? = a[id] { return v }
    return nil
}

// MARK: - sections.ts

/// TS: `truthy = (v) => v === true`.
private func truthy(_ a: Answers, _ id: String) -> Bool {
    if case .boolean(true)? = a[id] { return true }
    return false
}

public let SECTIONS: [Section] = [
    Section(id: "about-you", title: "About you", description: "Filing status and a few basics.", icon: "User"),
    Section(
        id: "dependents",
        title: "Family & dependents",
        description: "Children and others you support.",
        icon: "Users",
        dependsOn: { a in truthy(a, "ls_deps") }
    ),
    Section(
        id: "income-job",
        title: "Job income",
        description: "Wages from your W-2.",
        icon: "Briefcase",
        dependsOn: { a in truthy(a, "ls_job") }
    ),
    Section(
        id: "income-self",
        title: "Self-employment",
        description: "Freelance or business income.",
        icon: "Store",
        dependsOn: { a in truthy(a, "ls_self") }
    ),
    Section(
        id: "income-investments",
        title: "Investments",
        description: "Interest, dividends, and sales.",
        icon: "TrendingUp",
        dependsOn: { a in truthy(a, "ls_invest") }
    ),
    Section(
        id: "income-retirement",
        title: "Retirement & Social Security",
        description: "Pensions, IRAs, and benefits.",
        icon: "PiggyBank",
        dependsOn: { a in truthy(a, "ls_retire") }
    ),
    Section(id: "income-other", title: "Other income", description: "Anything else taxable.", icon: "Coins"),
    Section(id: "adjustments", title: "Adjustments", description: "Above-the-line deductions.", icon: "Sliders"),
    Section(id: "deductions", title: "Deductions", description: "Standard vs. itemized.", icon: "Receipt"),
    Section(
        id: "credits",
        title: "Credits",
        description: "Care, education, savings, and energy.",
        icon: "Gift",
        dependsOn: { a in
            truthy(a, "ls_care") || truthy(a, "ls_education") || truthy(a, "ls_energy") || truthy(a, "ls_savings")
        }
    ),
    Section(id: "payments", title: "Payments", description: "Withholding and estimates.", icon: "Wallet"),
]

// (Life Situations options are defined alongside the LifeSituations view in
// UI/TaxInsightViews.swift as LIFE_SITUATIONS: [LifeSituationOption].)

// MARK: - questionBank.ts

/// TS: `STATE_OPTIONS = SUPPORTED_STATES.map((s) => ({ value: s.code, label: s.name }))`.
private let STATE_OPTIONS: [QuestionOption] = SUPPORTED_STATES.map {
    QuestionOption(value: $0.code.rawValue, label: $0.name)
}

/// TS: `isMFS = (a) => a.q_filing === "mfs"`.
private func isMFS(_ a: Answers) -> Bool { str(a, "q_filing") == "mfs" }

/// TS: `isMarried = (a) => a.q_filing === "mfj" || a.q_filing === "qss"`.
private func isMarried(_ a: Answers) -> Bool {
    let f = str(a, "q_filing")
    return f == "mfj" || f == "qss"
}

public let QUESTION_BANK: [Question] = [
    // ---- About you ----
    Question(
        id: "q_filing",
        sectionId: "about-you",
        text: "What's your filing status?",
        helpText: "Your status sets your tax brackets and standard deduction.",
        inputType: .select,
        options: [
            QuestionOption(value: "single", label: "Single"),
            QuestionOption(value: "mfj", label: "Married filing jointly"),
            QuestionOption(value: "mfs", label: "Married filing separately"),
            QuestionOption(value: "hoh", label: "Head of household"),
            QuestionOption(value: "qss", label: "Qualifying surviving spouse"),
        ]
    ),
    Question(
        id: "q_lived_apart",
        sectionId: "about-you",
        text: "Did you live apart from your spouse for the entire tax year?",
        helpText: "Affects how your Social Security benefits and some credits are treated.",
        inputType: .boolean,
        dependsOn: isMFS
    ),
    Question(
        id: "q_age",
        sectionId: "about-you",
        text: "How old were you at the end of the tax year?",
        inputType: .integer,
        placeholder: "e.g. 40"
    ),
    Question(
        id: "q_blind",
        sectionId: "about-you",
        text: "Are you legally blind?",
        helpText: "Adds to your standard deduction.",
        inputType: .boolean
    ),
    Question(
        id: "q_spouse_age",
        sectionId: "about-you",
        text: "How old was your spouse at the end of the tax year?",
        inputType: .integer,
        dependsOn: isMarried
    ),
    Question(
        id: "q_spouse_blind",
        sectionId: "about-you",
        text: "Is your spouse legally blind?",
        inputType: .boolean,
        dependsOn: isMarried
    ),
    Question(
        id: "q_claimed_dependent",
        sectionId: "about-you",
        text: "Can someone else claim you as a dependent?",
        helpText: "If yes, your standard deduction may be limited.",
        inputType: .boolean
    ),
    Question(
        id: "q_state",
        sectionId: "about-you",
        text: "Which state did you live in?",
        helpText: "Adds a state income tax estimate (top 15 states). Leave blank to skip.",
        inputType: .select,
        options: STATE_OPTIONS
    ),

    // ---- Dependents ----
    Question(
        id: "q_qual_children",
        sectionId: "dependents",
        text: "How many qualifying children under 17 did you support?",
        helpText: "Each can qualify for the $2,000 Child Tax Credit.",
        inputType: .integer,
        placeholder: "0"
    ),
    Question(
        id: "q_other_deps",
        sectionId: "dependents",
        text: "How many other dependents did you support?",
        helpText: "Each can qualify for the $500 Credit for Other Dependents.",
        inputType: .integer,
        placeholder: "0"
    ),

    // ---- Job income ----
    Question(id: "q_wages", sectionId: "income-job", text: "Total wages (W-2 box 1)", inputType: .dollar),
    Question(id: "q_withholding", sectionId: "income-job", text: "Federal income tax withheld (W-2 box 2)", inputType: .dollar),

    // ---- Self-employment ----
    Question(
        id: "q_se_profit",
        sectionId: "income-self",
        text: "Net self-employment profit (after expenses)",
        inputType: .dollar,
        allowNegative: true
    ),
    Question(
        id: "q_se_sstb",
        sectionId: "income-self",
        text: "Is this a professional-service business (law, health, consulting, finance, etc.)?",
        helpText: "Specified service businesses lose the QBI deduction at higher incomes.",
        inputType: .boolean
    ),
    Question(id: "q_se_health", sectionId: "income-self", text: "Self-employed health insurance premiums", inputType: .dollar),

    // ---- Investments ----
    Question(id: "q_interest", sectionId: "income-investments", text: "Taxable interest (1099-INT box 1)", inputType: .dollar),
    Question(id: "q_tax_exempt", sectionId: "income-investments", text: "Tax-exempt interest (1099-INT box 8)", inputType: .dollar),
    Question(id: "q_ord_div", sectionId: "income-investments", text: "Ordinary dividends (1099-DIV box 1a)", inputType: .dollar),
    Question(
        id: "q_qual_div",
        sectionId: "income-investments",
        text: "Qualified dividends (1099-DIV box 1b)",
        helpText: "Taxed at lower capital-gains rates.",
        inputType: .dollar
    ),
    Question(id: "q_ltcg", sectionId: "income-investments", text: "Long-term capital gain or loss", inputType: .dollar, allowNegative: true),
    Question(id: "q_stcg", sectionId: "income-investments", text: "Short-term capital gain or loss", inputType: .dollar, allowNegative: true),
    Question(id: "q_capgain_dist", sectionId: "income-investments", text: "Capital gain distributions (1099-DIV box 2a)", inputType: .dollar),

    // ---- Retirement & Social Security ----
    Question(id: "q_ss_benefits", sectionId: "income-retirement", text: "Social Security benefits (1099-SSA box 5)", inputType: .dollar),
    Question(id: "q_retire_taxable", sectionId: "income-retirement", text: "Taxable pension/IRA distributions (1099-R box 2a)", inputType: .dollar),
    Question(
        id: "q_retire_early",
        sectionId: "income-retirement",
        text: "Was any of that an early withdrawal (under 59½, no exception)?",
        helpText: "Early withdrawals usually add a 10% penalty.",
        inputType: .boolean,
        dependsOn: { a in n(a, "q_retire_taxable") > 0 }
    ),

    // ---- Other income ----
    Question(id: "q_unemployment", sectionId: "income-other", text: "Unemployment compensation (1099-G)", inputType: .dollar),
    Question(id: "q_other_income", sectionId: "income-other", text: "Other taxable income", inputType: .dollar),

    // ---- Adjustments ----
    Question(id: "q_student_loan", sectionId: "adjustments", text: "Student loan interest paid", inputType: .dollar),
    Question(id: "q_educator", sectionId: "adjustments", text: "Educator (K-12) classroom expenses", inputType: .dollar),
    Question(
        id: "q_hsa_coverage",
        sectionId: "adjustments",
        text: "Did you have a high-deductible health plan (HSA)?",
        inputType: .select,
        options: [
            QuestionOption(value: "none", label: "No HSA"),
            QuestionOption(value: "self-only", label: "Self-only coverage"),
            QuestionOption(value: "family", label: "Family coverage"),
        ]
    ),
    Question(
        id: "q_hsa_contribution",
        sectionId: "adjustments",
        text: "HSA contribution",
        inputType: .dollar,
        dependsOn: { a in
            let c = str(a, "q_hsa_coverage")
            return c == "self-only" || c == "family"
        }
    ),
    Question(id: "q_ira_contribution", sectionId: "adjustments", text: "Traditional IRA contribution", inputType: .dollar),
    Question(
        id: "q_ira_covered",
        sectionId: "adjustments",
        text: "Are you covered by a workplace retirement plan?",
        inputType: .boolean,
        dependsOn: { a in n(a, "q_ira_contribution") > 0 }
    ),

    // ---- Deductions ----
    Question(
        id: "q_itemize",
        sectionId: "deductions",
        text: "Do you want to enter itemized deductions?",
        helpText: "We'll automatically use whichever is larger — standard or itemized.",
        inputType: .boolean
    ),
    Question(id: "q_mortgage_interest", sectionId: "deductions", text: "Home mortgage interest", inputType: .dollar, dependsOn: { a in b(a, "q_itemize") }),
    Question(id: "q_mortgage_balance", sectionId: "deductions", text: "Mortgage balance", inputType: .dollar, dependsOn: { a in b(a, "q_itemize") }),
    Question(id: "q_salt", sectionId: "deductions", text: "State & local income (or sales) tax", inputType: .dollar, dependsOn: { a in b(a, "q_itemize") }),
    Question(id: "q_property_tax", sectionId: "deductions", text: "Property taxes", inputType: .dollar, dependsOn: { a in b(a, "q_itemize") }),
    Question(id: "q_charitable", sectionId: "deductions", text: "Charitable contributions (cash)", inputType: .dollar, dependsOn: { a in b(a, "q_itemize") }),
    Question(id: "q_medical", sectionId: "deductions", text: "Medical & dental expenses", inputType: .dollar, dependsOn: { a in b(a, "q_itemize") }),

    // ---- Credits ----
    Question(id: "q_care_expenses", sectionId: "credits", text: "Child/dependent care expenses paid", inputType: .dollar, dependsOn: { a in b(a, "ls_care") }),
    Question(id: "q_care_children", sectionId: "credits", text: "How many children under 13 were in care?", inputType: .integer, placeholder: "0", dependsOn: { a in b(a, "ls_care") }),
    Question(id: "q_edu_expenses", sectionId: "credits", text: "Qualified tuition & fees paid", inputType: .dollar, dependsOn: { a in b(a, "ls_education") }),
    Question(
        id: "q_edu_aotc",
        sectionId: "credits",
        text: "Is the student in their first 4 years of an undergraduate degree?",
        helpText: "If yes, the more generous American Opportunity Credit applies.",
        inputType: .boolean,
        dependsOn: { a in b(a, "ls_education") }
    ),
    Question(id: "q_savers_contrib", sectionId: "credits", text: "Retirement contributions (for the Saver's Credit)", inputType: .dollar, dependsOn: { a in b(a, "ls_savings") }),
    Question(id: "q_clean_energy", sectionId: "credits", text: "Home clean-energy property cost (solar, etc.)", inputType: .dollar, dependsOn: { a in b(a, "ls_energy") }),
    Question(id: "q_ev_credit", sectionId: "credits", text: "Clean vehicle (EV) credit amount", inputType: .dollar, dependsOn: { a in b(a, "ls_energy") }),

    // ---- Payments ----
    Question(id: "q_est_payments", sectionId: "payments", text: "Estimated tax payments made", inputType: .dollar),
    Question(id: "q_extra_withholding", sectionId: "payments", text: "Other federal tax withheld (not on your W-2)", inputType: .dollar),
    Question(
        id: "q_state_withholding",
        sectionId: "payments",
        text: "State income tax withheld (W-2 box 17)",
        inputType: .dollar,
        dependsOn: { a in
            if let s = str(a, "q_state") { return s != "" }
            return false
        }
    ),
    Question(id: "q_prior_tax", sectionId: "payments", text: "Your 2023 total tax (for the underpayment check)", inputType: .dollar),
    Question(id: "q_prior_agi", sectionId: "payments", text: "Your 2023 AGI", inputType: .dollar),
]

// MARK: - questionRouter.ts

/// TS: `sectionById` lookup map.
private let sectionById: [String: Section] = {
    var m: [String: Section] = [:]
    for s in SECTIONS { m[s.id] = s }
    return m
}()

/// Is a single question currently visible (its section shows AND its own gate passes)?
/// TS: `isQuestionVisible`.
public func isQuestionVisible(_ q: Question, _ a: Answers) -> Bool {
    if let section = sectionById[q.sectionId], let gate = section.dependsOn, !gate(a) {
        return false
    }
    if let dep = q.dependsOn { return dep(a) }
    return true
}

/// Sections that currently pass their gate. TS: `getVisibleSections`.
public func getVisibleSections(_ a: Answers) -> [Section] {
    return SECTIONS.filter { s in
        guard let gate = s.dependsOn else { return true }
        return gate(a)
    }
}

/// Visible questions for a given section, in bank order. TS: `getQuestionsForSection`.
public func getQuestionsForSection(_ sectionId: String, _ a: Answers) -> [Question] {
    return QUESTION_BANK.filter { $0.sectionId == sectionId && isQuestionVisible($0, a) }
}

/// All visible questions across all visible sections. TS: `getVisibleQuestions`.
public func getVisibleQuestions(_ a: Answers) -> [Question] {
    return QUESTION_BANK.filter { isQuestionVisible($0, a) }
}

/**
 * Remove answers whose questions are no longer visible (e.g. the user unchecked a
 * life situation, or switched filing status away from MFS). Life-situation toggles
 * (ls_*) and any non-bank keys are preserved. Returns a new answers object.
 * TS: `pruneHidden`.
 */
public func pruneHidden(_ a: Answers) -> Answers {
    var next: Answers = [:]
    let bankIds = Set(QUESTION_BANK.map { $0.id })
    for (key, value) in a {
        if !bankIds.contains(key) {
            next[key] = value // ls_* and other non-question keys are kept
            continue
        }
        let q = QUESTION_BANK.first { $0.id == key }!
        if isQuestionVisible(q, a) { next[key] = value }
    }
    return next
}

/// Progress over the visible sections (0–100), given how many have been visited.
/// TS: `getProgress`.
public func getProgress(_ visitedSectionIds: [String], _ a: Answers) -> Int {
    let visible = getVisibleSections(a)
    if visible.isEmpty { return 0 }
    let visited = visible.filter { visitedSectionIds.contains($0.id) }.count
    return Int((Double(visited) / Double(visible.count) * 100).rounded())
}

// MARK: - buildReturn.ts

/// Convert an age at year-end 2024 into a mid-year DOB the engine can use.
/// TS: `dobFromAge`.
private func dobFromAge(_ age: Double) -> String {
    if age == 0 || age <= 0 { return "" }
    return "\(2024 - Int(age))-06-15"
}

/// Pure converter: interview answers → canonical TaxReturn2024.
/// TS: `buildReturn`.
public func buildReturn(_ a: Answers) -> TaxReturn2024 {
    var r = makeEmptyReturn()

    // ---- About you ----
    if let f = str(a, "q_filing"), let fs = FilingStatus(rawValue: f) {
        r.filingStatus = fs
    } else {
        r.filingStatus = .single
    }
    r.livedApartFromSpouse = b(a, "q_lived_apart")
    r.taxpayer.dateOfBirth = dobFromAge(n(a, "q_age"))
    r.taxpayer.blind = b(a, "q_blind")
    r.taxpayer.claimedAsDependentByAnother = b(a, "q_claimed_dependent")
    if r.filingStatus == .mfj || r.filingStatus == .qss {
        var sp = r.taxpayer
        sp.dateOfBirth = dobFromAge(n(a, "q_spouse_age"))
        sp.blind = b(a, "q_spouse_blind")
        r.spouse = sp
    }

    // ---- Dependents ----
    let kids = intOf(a, "q_qual_children")
    for i in 0..<max(0, kids) {
        r.dependents.append(Dependent(
            id: "qc-\(i)",
            firstName: "Child",
            lastName: "",
            ssn: "",
            dateOfBirth: "2018-01-01",
            relationshipType: .child,
            relationship: "child",
            monthsLivedWithTaxpayer: 12,
            taxpayerProvidedOverHalfSupport: true,
            qualifiesForCTC: true,
            qualifiesForODC: false,
            qualifiesForEITC: true,
            qualifiesForCareCredit: false
        ))
    }
    let otherDeps = intOf(a, "q_other_deps")
    for i in 0..<max(0, otherDeps) {
        r.dependents.append(Dependent(
            id: "od-\(i)",
            firstName: "Dependent",
            lastName: "",
            ssn: "",
            dateOfBirth: "1990-01-01",
            relationshipType: .relative,
            relationship: "relative",
            monthsLivedWithTaxpayer: 12,
            taxpayerProvidedOverHalfSupport: true,
            qualifiesForCTC: false,
            qualifiesForODC: true,
            qualifiesForEITC: false,
            qualifiesForCareCredit: false
        ))
    }

    // ---- Job income (W-2) ----
    let wages = n(a, "q_wages")
    let withholding = n(a, "q_withholding")
    if wages > 0 || withholding > 0 {
        r.income.flags.hasW2 = true
        r.income.w2.append(W2(
            id: "w2-0",
            owner: .taxpayer,
            employerName: "Employer",
            box1Wages: wages,
            box2FederalWithholding: withholding,
            box3SsWages: wages,
            box4SsWithheld: 0,
            box5MedicareWages: wages,
            box6MedicareWithheld: 0,
            box12: [],
            statutoryEmployee: false,
            box17StateWithholding: 0
        ))
    }

    // ---- Self-employment ----
    if n(a, "q_se_profit") != 0 {
        r.income.flags.hasSelfEmployment = true
        r.income.scheduleC.append(ScheduleC(
            id: "c-0",
            owner: .taxpayer,
            businessName: "Self-employment",
            description: "Business",
            grossReceipts: n(a, "q_se_profit"),
            costOfGoodsSold: 0,
            expenses: [:],
            homeOfficeDeduction: 0,
            vehicleExpense: 0,
            isSSTB: b(a, "q_se_sstb")
        ))
    }
    r.adjustments.selfEmployedHealthInsurance = n(a, "q_se_health")

    // ---- Investments ----
    let interest = n(a, "q_interest")
    let taxExempt = n(a, "q_tax_exempt")
    if interest > 0 || taxExempt > 0 {
        r.income.flags.hasInterest = true
        r.income.f1099Int.append(Form1099Int(
            id: "int-0",
            payer: "Bank",
            box1Interest: interest,
            box3UsTreasuryInterest: 0,
            box8TaxExemptInterest: taxExempt,
            box4FederalWithholding: 0
        ))
    }
    let ordDiv = n(a, "q_ord_div")
    let qualDiv = n(a, "q_qual_div")
    let capDist = n(a, "q_capgain_dist")
    if ordDiv > 0 || qualDiv > 0 || capDist > 0 {
        r.income.flags.hasDividends = true
        r.income.f1099Div.append(Form1099Div(
            id: "div-0",
            payer: "Brokerage",
            box1aOrdinaryDividends: max(ordDiv, qualDiv),
            box1bQualifiedDividends: qualDiv,
            box2aCapitalGainDistributions: capDist,
            box4FederalWithholding: 0
        ))
    }
    let ltcg = n(a, "q_ltcg")
    let stcg = n(a, "q_stcg")
    if ltcg != 0 || stcg != 0 {
        r.income.flags.hasCapitalGains = true
        if ltcg != 0 {
            r.income.f1099B.append(CapitalTransaction(
                id: "b-lt",
                description: "Long-term",
                proceeds: ltcg > 0 ? ltcg : 0,
                costBasis: ltcg < 0 ? -ltcg : 0,
                longTerm: true
            ))
        }
        if stcg != 0 {
            r.income.f1099B.append(CapitalTransaction(
                id: "b-st",
                description: "Short-term",
                proceeds: stcg > 0 ? stcg : 0,
                costBasis: stcg < 0 ? -stcg : 0,
                longTerm: false
            ))
        }
    }

    // ---- Retirement & Social Security ----
    if n(a, "q_ss_benefits") > 0 {
        r.income.flags.hasSocialSecurity = true
        r.income.f1099Ssa.append(Form1099Ssa(
            id: "ssa-0",
            owner: .taxpayer,
            box5NetBenefits: n(a, "q_ss_benefits"),
            federalWithholding: 0
        ))
    }
    if n(a, "q_retire_taxable") > 0 {
        r.income.flags.hasRetirementDistributions = true
        r.income.f1099R.append(Form1099R(
            id: "r-0",
            payer: "Plan",
            box1GrossDistribution: n(a, "q_retire_taxable"),
            box2aTaxableAmount: n(a, "q_retire_taxable"),
            box4FederalWithholding: 0,
            box7DistributionCode: b(a, "q_retire_early") ? "1" : "7",
            iraSepSimple: false
        ))
    }

    // ---- Other income ----
    if n(a, "q_unemployment") > 0 {
        r.income.flags.hasUnemployment = true
        r.income.f1099G.append(Form1099G(
            id: "g-0",
            payer: "State",
            box1Unemployment: n(a, "q_unemployment"),
            box2StateRefund: 0,
            box4FederalWithholding: 0
        ))
    }
    if n(a, "q_other_income") > 0 {
        r.income.flags.hasOtherIncome = true
        r.income.otherIncome = n(a, "q_other_income")
    }

    // ---- Adjustments ----
    r.adjustments.studentLoanInterest = n(a, "q_student_loan")
    r.adjustments.educatorExpenses = n(a, "q_educator")
    let hsa = str(a, "q_hsa_coverage")
    r.adjustments.hsaCoverage = (hsa == "self-only" || hsa == "family") ? (HsaCoverage(rawValue: hsa!) ?? .none) : .none
    r.adjustments.hsaContribution = n(a, "q_hsa_contribution")
    r.adjustments.traditionalIraContribution = n(a, "q_ira_contribution")
    r.adjustments.coveredByWorkplacePlan = b(a, "q_ira_covered")

    // ---- Deductions ----
    if b(a, "q_itemize") {
        r.itemized.mortgageInterest = n(a, "q_mortgage_interest")
        r.itemized.mortgageBalance = n(a, "q_mortgage_balance")
        r.itemized.stateLocalIncomeOrSalesTax = n(a, "q_salt")
        r.itemized.realEstateTaxes = n(a, "q_property_tax")
        r.itemized.charitableCash = n(a, "q_charitable")
        r.itemized.medicalExpenses = n(a, "q_medical")
    }

    // ---- Credits ----
    let careChildren = intOf(a, "q_care_children")
    if n(a, "q_care_expenses") > 0 && careChildren > 0 {
        r.credits.hasCareExpenses = true
        let earned = wages + max(0, n(a, "q_se_profit"))
        r.credits.care = CareCredit(
            expenses: n(a, "q_care_expenses"),
            taxpayerEarnedIncome: earned,
            spouseEarnedIncome: earned,
            employerBenefits: 0
        )
        var marked = 0
        for idx in r.dependents.indices {
            if marked >= careChildren { break }
            if r.dependents[idx].qualifiesForCTC {
                r.dependents[idx].qualifiesForCareCredit = true
                marked += 1
            }
        }
        if marked < careChildren {
            for i in marked..<careChildren {
                r.dependents.append(Dependent(
                    id: "care-\(i)",
                    firstName: "Child",
                    lastName: "",
                    ssn: "",
                    dateOfBirth: "2020-01-01",
                    relationshipType: .child,
                    relationship: "child",
                    monthsLivedWithTaxpayer: 12,
                    taxpayerProvidedOverHalfSupport: true,
                    qualifiesForCTC: false,
                    qualifiesForODC: false,
                    qualifiesForEITC: false,
                    qualifiesForCareCredit: true
                ))
            }
        }
    }
    if n(a, "q_edu_expenses") > 0 {
        r.credits.hasEducationExpenses = true
        r.credits.students = [
            EducationStudent(
                id: "s0",
                name: "Student",
                qualifiedExpenses: n(a, "q_edu_expenses"),
                aotcEligible: b(a, "q_edu_aotc"),
                priorAotcYears: 0,
                felonyDrugConviction: false
            )
        ]
    }
    r.credits.retirementContributions = n(a, "q_savers_contrib")
    r.credits.cleanEnergyCost = n(a, "q_clean_energy")
    r.credits.evCreditAmount = n(a, "q_ev_credit")

    // ---- State residency ----
    if let s = str(a, "q_state"), s != "" {
        r.residency.state = StateCode(rawValue: s)
        r.residency.stateWithholding = n(a, "q_state_withholding")
    }

    // ---- Payments ----
    r.payments.estimatedPayments = n(a, "q_est_payments")
    r.payments.additionalWithholding = n(a, "q_extra_withholding")
    if n(a, "q_prior_tax") > 0 { r.payments.priorYearTax = n(a, "q_prior_tax") }
    if n(a, "q_prior_agi") > 0 { r.payments.priorYearAgi = n(a, "q_prior_agi") }

    return r
}
