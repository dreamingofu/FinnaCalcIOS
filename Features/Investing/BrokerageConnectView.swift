//
//  BrokerageConnectView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of components/brokerage-connect.tsx.
//  Connect any broker via SnapTrade, view linked accounts + positions.
//

import SwiftUI

struct BrokerageConnectView: View {
    @State private var data: SnapTradeAccountsResponse?
    @State private var loading = true
    @State private var connecting = false
    @State private var error: String?
    @State private var portalURL: PortalURL?

    /// Identifiable wrapper so we can drive `.sheet(item:)` with the portal URL.
    private struct PortalURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    // MARK: Derived state (mirrors the web defaults)

    private var configured: Bool { data?.configured ?? true }
    private var accounts: [BrokerageAccount] { data?.accounts ?? [] }
    private var positions: [BrokeragePosition] { data?.positions ?? [] }
    private var currency: String { data?.currency ?? "USD" }
    private var hasAccounts: Bool { !accounts.isEmpty }

    // MARK: Money formatting

    private func money(_ n: Double?, _ currencyCode: String? = nil) -> String {
        guard let n else { return "—" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currencyCode ?? currency
        fmt.locale = Locale(identifier: "en_US")
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: n)) ?? "—"
    }

    // MARK: Body

    var body: some View {
        FCCard {
            header
            Divider().background(Theme.border)
            FCCardContent {
                content
            }
        }
        .onAppear {
            if data == nil { Task { await load() } }
        }
        .sheet(item: $portalURL, onDismiss: {
            // The user just linked a broker in the portal — refresh accounts.
            Task { await load() }
        }) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    // MARK: Header

    private var header: some View {
        FCCardHeader {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.primary)
                        .frame(width: 32, height: 32)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Brokerage")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.cardForeground)
                    Text("Connect any broker to view & trade · Powered by SnapTrade")
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                }
                Spacer(minLength: 8)
                if hasAccounts {
                    HStack(spacing: 8) {
                        FCButton(variant: .outline, size: .sm) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13))
                                Text("Refresh")
                            }
                        } action: {
                            Task { await load() }
                        }
                        .disabled(loading)

                        FCButton("Disconnect", variant: .outline, size: .sm) {
                            Task { await disconnect() }
                        }
                    }
                }
            }
        }
    }

    // MARK: Content switch

    @ViewBuilder
    private var content: some View {
        if loading {
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.muted)
                        .frame(height: 48)
                }
            }
        } else if !configured {
            notConfiguredNotice
        } else if hasAccounts {
            connectedState
        } else {
            connectPrompt
        }
    }

    // MARK: Not configured

    private var notConfiguredNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16))
                .foregroundColor(Theme.mutedForeground)
            (Text("Brokerage connections aren't configured yet. Add ")
                + Text("SNAPTRADE_CLIENT_ID").font(.system(size: Theme.FontSize.xs, design: .monospaced))
                + Text(" and ")
                + Text("SNAPTRADE_CONSUMER_KEY").font(.system(size: Theme.FontSize.xs, design: .monospaced))
                + Text(" to enable connecting a broker."))
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.muted.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    // MARK: Connected state

    private var connectedState: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Accounts grid (web uses 3 columns; adaptive here for narrow screens)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
                spacing: 16
            ) {
                ForEach(accounts) { account in
                    accountCard(account)
                }
            }

            // Positions table
            if !positions.isEmpty {
                positionsTable
            }

            // Footer actions
            HStack(alignment: .center) {
                FCButton(variant: .outline, size: .sm) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                        Text(connecting ? "Opening…" : "Connect another broker")
                    }
                } action: {
                    Task { await connect() }
                }
                .disabled(connecting)

                Spacer(minLength: 8)

                Text("Trading from FinnaCalc is coming next.")
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
        }
    }

    private func accountCard(_ a: BrokerageAccount) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(a.institution)
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
                .lineLimit(1)
            (Text(a.name).font(.system(size: Theme.FontSize.base, weight: .semibold))
                + Text(a.number.isEmpty ? "" : " ····\(String(a.number.suffix(4)))")
                    .font(.system(size: Theme.FontSize.base))
                    .foregroundColor(Theme.mutedForeground))
                .foregroundColor(Theme.cardForeground)
                .lineLimit(1)
            Text(money(a.totalValue, a.currency))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.cardForeground)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var positionsTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 8) {
                Text("Symbol")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Units")
                    .frame(width: 56, alignment: .trailing)
                Text("Price")
                    .frame(width: 72, alignment: .trailing)
                Text("Mkt value")
                    .frame(width: 84, alignment: .trailing)
                Text("Open P/L")
                    .frame(width: 84, alignment: .trailing)
            }
            .font(.system(size: Theme.FontSize.xs, weight: .semibold))
            .foregroundColor(Theme.mutedForeground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.muted.opacity(0.3))

            Divider().background(Theme.border)

            // Rows
            ForEach(Array(positions.enumerated()), id: \.offset) { index, p in
                positionRow(p)
                if index < positions.count - 1 {
                    Divider().background(Theme.border.opacity(0.6))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func positionRow(_ p: BrokeragePosition) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(p.symbol)
                    .font(.system(size: Theme.FontSize.sm, weight: .bold))
                    .foregroundColor(Theme.cardForeground)
                if !p.description.isEmpty {
                    Text(p.description)
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(CalcFormat.raw(p.units)) // raw units like the web {p.units} (keep fractional-share precision)
                .frame(width: 56, alignment: .trailing)
                .foregroundColor(Theme.cardForeground)

            Text(money(p.price))
                .frame(width: 72, alignment: .trailing)
                .foregroundColor(Theme.cardForeground)

            Text(money(p.marketValue))
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .frame(width: 84, alignment: .trailing)
                .foregroundColor(Theme.cardForeground)

            pnlCell(p.openPnl)
                .frame(width: 84, alignment: .trailing)
        }
        .font(.system(size: Theme.FontSize.sm))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func pnlCell(_ pnl: Double?) -> some View {
        if let pnl {
            Text("\(pnl >= 0 ? "+" : "")\(money(pnl))")
                .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                .foregroundColor(pnl >= 0 ? Theme.positive : Theme.negative)
        } else {
            Text("—")
                .font(.system(size: Theme.FontSize.sm, weight: .semibold))
                .foregroundColor(Theme.cardForeground)
        }
    }

    // MARK: Connect prompt (no accounts)

    private var connectPrompt: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "link")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.primary)
            }
            .padding(.bottom, 16)

            Text("Connect the broker you already use")
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundColor(Theme.cardForeground)
                .padding(.bottom, 4)

            Text("Link Robinhood, Webull, Schwab, Fidelity and more to see your real positions in FinnaCalc — and trade from here as we roll it out.")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .padding(.bottom, 20)

            if let error {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.negative)
                    Text(error)
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.negative)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 420)
                .background(Theme.negative.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.negative.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .padding(.bottom, 16)
            }

            FCButton(variant: .default, size: .default) {
                HStack(spacing: 8) {
                    if connecting {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                        Text("Opening…")
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                        Text("Connect a brokerage")
                    }
                }
            } action: {
                Task { await connect() }
            }
            .disabled(connecting)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 13))
                Text("Secure connection via SnapTrade · we never see your brokerage password")
            }
            .font(.system(size: 11))
            .foregroundColor(Theme.mutedForeground)
            .multilineTextAlignment(.center)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: Actions

    @MainActor
    private func load() async {
        loading = true
        do {
            let json = try await SnapTradeService.accounts()
            Task { @MainActor in
                data = json
                if let e = json.error { error = e }
                loading = false
            }
        } catch {
            let message = (error as? APIError)?.errorDescription
            Task { @MainActor in
                data = SnapTradeAccountsResponse(
                    configured: true,
                    connected: nil,
                    accounts: [],
                    positions: [],
                    totalValue: nil,
                    currency: nil,
                    error: nil
                )
                // Surface the server's error text like the web's load() does.
                self.error = message
                loading = false
            }
        }
    }

    @MainActor
    private func connect() async {
        error = nil
        connecting = true
        do {
            let url = try await SnapTradeService.connect()
            Task { @MainActor in
                portalURL = PortalURL(url: url)
                connecting = false
            }
        } catch let err as APIError {
            Task { @MainActor in
                error = err.errorDescription ?? "Could not start the connection."
                connecting = false
            }
        } catch {
            Task { @MainActor in
                self.error = "Could not start the connection."
                connecting = false
            }
        }
    }

    @MainActor
    private func disconnect() async {
        try? await SnapTradeService.disconnect()
        Task { @MainActor in
            if let d = data {
                data = SnapTradeAccountsResponse(
                    configured: d.configured,
                    connected: false,
                    accounts: [],
                    positions: [],
                    totalValue: nil,
                    currency: d.currency,
                    error: nil
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            BrokerageConnectView()
                .padding()
        }
        .background(Theme.background)
    }
}
