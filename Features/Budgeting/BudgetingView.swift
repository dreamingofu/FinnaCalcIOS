//
//  BudgetingView.swift
//  FinnaCalcIOS
//

import SwiftUI

struct BudgetingView: View {
    var body: some View {
        ComingSoonView(
            icon: "wallet.bifold",
            title: "Budgeting",
            message: "Connect your bank with Plaid, track spending, and get AI budget recommendations.",
            phase: "Coming in Phase 4"
        )
    }
}

#Preview { BudgetingView() }
