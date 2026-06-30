//
//  HistoryTabView.swift
//  FinnaCalcIOS
//
//  The "History" tab of the Budget Planner, ported from the `value="history"`
//  TabsContent (plus the Save-Snapshot and History-Detail dialogs) in
//  ../FinnaCalc/app/budgeting/page.tsx.
//
//  Lists saved budget snapshots (BudgetHistoryEntry) newest-first as cards
//  showing the name, date range, and budget type. Tapping "View Details" opens a
//  sheet with the snapshot's income/expenses/net totals and its budget items
//  grouped by category. A "Save to History" action opens a sheet that captures a
//  custom name + start/end date range and calls store.saveSnapshot. Snapshots can
//  be deleted with confirmation.
//

import SwiftUI

struct HistoryTabView: View {
    @EnvironmentObject var store: BudgetStore

    @State private var saveSheetPresented = false
    @State private var viewingEntry: BudgetHistoryEntry?
    @State private var pendingDelete: BudgetHistoryEntry?

    var body: some View {
        FCCard {
            FCCardHeader {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        FCCardTitle("Budget History")
                        FCCardDescription("Review your past budget snapshots.")
                    }
                    Spacer(minLength: 8)
                    FCButton(variant: .outline, size: .sm, label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save to History")
                        }
                    }, action: { saveSheetPresented = true })
                }
            }
            FCCardContent {
                if store.history.isEmpty {
                    Text("No budget history saved yet. Save a snapshot from the \"Budget\" tab!")
                        .font(.system(size: Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32) // py-8
                } else {
                    VStack(spacing: 16) { // space-y-4
                        ForEach(store.history) { entry in
                            HistoryEntryRow(
                                entry: entry,
                                onView: { viewingEntry = entry },
                                onDelete: { pendingDelete = entry }
                            )
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Theme.background)
        .sheet(isPresented: $saveSheetPresented) {
            SaveSnapshotSheet { name, start, end in
                store.saveSnapshot(name: name, startDate: start, endDate: end)
            }
        }
        .sheet(item: $viewingEntry) { entry in
            HistoryDetailSheet(entry: entry)
        }
        .alert(
            "Delete snapshot?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { entry in
            Button("Delete", role: .destructive) { store.deleteSnapshot(entry) }
            Button("Cancel", role: .cancel) {}
        } message: { entry in
            Text("Are you sure you want to delete the history snapshot \"\(entry.name)\"?")
        }
    }
}

// MARK: - List row

/// One snapshot card: `border p-4 rounded-lg shadow-sm bg-background
/// flex justify-between items-center`.
private struct HistoryEntryRow: View {
    let entry: BudgetHistoryEntry
    let onView: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 18, weight: .semibold)) // text-lg font-semibold
                    .foregroundColor(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(HistoryDate.range(entry.startDate, entry.endDate))
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
                Text("\(entry.budgetType.title) Budget")
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                FCButton("View Details", variant: .outline, size: .sm, action: onView)
                FCButton(variant: .ghost, size: .sm, label: {
                    Image(systemName: "trash")
                        .foregroundColor(Theme.negative)
                }, action: onDelete)
            }
        }
        .padding(16) // p-4
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1) // shadow-sm
    }
}

// MARK: - Save Snapshot sheet

/// Mirrors the "Save Budget Snapshot" dialog: optional custom name + a start/end
/// date range (defaulting to the current month). Validation matches the web's
/// handleSaveBudgetHistory: start required, start <= end, 1 week minimum and
/// 1 year maximum span. On save it hands ISO-8601 strings up to the store.
private struct SaveSnapshotSheet: View {
    let onSave: (_ name: String, _ start: String, _ end: String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var customName = ""
    @State private var startDate: Date = HistoryDate.monthStart
    @State private var endDate: Date = Date()
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { // grid gap-4
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Budget Name (Optional)")
                        FCTextField(
                            "e.g., Budget for \(HistoryDate.monthYear(Date()))",
                            text: $customName
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Select Date Range")
                        DatePicker(
                            "Start Date",
                            selection: $startDate,
                            displayedComponents: .date
                        )
                        .font(.system(size: Theme.FontSize.sm, weight: .medium))
                        .foregroundColor(Theme.foreground)
                        DatePicker(
                            "End Date",
                            selection: $endDate,
                            displayedComponents: .date
                        )
                        .font(.system(size: Theme.FontSize.sm, weight: .medium))
                        .foregroundColor(Theme.foreground)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundColor(Theme.negative)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .navigationTitle("Save Budget Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Snapshot") { attemptSave() }
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.sm, weight: .medium))
            .foregroundColor(Theme.foreground)
    }

    private func attemptSave() {
        errorText = nil

        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        if start > end {
            errorText = "Start date cannot be after end date."
            return
        }

        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        if days < 6 { // minimum timeframe is one week
            errorText = "The minimum timeframe is one week."
            return
        }
        if days > 366 { // maximum timeframe is one year
            errorText = "The maximum timeframe is one year."
            return
        }

        let defaultName: String = {
            let base = "Budget: \(HistoryDate.medium(start))"
            return start == end ? base : base + " - \(HistoryDate.medium(end))"
        }()
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultName
            : customName.trimmingCharacters(in: .whitespacesAndNewlines)

        onSave(name, HistoryDate.iso(start), HistoryDate.iso(end))
        dismiss()
    }
}

// MARK: - History Detail sheet

/// Mirrors the "History Detail" dialog: the snapshot's three totals followed by
/// its income then expense items, each grouped by category.
private struct HistoryDetailSheet: View {
    let entry: BudgetHistoryEntry

    @Environment(\.dismiss) private var dismiss

    private var incomeGroups: [(category: String, items: [BudgetItem])] {
        grouped(.income)
    }
    private var expenseGroups: [(category: String, items: [BudgetItem])] {
        grouped(.expense)
    }

    /// Group the snapshot's items (filtered to its budgetType) by category,
    /// preserving first-seen order — matches the web `reduce` over budgetItems.
    private func grouped(_ type: ItemType) -> [(category: String, items: [BudgetItem])] {
        var order: [String] = []
        var buckets: [String: [BudgetItem]] = [:]
        for item in entry.budgetItems
        where item.budgetType == entry.budgetType && item.type == type {
            if buckets[item.category] == nil { order.append(item.category) }
            buckets[item.category, default: []].append(item)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { // space-y-6
                    Text(
                        "Details for the budget from "
                        + HistoryDate.long(entry.startDate)
                        + " to "
                        + HistoryDate.long(entry.endDate) + "."
                    )
                    .font(.system(size: Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)

                    totalsRow

                    sectionHeader("Income Items")
                    if incomeGroups.isEmpty {
                        emptyLine("No income items in this snapshot.")
                    } else {
                        itemGroups(incomeGroups, isIncome: true)
                    }

                    sectionHeader("Expense Items")
                    if expenseGroups.isEmpty {
                        emptyLine("No expense items in this snapshot.")
                    } else {
                        itemGroups(expenseGroups, isIncome: false)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // grid grid-cols-3 gap-4 of summary cards
    private var totalsRow: some View {
        HStack(alignment: .top, spacing: 16) {
            totalCard("Monthly Income",
                      CalcFormat.currency(entry.monthlyIncome),
                      Theme.positive)
            totalCard("Monthly Expenses",
                      CalcFormat.currency(entry.monthlyExpenses),
                      Theme.negative)
            totalCard("Net Income",
                      CalcFormat.currency(entry.monthlyNet),
                      entry.monthlyNet >= 0 ? Theme.positive : Theme.negative)
        }
    }

    private func totalCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: 20, weight: .bold)) // text-xl font-bold
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(16) // p-4
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    // text-lg font-semibold border-b pb-2
    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.foreground)
            Divider().background(Theme.border)
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.sm))
            .foregroundColor(Theme.mutedForeground)
    }

    private func itemGroups(
        _ groups: [(category: String, items: [BudgetItem])],
        isIncome: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) { // space-y-3
            ForEach(groups, id: \.category) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.category)
                        .font(.system(size: Theme.FontSize.base, weight: .semibold))
                        .foregroundColor(Theme.foreground)
                    VStack(spacing: 8) { // space-y-2
                        ForEach(group.items) { item in
                            itemRow(item, isIncome: isIncome)
                        }
                    }
                }
            }
        }
    }

    // flex justify-between items-center bg-muted/40 p-2 rounded text-sm
    private func itemRow(_ item: BudgetItem, isIncome: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(item.subcategory.isEmpty ? "No description" : item.subcategory)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.primary) // text-blue-600
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(
                (isIncome ? "+" : "-")
                + CalcFormat.currency(item.amount)
                + " (\(item.frequency.rawValue))"
            )
            .font(.system(size: Theme.FontSize.sm, weight: .bold))
            .foregroundColor(isIncome ? Theme.positive : Theme.negative)
        }
        .padding(8) // p-2
        .background(Theme.muted.opacity(0.4)) // bg-muted/40
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
}

// MARK: - Date helpers

/// Snapshot dates are persisted as ISO-8601 strings (mirroring the web's
/// `Date.toISOString()`), then formatted for display. `parse` tolerates both
/// full ISO-8601 timestamps and bare `yyyy-MM-dd` values.
private enum HistoryDate {
    static var monthStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Produce an ISO-8601 string for storage (matches `toISOString()` shape).
    static func iso(_ date: Date) -> String { isoFormatter.string(from: date) }

    static func parse(_ raw: String) -> Date? {
        if let d = isoFormatter.date(from: raw) { return d }
        if let d = isoNoFraction.date(from: raw) { return d }
        return ymd.date(from: raw)
    }

    /// `format(date, 'PPP')` — e.g. "June 1, 2026".
    static func long(_ raw: String) -> String {
        guard let d = parse(raw) else { return raw }
        return d.formatted(.dateTime.month(.wide).day().year())
    }

    /// `format(date, 'MMM d, yyyy')` — e.g. "Jun 1, 2026".
    static func medium(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    /// `format(date, 'MMMM yyyy')` — e.g. "June 2026".
    static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    /// The list-row date range: "June 1, 2026 - June 30, 2026" ('PPP' - 'PPP').
    static func range(_ start: String, _ end: String) -> String {
        long(start) + " - " + long(end)
    }
}

// MARK: - Preview

#Preview {
    let store = BudgetStore()
    store.history = [
        BudgetHistoryEntry(
            id: "1",
            name: "Budget: Jun 1, 2026 - Jun 30, 2026",
            startDate: "2026-06-01T00:00:00.000Z",
            endDate: "2026-06-30T00:00:00.000Z",
            budgetItems: [
                BudgetItem(id: "a", category: "Salary", subcategory: "Main job",
                           amount: 5000, frequency: .monthly, type: .income,
                           isFixed: true, budgetType: .personal, importDate: nil),
                BudgetItem(id: "b", category: "Housing", subcategory: "Rent",
                           amount: 1800, frequency: .monthly, type: .expense,
                           isFixed: true, budgetType: .personal, importDate: nil),
                BudgetItem(id: "c", category: "Food", subcategory: "Groceries",
                           amount: 120, frequency: .weekly, type: .expense,
                           isFixed: false, budgetType: .personal, importDate: nil),
            ],
            monthlyIncome: 5000,
            monthlyExpenses: 2319.6,
            monthlyNet: 2680.4,
            budgetType: .personal
        )
    ]
    return ScrollView {
        HistoryTabView().environmentObject(store)
    }
    .background(Theme.background)
}
