//
//  BudgetingView.swift
//  FinnaCalcIOS
//
//  Budget Planner container, ported from app/budgeting/page.tsx: the KPI header,
//  the personal/business toggle, the five sub-tabs (Budget, Analysis, Goals,
//  Credit, History), Bank Actions (Plaid transaction import), and Clear Data.
//  Owns the BudgetStore and injects it into the sub-views.
//

import SwiftUI

struct BudgetingView: View {
    @StateObject private var store = BudgetStore()
    @StateObject private var plaid = PlaidLinkCoordinator()

    private enum SubTab: String, CaseIterable, Identifiable {
        case budget = "Budget", analysis = "Analysis", goals = "Goals", credit = "Credit", history = "History"
        var id: String { rawValue }
    }
    @State private var tab: SubTab = .budget

    @State private var importing = false
    @State private var importError: String?
    @State private var showClearConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                kpiGrid
                budgetTypeToggle

                Picker("", selection: $tab) {
                    ForEach(SubTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if let importError {
                    CalcErrorText(text: importError)
                }

                content
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .environmentObject(store)
        .confirmationDialog("Clear data", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear budget items", role: .destructive) { store.clearBudgetItems() }
            Button("Clear everything (items, goals, history)", role: .destructive) { store.clearAll() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(store.budgetType.title) Budget Planner")
                    .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                    .foregroundStyle(Theme.foreground)
                Text("Take control of your finances with our comprehensive budgeting tool")
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundStyle(Theme.mutedForeground)
            }
            HStack(spacing: 8) {
                FCButton("Bank Actions", variant: .outline, size: .sm) { connectBank() }
                    .disabled(importing)
                FCButton("Clear Data", variant: .destructive, size: .sm) { showClearConfirm = true }
                if importing {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            stat("Monthly Income", CalcFormat.currency(store.monthlyIncome), Theme.positive)
            stat("Monthly Expenses", CalcFormat.currency(store.monthlyExpenses), Theme.negative)
            stat("Net Income", CalcFormat.currency(store.monthlyNet), store.monthlyNet >= 0 ? Theme.positive : Theme.negative)
            stat("Savings Rate", store.savingsRate.map { CalcFormat.fixed($0, 1) + "%" } ?? "—", Theme.primary)
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: Theme.FontSize.xs)).foregroundStyle(Theme.mutedForeground)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    private var budgetTypeToggle: some View {
        Picker("Budget type", selection: $store.budgetType) {
            ForEach(BudgetType.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Sub-tab content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .budget: BudgetTabView()
        case .analysis: BudgetAdvisorView()
        case .goals: GoalsTabView()
        case .credit: DebtCardView()
        case .history: HistoryTabView()
        }
    }

    // MARK: Bank import (Plaid transactions)

    private func connectBank() {
        importing = true
        importError = nil
        Task { @MainActor in
            do {
                let token = try await PlaidService.createLinkToken(product: .transactions)
                plaid.open(linkToken: token, onSuccess: { publicToken in
                    Task { @MainActor in
                        do {
                            let transactions = try await PlaidService.importTransactions(publicToken: publicToken)
                            guard !transactions.isEmpty else {
                                importError = "No transactions were found on this account."
                                importing = false
                                return
                            }
                            // Saves a history snapshot of just the imported set;
                            // does not touch the live budget (matches the web).
                            store.importPlaidTransactions(transactions)
                            importing = false
                        } catch {
                            importError = describe(error)
                            importing = false
                        }
                    }
                }, onExit: {
                    importing = false
                })
            } catch {
                importError = describe(error)
                importing = false
            }
        }
    }

    private func describe(_ error: Error) -> String {
        (error as? APIError)?.errorDescription ?? error.localizedDescription
    }
}

#Preview {
    NavigationStack { BudgetingView() }
}
