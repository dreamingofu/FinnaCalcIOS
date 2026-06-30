//
//  HomeView.swift
//  FinnaCalcIOS
//
//  The Home tab is the calculator hub — the iOS counterpart of the web home
//  page's "Choose Your Calculator" grid (app/page.tsx). Each card pushes the
//  corresponding calculator.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    FCWordmark(size: 34)
                    Text(auth.user.map { "Welcome back, \($0.displayName)." }
                         ?? "Free, accurate financial calculators.")
                        .font(.system(size: Theme.FontSize.base))
                        .foregroundStyle(Theme.mutedForeground)
                }

                Text("Choose your calculator")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.foreground)

                ForEach(CalculatorKind.allCases) { calc in
                    NavigationLink {
                        calc.destination
                    } label: {
                        CalculatorCard(calc: calc)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

private struct CalculatorCard: View {
    let calc: CalculatorKind

    var body: some View {
        FCCard {
            FCCardHeader {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: calc.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(calc.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.cardForeground)
                        FCCardDescription(calc.summary)
                        FCBadge(calc.category, variant: .secondary)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.mutedForeground)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { HomeView().environmentObject(AuthManager()) }
}
