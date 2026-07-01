//
//  StartupCostCalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/startup-cost-calculator/page.tsx` —
//  "Enhanced Startup Cost Calculator" with two input tabs (Startup Costs /
//  Funding Sources), industry templates, a 20% buffer, funding-gap analysis,
//  and a detailed cost-category breakdown. Calculation logic ported 1:1.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum StartupCostCalc {

    /// One row of the detailed cost breakdown (the web `costCategories`).
    struct CostCategory: Identifiable {
        let id = UUID()
        let name: String
        let value: Double
        let color: Color
    }

    struct Result {
        let totalCosts: Double
        let recommendedBuffer: Double
        let totalWithBuffer: Double
        let totalFunding: Double
        let fundingGap: Double
        let fundingProgress: Double   // min(totalFunding/totalWithBuffer*100, 100)
        let costCategories: [CostCategory]
    }

    /// Industry presets (web `businessTemplates`). Each maps a business type to
    /// default dollar values for the cost fields it populates.
    struct Template {
        let equipment, inventory, marketing, legal, rent: Double
        let utilities, insurance, permits, website, workingCapital: Double
    }

    static let templates: [String: Template] = [
        "retail": Template(equipment: 25000, inventory: 15000, marketing: 8000, legal: 3500, rent: 12000,
                           utilities: 2000, insurance: 3000, permits: 1500, website: 3000, workingCapital: 10000),
        "restaurant": Template(equipment: 50000, inventory: 8000, marketing: 10000, legal: 5000, rent: 18000,
                               utilities: 3000, insurance: 4000, permits: 3000, website: 2000, workingCapital: 15000),
        "service": Template(equipment: 8000, inventory: 2000, marketing: 5000, legal: 2500, rent: 6000,
                            utilities: 1000, insurance: 2000, permits: 500, website: 4000, workingCapital: 8000),
        "online": Template(equipment: 5000, inventory: 10000, marketing: 12000, legal: 2000, rent: 0,
                           utilities: 500, insurance: 1500, permits: 200, website: 8000, workingCapital: 12000),
        "manufacturing": Template(equipment: 75000, inventory: 25000, marketing: 8000, legal: 5000, rent: 15000,
                                  utilities: 4000, insurance: 6000, permits: 5000, website: 3000, workingCapital: 25000),
        "consulting": Template(equipment: 3000, inventory: 0, marketing: 6000, legal: 2000, rent: 3000,
                               utilities: 800, insurance: 1500, permits: 300, website: 5000, workingCapital: 5000),
    ]

    static func calculate(
        equipment: Double, inventory: Double, marketing: Double, legal: Double,
        rent: Double, utilities: Double, insurance: Double, other: Double,
        employees: Double, salaries: Double, permits: Double, website: Double,
        workingCapital: Double,
        personalSavings: Double, loanAmount: Double, investorFunding: Double
    ) -> Result {
        let costsTotal = equipment + inventory + marketing + legal + rent + utilities
            + insurance + other + employees + salaries + permits + website + workingCapital

        let recommendedBuffer = costsTotal * 0.2   // 20% buffer
        let totalWithBuffer = costsTotal + recommendedBuffer

        let totalFunding = personalSavings + loanAmount + investorFunding
        let fundingGap = totalWithBuffer - totalFunding

        let categories: [CostCategory] = [
            CostCategory(name: "Equipment & Technology", value: equipment, color: Color(hex: 0x3B82F6)),
            CostCategory(name: "Inventory", value: inventory, color: Color(hex: 0x10B981)),
            CostCategory(name: "Marketing", value: marketing, color: Color(hex: 0xF59E0B)),
            CostCategory(name: "Legal & Professional", value: legal, color: Color(hex: 0xEF4444)),
            CostCategory(name: "Rent & Utilities", value: rent + utilities, color: Color(hex: 0x8B5CF6)),
            CostCategory(name: "Insurance & Permits", value: insurance + permits, color: Color(hex: 0x06B6D4)),
            CostCategory(name: "Website & Digital", value: website, color: Color(hex: 0x84CC16)),
            CostCategory(name: "Working Capital", value: workingCapital, color: Color(hex: 0xF97316)),
            CostCategory(name: "Salaries & Staff", value: salaries + employees, color: Color(hex: 0xEC4899)),
            CostCategory(name: "Other", value: other, color: Color(hex: 0x6B7280)),
        ].filter { $0.value > 0 }

        let progress = totalWithBuffer > 0
            ? min(totalFunding / totalWithBuffer * 100, 100)
            : 0

        return Result(
            totalCosts: costsTotal,
            recommendedBuffer: recommendedBuffer,
            totalWithBuffer: totalWithBuffer,
            totalFunding: totalFunding,
            fundingGap: fundingGap,
            fundingProgress: progress,
            costCategories: categories
        )
    }
}

private extension Color {
    /// 0xRRGGBB hex initializer for the breakdown swatches.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - View

struct StartupCostCalculatorView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case costs, funding
        var id: String { rawValue }
        var title: String {
            switch self {
            case .costs: return "Startup Costs"
            case .funding: return "Funding Sources"
            }
        }
    }

    @State private var activeTab: Tab = .costs

    // Cost inputs
    @State private var businessType = ""
    @State private var equipment = ""
    @State private var inventory = ""
    @State private var marketing = ""
    @State private var legal = ""
    @State private var rent = ""
    @State private var utilities = ""
    @State private var insurance = ""
    @State private var other = ""
    @State private var employees = ""
    @State private var salaries = ""
    @State private var permits = ""
    @State private var website = ""
    @State private var workingCapital = ""

    // Funding inputs
    @State private var personalSavings = ""
    @State private var loanAmount = ""
    @State private var investorFunding = ""

    @State private var result: StartupCostCalc.Result?

    var body: some View {
        CalculatorScaffold(
            icon: "building.2",
            title: "Enhanced Startup Cost Calculator",
            description: "Comprehensive startup cost estimation with funding analysis",
            calculateTitle: "Calculate Comprehensive Startup Costs",
            onCalculate: calculate
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $activeTab) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: activeTab) { _ in result = nil }

                switch activeTab {
                case .costs: costInputs
                case .funding: fundingInputs
                }
            }
        } results: {
            resultView
        }
    }

    // MARK: Inputs

    private var costInputs: some View {
        VStack(alignment: .leading, spacing: 16) {
            CalcPicker(label: "Business Type", selection: $businessType, options: [
                ("", "Select business type"),
                ("retail", "Retail Store"),
                ("restaurant", "Restaurant"),
                ("service", "Service Business"),
                ("online", "Online Business"),
                ("manufacturing", "Manufacturing"),
                ("consulting", "Consulting"),
            ])

            if !businessType.isEmpty {
                FCButton("Load Template", variant: .outline, action: loadTemplate)
            }

            CalcGrid {
                CalcField(label: "Equipment & Technology ($)", placeholder: "15000", text: $equipment)
                CalcField(label: "Initial Inventory ($)", placeholder: "10000", text: $inventory)
                CalcField(label: "Marketing & Advertising ($)", placeholder: "5000", text: $marketing)
                CalcField(label: "Legal & Professional Fees ($)", placeholder: "3000", text: $legal)
                CalcField(label: "First 3 Months Rent ($)", placeholder: "9000", text: $rent)
                CalcField(label: "Utilities Setup ($)", placeholder: "1500", text: $utilities)
                CalcField(label: "Insurance (Annual) ($)", placeholder: "2400", text: $insurance)
                CalcField(label: "Permits & Licenses ($)", placeholder: "1500", text: $permits)
                CalcField(label: "Website & Digital Setup ($)", placeholder: "3000", text: $website)
                CalcField(label: "Employee Setup Costs ($)", placeholder: "2000", text: $employees)
                CalcField(label: "First 3 Months Salaries ($)", placeholder: "15000", text: $salaries)
                CalcField(label: "Working Capital ($)", placeholder: "10000", text: $workingCapital)
                CalcField(label: "Other Expenses ($)", placeholder: "2000", text: $other)
            }
        }
    }

    private var fundingInputs: some View {
        CalcGrid {
            CalcField(label: "Personal Savings ($)", placeholder: "25000", text: $personalSavings)
            CalcField(label: "Business Loan ($)", placeholder: "50000", text: $loanAmount)
            CalcField(label: "Investor Funding ($)", placeholder: "100000", text: $investorFunding)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultView: some View {
        if let result {
            VStack(alignment: .leading, spacing: 16) {
                CalcResultsSection {
                    CalcResult(label: "Total Startup Costs",
                               value: "$" + CalcFormat.locale(result.totalCosts),
                               color: Theme.positive, emphasized: true)
                    CalcResult(label: "Recommended Total (with 20% buffer)",
                               value: "$" + CalcFormat.locale(result.totalWithBuffer),
                               color: Theme.primary)
                    CalcResult(label: "Total Funding Available",
                               value: "$" + CalcFormat.locale(result.totalFunding),
                               color: Theme.primary)
                }

                // Funding Analysis
                VStack(alignment: .leading, spacing: 8) {
                    Text("Funding Analysis:")
                        .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                        .foregroundColor(Theme.foreground)

                    analysisRow("Required Capital:", "$" + CalcFormat.locale(result.totalWithBuffer))
                    analysisRow("Available Funding:", "$" + CalcFormat.locale(result.totalFunding))

                    Divider()

                    HStack {
                        Text("Funding Gap:")
                            .font(Theme.sans(Theme.FontSize.sm))
                            .foregroundColor(Theme.foreground)
                        Spacer()
                        Text((result.fundingGap > 0 ? "-" : "+") + "$" + CalcFormat.locale(abs(result.fundingGap)))
                            .font(Theme.sans(Theme.FontSize.sm, weight: .bold))
                            .foregroundColor(result.fundingGap > 0 ? Theme.negative : Theme.positive)
                    }

                    ProgressView(value: result.fundingProgress, total: 100)
                        .padding(.top, 2)

                    Text(result.fundingGap > 0
                         ? "You need an additional $\(CalcFormat.locale(result.fundingGap)) in funding"
                         : "You have sufficient funding with $\(CalcFormat.locale(abs(result.fundingGap))) surplus")
                        .font(Theme.sans(Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.muted.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))

                // Detailed Cost Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.pie")
                            .font(Theme.sans(14))
                            .foregroundColor(Theme.foreground)
                        Text("Detailed Cost Breakdown:")
                            .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                            .foregroundColor(Theme.foreground)
                    }

                    ForEach(result.costCategories) { category in
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 12, height: 12)
                                Text("\(category.name):")
                                    .font(Theme.sans(Theme.FontSize.sm))
                                    .foregroundColor(Theme.foreground)
                            }
                            Spacer()
                            Text("$" + CalcFormat.locale(category.value))
                                .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                                .foregroundColor(Theme.foreground)
                            + Text("  (\(percent(category.value, of: result.totalCosts))%)")
                                .font(Theme.sans(Theme.FontSize.xs))
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.muted.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            }
        }
    }

    private func analysisRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.sans(Theme.FontSize.sm))
                .foregroundColor(Theme.foreground)
            Spacer()
            Text(value)
                .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                .foregroundColor(Theme.foreground)
        }
    }

    /// `((value / total) * 100).toFixed(1)`
    private func percent(_ value: Double, of total: Double) -> String {
        guard total > 0 else { return "0.0" }
        return CalcFormat.fixed(value / total * 100, 1)
    }

    // MARK: Actions

    private func loadTemplate() {
        guard let template = StartupCostCalc.templates[businessType] else { return }
        equipment = String(Int(template.equipment))
        inventory = String(Int(template.inventory))
        marketing = String(Int(template.marketing))
        legal = String(Int(template.legal))
        rent = String(Int(template.rent))
        utilities = String(Int(template.utilities))
        insurance = String(Int(template.insurance))
        permits = String(Int(template.permits))
        website = String(Int(template.website))
        workingCapital = String(Int(template.workingCapital))
        result = nil
    }

    private func calculate() {
        result = StartupCostCalc.calculate(
            equipment: equipment.calcValue, inventory: inventory.calcValue,
            marketing: marketing.calcValue, legal: legal.calcValue,
            rent: rent.calcValue, utilities: utilities.calcValue,
            insurance: insurance.calcValue, other: other.calcValue,
            employees: employees.calcValue, salaries: salaries.calcValue,
            permits: permits.calcValue, website: website.calcValue,
            workingCapital: workingCapital.calcValue,
            personalSavings: personalSavings.calcValue,
            loanAmount: loanAmount.calcValue,
            investorFunding: investorFunding.calcValue
        )
    }
}

#Preview {
    NavigationStack { StartupCostCalculatorView() }
}
