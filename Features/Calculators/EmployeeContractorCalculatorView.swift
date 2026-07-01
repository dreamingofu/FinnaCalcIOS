//
//  EmployeeContractorCalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/employee-contractor-calculator/page.tsx` —
//  compares the true total cost of an employee (salary + benefits + employer
//  payroll taxes + workers comp) against a contractor's annual cost, using the
//  page's exact 2024 tax rates and benefit benchmarks. Follows the
//  LoanCalculatorView exemplar and the CalcSupport toolkit.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum EmployeeContractorCalc {
    /// 2024 Social Security wage base (`SS_WAGE_BASE_2024`).
    static let ssWageBase2024: Double = 168_600

    struct EmployeeBreakdown {
        let salary: Double
        let healthDentalVision: Double
        let retirement401k: Double
        let ptoValue: Double
        let otherBenefits: Double
        let totalBenefits: Double
        let employerSS: Double
        let employerMedicare: Double
        let ficaTotal: Double
        let futaNet: Double
        let suta: Double
        let workersComp: Double
        let totalCost: Double
        let burdenRate: Double
    }

    struct ContractorBreakdown {
        let hourlyRate: Double
        let annualCost: Double
        let equivalentHourly: Double
    }

    struct Comparison {
        let employee: EmployeeBreakdown
        let contractor: ContractorBreakdown
        let savings: Double
        let savingsPercentage: Double
        /// "contractor" when savings > 0, otherwise "employee".
        let recommendation: String
        /// Echoed inputs for the contractor-detail line items.
        let hours: Double
        let weeks: Double
    }

    enum Result {
        case error(String)
        case comparison(Comparison)
    }

    /// Mirrors `calculateComparison()` exactly.
    static func compare(salary: String, contractorRate: String, hoursPerWeek: String, weeksPerYear: String) -> Result {
        let annualSalary = salary.calcValue
        let hourlyRate = contractorRate.calcValue
        // Web: `Number.parseFloat(hoursPerWeek) || 40` — empty/invalid falls back to 40.
        let hours = parseOr(hoursPerWeek, 40)
        let weeks = parseOr(weeksPerYear, 50)

        if annualSalary <= 0 || hourlyRate <= 0 {
            return .error("Please enter valid salary and hourly rate values.")
        }

        // Employer payroll taxes (2024)
        let ssSalary = min(annualSalary, ssWageBase2024)
        let employerSS = ssSalary * 0.062                  // Social Security: 6.2% up to $168,600
        let employerMedicare = annualSalary * 0.0145       // Medicare: 1.45% (no cap)
        let ficaTotal = employerSS + employerMedicare

        // FUTA (net after standard 5.4% state credit): 0.6% on first $7,000
        let futaNet = min(annualSalary, 7000) * 0.006      // = $42 max
        // SUTA varies by state; use 2% estimate as common midpoint
        let suta = min(annualSalary, 7000) * 0.02          // ≈ $140 max

        // Workers' compensation (2% of salary, industry average)
        let workersComp = annualSalary * 0.02

        // Benefits breakdown (employer costs, 2024 estimates)
        let healthDentalVision = min(annualSalary * 0.12, 10800) // ~$9k median employer health cost
        let retirement401k = annualSalary * 0.03           // 3% match (common baseline)
        let ptoValue = annualSalary * (15.0 / 260.0)       // 15 PTO days ≈ 5.77% of salary
        let otherBenefits = annualSalary * 0.02            // Life/disability/misc
        let totalBenefits = healthDentalVision + retirement401k + ptoValue + otherBenefits

        let totalEmployeeCost =
            annualSalary + totalBenefits + ficaTotal + workersComp + futaNet + suta

        let contractorAnnualCost = hourlyRate * hours * weeks
        let contractorEquivalentHourly = totalEmployeeCost / (hours * weeks)

        let savings = totalEmployeeCost - contractorAnnualCost
        let savingsPercentage = totalEmployeeCost > 0 ? (savings / totalEmployeeCost) * 100 : 0

        let employee = EmployeeBreakdown(
            salary: annualSalary,
            healthDentalVision: healthDentalVision,
            retirement401k: retirement401k,
            ptoValue: ptoValue,
            otherBenefits: otherBenefits,
            totalBenefits: totalBenefits,
            employerSS: employerSS,
            employerMedicare: employerMedicare,
            ficaTotal: ficaTotal,
            futaNet: futaNet,
            suta: suta,
            workersComp: workersComp,
            totalCost: totalEmployeeCost,
            burdenRate: ((totalEmployeeCost - annualSalary) / annualSalary) * 100
        )

        let contractor = ContractorBreakdown(
            hourlyRate: hourlyRate,
            annualCost: contractorAnnualCost,
            equivalentHourly: contractorEquivalentHourly
        )

        return .comparison(Comparison(
            employee: employee,
            contractor: contractor,
            savings: savings,
            savingsPercentage: savingsPercentage,
            recommendation: savings > 0 ? "contractor" : "employee",
            hours: hours,
            weeks: weeks
        ))
    }

    /// `Number.parseFloat(x) || fallback` — empty/invalid/zero input uses fallback.
    private static func parseOr(_ string: String, _ fallback: Double) -> Double {
        let value = Double(string.trimmingCharacters(in: .whitespaces))
        if let value, value != 0 { return value }
        return fallback
    }
}

// MARK: - View

struct EmployeeContractorCalculatorView: View {
    private enum BreakdownTab: String, CaseIterable, Identifiable {
        case employee, contractor
        var id: String { rawValue }
        var label: String {
            switch self {
            case .employee: return "Employee Breakdown"
            case .contractor: return "Contractor Details"
            }
        }
    }

    @State private var salary = ""
    @State private var contractorRate = ""
    @State private var hoursPerWeek = "40"
    @State private var weeksPerYear = "50"

    @State private var breakdownTab: BreakdownTab = .employee
    @State private var result: EmployeeContractorCalc.Result?

    var body: some View {
        CalculatorScaffold(
            icon: "person.2",
            title: "Employee vs Contractor Calculator",
            description: "Compare the true total cost of employees vs contractors using 2024 tax rates and benefit benchmarks",
            calculateTitle: "Compare Costs",
            onCalculate: calculate
        ) {
            CalcGrid {
                CalcField(label: "Employee Annual Salary ($)", placeholder: "60000", text: $salary)
                CalcField(label: "Contractor Hourly Rate ($)", placeholder: "40", text: $contractorRate)
                CalcField(label: "Hours per Week", placeholder: "40", text: $hoursPerWeek)
                CalcField(label: "Weeks per Year", placeholder: "50", text: $weeksPerYear)
            }
        } results: {
            resultView
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultView: some View {
        if let result {
            switch result {
            case .error(let message):
                CalcErrorText(text: message)
            case .comparison(let c):
                comparisonView(c)
            }
        }
    }

    @ViewBuilder
    private func comparisonView(_ c: EmployeeContractorCalc.Comparison) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Comparison")
                .font(Theme.sans(18, weight: .semibold))
                .foregroundStyle(Theme.foreground)

            CalcGrid {
                // Total Employee Cost — text-3xl text-red-600
                resultBlock(
                    caption: "Total Employee Cost",
                    value: dollar(c.employee.totalCost),
                    color: Theme.negative,
                    emphasized: true,
                    sub: "+\(CalcFormat.fixed(c.employee.burdenRate, 0))% burden above salary"
                )
                // Total Contractor Cost — text-3xl text-blue-600
                resultBlock(
                    caption: "Total Contractor Cost",
                    value: dollar(c.contractor.annualCost),
                    color: Theme.primary,
                    emphasized: true,
                    sub: "$\(CalcFormat.trimmed(c.contractor.hourlyRate))/hr × \(hoursPerWeek)h × \(weeksPerYear)wks"
                )
                // Savings — text-2xl, green when contractor saves else orange
                resultBlock(
                    caption: c.savings > 0 ? "Contractor Saves" : "Employee Saves",
                    value: dollar(abs(c.savings)) + " / yr",
                    color: c.savings > 0 ? Theme.positive : Theme.negative,
                    emphasized: false,
                    sub: "\(CalcFormat.fixed(abs(c.savingsPercentage), 1))% \(c.savings > 0 ? "cheaper" : "more expensive") vs employee"
                )
                // Equivalent Employee Hourly Rate — text-2xl, neutral
                resultBlock(
                    caption: "Equivalent Employee Hourly Rate",
                    value: "$\(CalcFormat.fixed(c.contractor.equivalentHourly, 2))/hr",
                    color: Theme.foreground,
                    emphasized: false,
                    sub: "Total employee cost ÷ total hours"
                )
            }

            Picker("", selection: $breakdownTab) {
                ForEach(BreakdownTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            switch breakdownTab {
            case .employee: employeeBreakdown(c)
            case .contractor: contractorDetails(c)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Result block (caption + bold value + muted subcaption)

    @ViewBuilder
    private func resultBlock(caption: String, value: String, color: Color, emphasized: Bool, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(Theme.sans(Theme.FontSize.sm))
                .foregroundStyle(Theme.mutedForeground)
            Text(value)
                .font(Theme.sans(emphasized ? 30 : 24, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(sub)
                .font(Theme.sans(Theme.FontSize.xs))
                .foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Employee breakdown tab

    @ViewBuilder
    private func employeeBreakdown(_ c: EmployeeContractorCalc.Comparison) -> some View {
        let e = c.employee
        VStack(alignment: .leading, spacing: 8) {
            row("Base Salary", dollar(e.salary), bold: true)

            sectionLabel("Benefits:")
            row("Health / Dental / Vision", dollar(e.healthDentalVision), indented: true)
            row("401(k) Match (3%)", dollar(e.retirement401k), indented: true)
            row("PTO Value (15 days)", dollar(e.ptoValue), indented: true)
            row("Life / Disability / Other", dollar(e.otherBenefits), indented: true)
            dividerRow()
            row("Total Benefits", dollar(e.totalBenefits))

            sectionLabel("Employer Taxes (2024):")
            row("Social Security (6.2%, up to $168,600)", dollar(e.employerSS), indented: true)
            row("Medicare (1.45%)", dollar(e.employerMedicare), indented: true)
            row("FUTA (net 0.6% on first $7k)", dollar(e.futaNet), indented: true)
            row("SUTA (est. 2% on first $7k)", dollar(e.suta), indented: true)
            row("Workers Comp (est. 2%)", dollar(e.workersComp), indented: true)
            dividerRow()
            row("Total Employer Cost", dollar(e.totalCost), bold: true, large: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    // MARK: Contractor details tab

    @ViewBuilder
    private func contractorDetails(_ c: EmployeeContractorCalc.Comparison) -> some View {
        // Match the web's `Number(hoursPerWeek) * Number(weeksPerYear)` on the
        // raw inputs, not the fallback-adjusted hours/weeks used for cost math.
        let annualHours = hoursPerWeek.calcValue * weeksPerYear.calcValue
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                row("Hourly Rate", "$\(CalcFormat.trimmed(c.contractor.hourlyRate))/hr")
                row("Annual Hours (\(hoursPerWeek)h × \(weeksPerYear)wks)", "\(CalcFormat.int(annualHours)) hrs")
                dividerRow()
                row("Annual Contractor Cost", dollar(c.contractor.annualCost), bold: true)
                Text("No payroll taxes, benefits, or workers comp required. Contractor is responsible for their own SE tax, insurance, and retirement.")
                    .font(Theme.sans(Theme.FontSize.xs))
                    .foregroundStyle(Theme.mutedForeground)
                    .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.muted.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))

            // Recommendation callout
            VStack(alignment: .leading, spacing: 4) {
                Text("Recommendation")
                    .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                Text(recommendationText(c))
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundStyle(Theme.mutedForeground)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((c.recommendation == "contractor" ? Theme.positive : Theme.primary).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
    }

    private func recommendationText(_ c: EmployeeContractorCalc.Comparison) -> String {
        if c.recommendation == "contractor" {
            return "Hiring a contractor saves \(dollar(c.savings)) per year (\(CalcFormat.fixed(c.savingsPercentage, 1))%). Best for short-term, specialized, or variable-hour work."
        } else {
            return "An employee is \(dollar(abs(c.savings))) cheaper per year at this rate. Better for long-term, high-commitment roles with training investment."
        }
    }

    // MARK: Breakdown row helpers

    @ViewBuilder
    private func row(_ label: String, _ value: String, indented: Bool = false, bold: Bool = false, large: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 8)
            Text(value)
        }
        .font(Theme.sans(large ? Theme.FontSize.base : Theme.FontSize.sm,
                      weight: bold ? .semibold : .regular))
        .foregroundStyle(Theme.foreground)
        .padding(.leading, indented ? 16 : 0)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
            .foregroundStyle(Theme.mutedForeground)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func dividerRow() -> some View {
        Divider().overlay(Theme.border)
    }

    // MARK: Formatting

    /// Web `dollar(n)` — `$${Math.round(n).toLocaleString()}`.
    private func dollar(_ n: Double) -> String {
        "$" + CalcFormat.int(n.rounded())
    }

    private func calculate() {
        result = EmployeeContractorCalc.compare(
            salary: salary,
            contractorRate: contractorRate,
            hoursPerWeek: hoursPerWeek,
            weeksPerYear: weeksPerYear
        )
    }
}

// MARK: - Formatting helper

private extension CalcFormat {
    /// Mirrors how JS prints `${result.contractor.hourlyRate}` — the raw number
    /// with no grouping and no forced decimals.
    static func trimmed(_ value: Double) -> String {
        raw(value)
    }
}

#Preview {
    NavigationStack { EmployeeContractorCalculatorView() }
}
