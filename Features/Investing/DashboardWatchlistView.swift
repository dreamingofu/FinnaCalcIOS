//
//  DashboardWatchlistView.swift
//  FinnaCalcIOS
//
//  Native port of `../FinnaCalc/components/dashboard-watchlist.tsx`.
//
//  A card of watchlist tiles. Each tile renders a `TradingViewMini` sparkline
//  for its symbol with a hover-equivalent remove (X) button; the header lets you
//  add a ticker via an inline field. The symbol list is persisted to
//  UserDefaults under the same `finnacalc.watchlist` key the web app uses in
//  localStorage, seeded with the same `DEFAULT_SYMBOLS`.
//
//  The web grid is `grid-cols-4`; on a phone that collapses to 2 columns (the
//  responsive equivalent) while keeping the exact tile composition, height (140),
//  rounded-xl border, and per-tile remove control.
//

import SwiftUI

struct DashboardWatchlistView: View {

    // localStorage key + seed list, ported 1:1 from the web component.
    private static let storageKey = "finnacalc.watchlist"
    private static let defaultSymbols = ["AAPL", "TSLA", "NVDA", "MSFT", "AMZN", "META", "GOOGL", "BINANCE:BTCUSDT"]

    @State private var symbols: [String] = DashboardWatchlistView.loadSymbols()
    @State private var adding = false
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    // grid-cols-4 on the web → 2 columns on a phone (responsive equivalent).
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        FCCard {
            header
            content
        }
    }

    // MARK: - Header (Star + title, Add control)

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                // <Star className="h-5 w-5 text-blue-600" /> + CardTitle (text-lg)
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(Theme.sans(20))
                        .foregroundColor(Theme.primary)
                    Text("My Watchlist")
                        .font(Theme.sans(18, weight: .semibold)) // text-lg
                        .foregroundStyle(Theme.cardForeground)
                }

                Spacer(minLength: 8)

                if adding {
                    addingControls
                } else {
                    // <Button size="sm" variant="outline"> <Plus /> Add
                    FCButton(variant: .outline, size: .sm) {
                        Label("Add", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                    } action: {
                        adding = true
                        // autoFocus on the input
                        Task { @MainActor in draftFocused = true }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12) // pb-3

            Divider().background(Theme.border) // border-b border-border
        }
    }

    @ViewBuilder
    private var addingControls: some View {
        HStack(spacing: 8) {
            // <Input placeholder="Ticker e.g. AMD" className="w-36" /> (autoFocus)
            FCTextField("Ticker e.g. AMD", text: $draft)
                .frame(width: 144) // w-36
                .focused($draftFocused)
                .submitLabel(.done)
                .onSubmit(addSymbol) // onKeyDown Enter → addSymbol
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.characters)

            // <Button size="sm" className="bg-blue-600"> Add
            FCButton("Add", size: .sm, action: addSymbol)

            // <Button size="sm" variant="ghost"> Cancel
            FCButton("Cancel", variant: .ghost, size: .sm) {
                adding = false
                draft = ""
            }
        }
    }

    // MARK: - Content (grid of tiles / empty state)

    private var content: some View {
        Group {
            if symbols.isEmpty {
                // col-span-4 text-sm text-muted-foreground text-center py-8
                Text("Your watchlist is empty. Add a ticker to track it here.")
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundStyle(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32) // py-8
            } else {
                LazyVGrid(columns: columns, spacing: 16) { // grid gap-4
                    ForEach(symbols, id: \.self) { symbol in
                        tile(for: symbol)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)   // pt-5
        .padding(.bottom, 24)
    }

    private func tile(for symbol: String) -> some View {
        // relative rounded-xl border border-border p-2
        ZStack(alignment: .topTrailing) {
            TradingViewMini(symbol: symbol, height: 140)
                .padding(8) // p-2

            // remove button — always visible on touch (no hover on iOS):
            // top-1.5 right-1.5, w-5 h-5 rounded-full bg-muted hover:bg-red-500
            Button {
                remove(symbol)
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.sans(10, weight: .bold))
                    .foregroundColor(Theme.mutedForeground)
                    .frame(width: 20, height: 20)
                    .background(Theme.muted)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Remove \(symbol)")
            .padding(6) // top-1.5 / right-1.5
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)) // rounded-xl ≈ lg
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1) // border border-border
        )
    }

    // MARK: - Actions

    private func addSymbol() {
        let s = draft.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty else { return }
        if !symbols.contains(s) { persist(symbols + [s]) }
        draft = ""
        adding = false
        draftFocused = false
    }

    private func remove(_ s: String) {
        persist(symbols.filter { $0 != s })
    }

    private func persist(_ next: [String]) {
        symbols = next
        UserDefaults.standard.set(next, forKey: Self.storageKey)
    }

    // MARK: - Persistence

    private static func loadSymbols() -> [String] {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String], !saved.isEmpty {
            return saved
        }
        return defaultSymbols
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DashboardWatchlistView()
            .padding(16)
    }
    .background(Theme.background)
}
