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
                        .font(Theme.sans(Theme.FontSize.base))
                        .foregroundStyle(Theme.mutedForeground)
                }

                Text("Choose your calculator")
                    .font(Theme.sans(18, weight: .semibold))
                    .foregroundStyle(Theme.foreground)

                ForEach(CalculatorKind.allCases) { calc in
                    NavigationLink {
                        calc.destination
                    } label: {
                        CalculatorCard(calc: calc)
                    }
                    .buttonStyle(.plain)
                }

                footer
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // Footer links (the web footer): accessible to everyone, signed in or not.
    private var footer: some View {
        VStack(spacing: 10) {
            Divider().background(Theme.border)
            HStack(spacing: 0) {
                footerLink("About") { AboutView() }
                footerDot
                footerLink("Premium") { PremiumView() }
                footerDot
                footerLink("Advising") { AdvisingView() }
            }
            HStack(spacing: 0) {
                footerLink("Privacy") { PrivacyView() }
                footerDot
                footerLink("Terms") { TermsView() }
            }
            Text("Educational only — not licensed financial or tax advice.")
                .font(Theme.sans(Theme.FontSize.xs))
                .foregroundStyle(Theme.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var footerDot: some View {
        Text("·").font(Theme.sans(Theme.FontSize.sm)).foregroundStyle(Theme.mutedForeground).padding(.horizontal, 8)
    }

    @ViewBuilder
    private func footerLink<Destination: View>(_ title: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            Text(title).font(Theme.sans(Theme.FontSize.sm)).foregroundStyle(Theme.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct CalculatorCard: View {
    let calc: CalculatorKind

    var body: some View {
        FCCard(interactive: true) {
            FCListRow(icon: calc.icon, title: calc.title, subtitle: calc.summary)
        }
    }
}

#Preview {
    NavigationStack { HomeView().environmentObject(AuthManager()) }
}
