//
//  CalculatorCatalog.swift
//  FinnaCalcIOS
//
//  The calculator catalog shown on the Home hub — ported from the `calculators`
//  array in `../FinnaCalc/app/page.tsx` (same titles, descriptions, order, and
//  categories). Tax Calculator is intentionally omitted here; it ships with the
//  tax engine in Phase 6.
//

import SwiftUI

enum CalculatorKind: String, CaseIterable, Identifiable {
    case emergencyFund
    case breakEven
    case startupCost
    case cashFlow
    case loan
    case pricing
    case roi
    case employeeContractor
    case profitMargin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emergencyFund:      return "Emergency Fund Calculator"
        case .breakEven:          return "Break-Even Point Calculator"
        case .startupCost:        return "Startup Cost Estimator"
        case .cashFlow:           return "Cash Flow Projector"
        case .loan:               return "Loan Calculator"
        case .pricing:            return "Pricing Calculator"
        case .roi:                return "ROI Calculator"
        case .employeeContractor: return "Employee vs Contractor Calculator"
        case .profitMargin:       return "Profit Margin Calculator"
        }
    }

    var summary: String {
        switch self {
        case .emergencyFund:      return "Calculate how much you need in your emergency fund and track progress toward your goal"
        case .breakEven:          return "Find out exactly how many units you need to sell to cover all costs and reach profitability"
        case .startupCost:        return "Estimate total startup costs with industry templates and funding gap analysis"
        case .cashFlow:           return "Project your business cash flow over time with growth rate modeling"
        case .loan:               return "Calculate payments, true APR, loan amounts, and remaining balances for any loan type"
        case .pricing:            return "Set the right price for your products and services with competitive analysis"
        case .roi:                return "Calculate annualized return on investment with inflation and tax adjustments"
        case .employeeContractor: return "Compare the true total cost of hiring employees versus independent contractors"
        case .profitMargin:       return "Calculate gross, operating, and net profit margins with industry benchmarks"
        }
    }

    var category: String {
        switch self {
        case .emergencyFund:      return "Personal Finance"
        case .breakEven, .startupCost, .cashFlow, .pricing, .employeeContractor, .profitMargin: return "Business"
        case .loan:               return "Loans"
        case .roi:                return "Investment"
        }
    }

    /// SF Symbol mapped from the lucide icon used on the web card.
    var icon: String {
        switch self {
        case .emergencyFund:      return "dollarsign.circle"          // DollarSign
        case .breakEven:          return "chart.line.uptrend.xyaxis"  // TrendingUp
        case .startupCost:        return "building.2"                 // Building2
        case .cashFlow:           return "chart.line.uptrend.xyaxis"  // TrendingUp
        case .loan:               return "banknote"                   // Calculator
        case .pricing:            return "dollarsign.circle"          // DollarSign
        case .roi:                return "chart.pie"                  // PieChart
        case .employeeContractor: return "person.2"                   // Users
        case .profitMargin:       return "chart.line.uptrend.xyaxis"  // TrendingUp
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .emergencyFund:      EmergencyFundCalculatorView()
        case .breakEven:          BreakEvenCalculatorView()
        case .startupCost:        StartupCostCalculatorView()
        case .cashFlow:           CashFlowCalculatorView()
        case .loan:               LoanCalculatorView()
        case .pricing:            PricingCalculatorView()
        case .roi:                ROICalculatorView()
        case .employeeContractor: EmployeeContractorCalculatorView()
        case .profitMargin:       ProfitMarginCalculatorView()
        }
    }
}
