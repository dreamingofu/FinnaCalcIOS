//
//  InvestingView.swift
//  FinnaCalcIOS
//

import SwiftUI

struct InvestingView: View {
    var body: some View {
        ComingSoonView(
            icon: "chart.line.uptrend.xyaxis",
            title: "Investing",
            message: "Markets, stock research, SnapTrade brokerage connections, and your portfolio.",
            phase: "Coming in Phase 5"
        )
    }
}

#Preview { InvestingView() }
