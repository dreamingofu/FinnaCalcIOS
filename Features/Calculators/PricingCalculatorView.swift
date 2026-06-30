//
//  PricingCalculatorView.swift
//  FinnaCalcIOS
//
//  Faithful port of `../FinnaCalc/app/pricing-calculator/page.tsx` — two modes
//  (Service Pricing, Product Pricing) with industry benchmarks, competitive
//  analysis, and scenario/strategy planning. Follows the LoanCalculatorView
//  exemplar and the shared CalcSupport toolkit.
//

import SwiftUI
import Foundation

// MARK: - Pure logic (ported 1:1)

enum PricingCalc {

    // Industry benchmarks (value, label, hourlyRange, profitMargin).
    struct Industry {
        let value: String
        let label: String
        let hourlyLow: Double
        let hourlyHigh: Double
        let profitMargin: Double
    }

    static let industries: [Industry] = [
        Industry(value: "consulting",  label: "Consulting",                          hourlyLow: 75,  hourlyHigh: 200, profitMargin: 25),
        Industry(value: "design",      label: "Design & Creative",                   hourlyLow: 50,  hourlyHigh: 150, profitMargin: 30),
        Industry(value: "development", label: "Software Development",                 hourlyLow: 60,  hourlyHigh: 180, profitMargin: 35),
        Industry(value: "marketing",   label: "Marketing & Advertising",             hourlyLow: 40,  hourlyHigh: 120, profitMargin: 28),
        Industry(value: "legal",       label: "Legal Services",                      hourlyLow: 150, hourlyHigh: 500, profitMargin: 40),
        Industry(value: "accounting",  label: "Accounting & Finance",                hourlyLow: 50,  hourlyHigh: 150, profitMargin: 30),
        Industry(value: "coaching",    label: "Coaching & Training",                 hourlyLow: 75,  hourlyHigh: 300, profitMargin: 45),
        Industry(value: "healthcare",  label: "Healthcare & Wellness",               hourlyLow: 80,  hourlyHigh: 250, profitMargin: 20),
        Industry(value: "trades",      label: "Trades (Plumbing, Electrical, etc.)", hourlyLow: 45,  hourlyHigh: 120, profitMargin: 25),
        Industry(value: "realestate",  label: "Real Estate",                         hourlyLow: 50,  hourlyHigh: 150, profitMargin: 30),
        Industry(value: "education",   label: "Education & Tutoring",                hourlyLow: 30,  hourlyHigh: 100, profitMargin: 20),
        Industry(value: "freelance",   label: "General Freelance",                   hourlyLow: 25,  hourlyHigh: 100, profitMargin: 20),
        Industry(value: "other",       label: "Other",                               hourlyLow: 20,  hourlyHigh: 80,  profitMargin: 15),
    ]

    static func industry(for value: String) -> Industry? {
        industries.first { $0.value == value }
    }

    struct Scenario: Identifiable {
        let id = UUID()
        let name: String
        let rate: Double
        let description: String
        let annualRevenue: Double
        let netIncome: Double
    }

    struct Strategy: Identifiable {
        let id = UUID()
        let name: String
        let price: Double
        let description: String
        let profit: Double
        let margin: Double
    }

    struct ServiceResult {
        let annualRevenue: Double
        let netIncome: Double
        let requiredHourlyRate: Double
        let breakEvenRate: Double
        let currentRate: Double
        let industry: Industry?
        let isCompetitive: Bool?
        let scenarios: [Scenario]
    }

    struct ProductResult {
        let sellingPrice: Double
        let profit: Double
        let markupPercentage: Double
        let marginPercentage: Double
        let competitiveAdvantage: Double
        let strategies: [Strategy]
    }

    enum Result {
        case error(String)
        case service(ServiceResult)
        case product(ProductResult)
    }

    static func calculateServicePricing(
        hourlyRate: String, hoursPerWeek: String, weeksPerYear: String,
        expenses: String, profitMargin: String, desiredSalary: String,
        taxRate: String, industryType: String
    ) -> Result {
        // `Number.parseFloat(x) || 0`, with the web's per-field fallbacks.
        let rate = Double(hourlyRate) ?? 0
        let hours = Double(hoursPerWeek) ?? 0
        let weeks = Double(weeksPerYear) ?? 50
        let annualExpenses = Double(expenses) ?? 0
        let salary = Double(desiredSalary) ?? 0
        let tax = Double(taxRate) ?? 25

        let totalBillableHours = hours * weeks
        let annualRevenue = rate * totalBillableHours
        let grossProfit = annualRevenue - annualExpenses
        let netIncome = grossProfit * (1 - tax / 100)

        let requiredGrossIncome = salary / (1 - tax / 100)
        let requiredRevenue = requiredGrossIncome + annualExpenses
        let requiredHourlyRate = totalBillableHours > 0 ? requiredRevenue / totalBillableHours : 0

        let breakEvenRate = totalBillableHours > 0 ? annualExpenses / totalBillableHours : 0

        let industryData = industryType.isEmpty ? nil : industry(for: industryType)
        let isCompetitive: Bool? = industryData.map { rate >= $0.hourlyLow && rate <= $0.hourlyHigh }

        let scenarioSpecs: [(String, Double, String)] = [
            ("Conservative", rate * 0.8, "20% below current rate"),
            ("Current", rate, "Your current rate"),
            ("Optimistic", rate * 1.2, "20% above current rate"),
            ("Premium", rate * 1.5, "50% premium pricing"),
        ]
        let scenarios = scenarioSpecs.map { spec -> Scenario in
            let annual = spec.1 * totalBillableHours
            return Scenario(
                name: spec.0,
                rate: spec.1,
                description: spec.2,
                annualRevenue: annual,
                netIncome: (annual - annualExpenses) * (1 - tax / 100)
            )
        }

        return .service(ServiceResult(
            annualRevenue: annualRevenue,
            netIncome: netIncome,
            requiredHourlyRate: requiredHourlyRate,
            breakEvenRate: breakEvenRate,
            currentRate: rate,
            industry: industryData,
            isCompetitive: isCompetitive,
            scenarios: scenarios
        ))
    }

    static func calculateProductPricing(
        productCost: String, productMargin: String, competitorPrice: String,
        volumeDiscount: String, shippingCost: String
    ) -> Result {
        let cost = Double(productCost) ?? 0
        let margin = Double(productMargin) ?? 50
        let competitor = Double(competitorPrice) ?? 0
        // discount/shipping parsed for parity; the web result only surfaces the
        // figures below, so they are not rendered as result rows.
        _ = Double(volumeDiscount) ?? 0
        _ = Double(shippingCost) ?? 0

        if margin >= 100 {
            return .error("Profit margin must be less than 100%")
        }
        if cost < 0 {
            return .error("Product cost cannot be negative.")
        }

        let sellingPrice = cost > 0 ? cost / (1 - margin / 100) : 0
        let profit = sellingPrice - cost
        let markupPercentage = cost > 0 ? (profit / cost) * 100 : 0

        let competitiveAdvantage = competitor > 0 ? ((competitor - sellingPrice) / competitor) * 100 : 0

        let strategySpecs: [(String, Double, String)] = [
            ("Cost-Plus", sellingPrice, "Standard markup pricing"),
            ("Competitive", competitor * 0.95, "5% below competitor"),
            ("Premium", sellingPrice * 1.3, "30% premium positioning"),
            ("Penetration", sellingPrice * 0.8, "20% below standard for market entry"),
        ]
        let strategies = strategySpecs
            .filter { $0.1 > 0 }
            .map { spec -> Strategy in
                Strategy(
                    name: spec.0,
                    price: spec.1,
                    description: spec.2,
                    profit: spec.1 - cost,
                    margin: spec.1 > 0 ? ((spec.1 - cost) / spec.1) * 100 : 0
                )
            }

        return .product(ProductResult(
            sellingPrice: sellingPrice,
            profit: profit,
            markupPercentage: markupPercentage,
            marginPercentage: margin,
            competitiveAdvantage: competitiveAdvantage,
            strategies: strategies
        ))
    }

    /// Mirrors JS `String(number)` — drops a trailing `.0` for whole numbers
    /// (used for the raw margin echo, web `{result.marginPercentage}%`).
    static func plainNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(value)
    }
}

// MARK: - View

struct PricingCalculatorView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case service, product
        var id: String { rawValue }
        var tab: String {
            switch self {
            case .service: return "Service Pricing"
            case .product: return "Product Pricing"
            }
        }
        var calculateTitle: String {
            switch self {
            case .service: return "Calculate Advanced Service Pricing"
            case .product: return "Calculate Advanced Product Pricing"
            }
        }
    }

    @State private var mode: Mode = .service

    // Service Pricing
    @State private var industryType = ""
    @State private var hourlyRate = ""
    @State private var hoursPerWeek = ""
    @State private var weeksPerYear = "50"
    @State private var expenses = ""
    @State private var desiredSalary = ""
    @State private var taxRate = "25"
    @State private var profitMargin = "20"

    // Product Pricing
    @State private var productCost = ""
    @State private var productMargin = "50"
    @State private var competitorPrice = ""
    @State private var shippingCost = ""
    @State private var volumeDiscount = ""

    @State private var result: PricingCalc.Result?

    var body: some View {
        CalculatorScaffold(
            icon: "dollarsign.circle",
            title: "Advanced Pricing Calculator",
            description: "Strategic pricing with competitive analysis and industry benchmarks",
            calculateTitle: mode.calculateTitle,
            onCalculate: calculate
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.tab).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _ in result = nil }

                switch mode {
                case .service: serviceInputs
                case .product: productInputs
                }
            }
        } results: {
            resultView
        }
    }

    // MARK: Inputs

    private var serviceInputs: some View {
        CalcGrid {
            CalcPicker(label: "Industry Type", selection: $industryType, options:
                [("", "Select your industry")] +
                PricingCalc.industries.map { ($0.value, $0.label) }
            )
            CalcField(label: "Current Hourly Rate ($)", placeholder: "75", text: $hourlyRate)
            CalcField(label: "Billable Hours per Week", placeholder: "30", text: $hoursPerWeek)
            CalcField(label: "Working Weeks per Year", placeholder: "50", text: $weeksPerYear)
            CalcField(label: "Annual Business Expenses ($)", placeholder: "25000", text: $expenses)
            CalcField(label: "Desired Annual Salary ($)", placeholder: "80000", text: $desiredSalary)
            CalcField(label: "Tax Rate (%)", placeholder: "25", text: $taxRate)
            CalcField(label: "Target Profit Margin (%)", placeholder: "20", text: $profitMargin)
        }
    }

    private var productInputs: some View {
        CalcGrid {
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Product Cost ($)", placeholder: "25", text: $productCost)
                helperText("Total cost to make/acquire")
            }
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Desired Profit Margin (%)", placeholder: "50", text: $productMargin)
                helperText("Percentage of selling price")
            }
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Competitor Price ($)", placeholder: "60", text: $competitorPrice)
                helperText("For competitive analysis")
            }
            CalcField(label: "Shipping Cost ($)", placeholder: "5", text: $shippingCost)
            VStack(alignment: .leading, spacing: 6) {
                CalcField(label: "Volume Discount (%)", placeholder: "10", text: $volumeDiscount)
                helperText("For bulk orders")
            }
        }
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.xs))
            .foregroundStyle(Theme.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Results

    @ViewBuilder
    private var resultView: some View {
        if let result {
            switch result {
            case .error(let message):
                CalcErrorText(text: message)
            case .service(let r):
                serviceResults(r)
            case .product(let r):
                productResults(r)
            }
        }
    }

    @ViewBuilder
    private func serviceResults(_ r: PricingCalc.ServiceResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CalcResultsSection {
                CalcResult(label: "Current Annual Revenue", value: CalcFormat.currency(r.annualRevenue), color: Theme.positive, emphasized: true)
                CalcResult(label: "Net Income (After Tax)", value: CalcFormat.currency(r.netIncome), color: r.netIncome >= 0 ? Theme.primary : Theme.negative)
                CalcResult(label: "Required Hourly Rate", value: "$" + CalcFormat.fixed(r.requiredHourlyRate, 2))
                CalcResult(label: "Break-Even Rate", value: "$" + CalcFormat.fixed(r.breakEvenRate, 2))
            }

            if let industry = r.industry {
                infoCard {
                    Text("Industry Benchmark Analysis")
                        .font(.system(size: Theme.FontSize.base, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                    HStack {
                        Text("Industry Range: $\(PricingCalc.plainNumber(industry.hourlyLow)) - $\(PricingCalc.plainNumber(industry.hourlyHigh))")
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundStyle(Theme.foreground)
                        Spacer()
                        FCBadge(variant: (r.isCompetitive ?? false) ? .default : .secondary) {
                            Text((r.isCompetitive ?? false) ? "Competitive" : "Outside Range")
                        }
                    }
                    progressBar(value: min((r.currentRate / industry.hourlyHigh) * 100, 100))
                }
            }

            mutedCard {
                Text("Pricing Scenarios:")
                    .font(.system(size: Theme.FontSize.base, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                ForEach(r.scenarios) { scenario in
                    listRow(
                        name: scenario.name,
                        sub: "$\(CalcFormat.fixed(scenario.rate, 2))/hr",
                        primary: CalcFormat.currency(scenario.annualRevenue),
                        secondary: "Net: \(CalcFormat.currency(scenario.netIncome))",
                        secondaryColor: scenario.netIncome >= 0 ? Theme.positive : Theme.negative
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func productResults(_ r: PricingCalc.ProductResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CalcResultsSection {
                CalcResult(label: "Recommended Selling Price", value: "$" + CalcFormat.fixed(r.sellingPrice, 2), color: Theme.positive, emphasized: true)
                CalcResult(label: "Profit per Unit", value: "$" + CalcFormat.fixed(r.profit, 2), color: Theme.primary)
                CalcResult(label: "Markup Percentage", value: CalcFormat.fixed(r.markupPercentage, 1) + "%")
                CalcResult(label: "Profit Margin", value: PricingCalc.plainNumber(r.marginPercentage) + "%")
            }

            if r.competitiveAdvantage != 0 {
                infoCard {
                    Text("Competitive Analysis")
                        .font(.system(size: Theme.FontSize.base, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                    Text("Your price is \(CalcFormat.fixed(abs(r.competitiveAdvantage), 1))%\(r.competitiveAdvantage > 0 ? " below" : " above") competitor pricing")
                        .font(.system(size: Theme.FontSize.sm))
                        .foregroundColor(r.competitiveAdvantage > 0 ? Theme.positive : Theme.negative)
                }
            }

            mutedCard {
                Text("Pricing Strategies:")
                    .font(.system(size: Theme.FontSize.base, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                ForEach(r.strategies) { strategy in
                    listRow(
                        name: strategy.name,
                        sub: strategy.description,
                        primary: "$" + CalcFormat.fixed(strategy.price, 2),
                        secondary: "Profit: $\(CalcFormat.fixed(strategy.profit, 2)) (\(CalcFormat.fixed(strategy.margin, 1))%)",
                        secondaryColor: Theme.positive
                    )
                }
            }
        }
    }

    // MARK: Result building blocks

    @ViewBuilder
    private func infoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    @ViewBuilder
    private func mutedCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func progressBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.secondary)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.primary)
                    .frame(width: geo.size.width * CGFloat(max(0, min(value, 100)) / 100))
            }
        }
        .frame(height: 8)
    }

    private func listRow(name: String, sub: String, primary: String, secondary: String, secondaryColor: Color) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: Theme.FontSize.sm, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                Text(sub)
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundStyle(Theme.mutedForeground)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(primary)
                    .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                Text(secondary)
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(secondaryColor)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    // MARK: Calculate

    private func calculate() {
        switch mode {
        case .service:
            result = PricingCalc.calculateServicePricing(
                hourlyRate: hourlyRate, hoursPerWeek: hoursPerWeek, weeksPerYear: weeksPerYear,
                expenses: expenses, profitMargin: profitMargin, desiredSalary: desiredSalary,
                taxRate: taxRate, industryType: industryType
            )
        case .product:
            result = PricingCalc.calculateProductPricing(
                productCost: productCost, productMargin: productMargin, competitorPrice: competitorPrice,
                volumeDiscount: volumeDiscount, shippingCost: shippingCost
            )
        }
    }
}

#Preview {
    NavigationStack { PricingCalculatorView() }
}
