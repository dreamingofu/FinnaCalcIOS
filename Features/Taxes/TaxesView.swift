//
//  TaxesView.swift
//  FinnaCalcIOS
//
//  Taxes tab, ported from app/taxes/page.tsx: two tabs — the adaptive Tax
//  Estimator (the IRS-accurate engine interview) and Calculators & Tools.
//

import SwiftUI

struct TaxesView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case estimator = "Tax Estimator"
        case calculators = "Calculators & Tools"
        var id: String { rawValue }
    }
    @State private var tab: Tab = .estimator

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Estimate your federal taxes and explore tools to optimize your strategy.")
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundStyle(Theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            switch tab {
            case .estimator: TaxInterview()
            case .calculators: TaxCalculatorsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    NavigationStack { TaxesView() }
}
