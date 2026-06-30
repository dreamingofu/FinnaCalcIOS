//
//  DebtCardView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/components/debt-card.tsx`.
//
//  Connect a Plaid "liabilities" link, pull credit cards + loans, and render
//  total debt, minimum payments, and credit-utilization health (FICO bands).
//
//  Self-contained: owns its Plaid link/load state machine and its own
//  PlaidLinkCoordinator. Does not read from BudgetStore.
//

import SwiftUI

struct DebtCardView: View {

    // MARK: Connection state machine (mirrors the web component)

    private enum Status { case idle, linking, loading, ready, error }

    @State private var linkToken: String?
    @State private var data: LiabilitiesResponse?
    @State private var status: Status = .idle
    @State private var error: String?

    @StateObject private var plaid = PlaidLinkCoordinator()

    // MARK: Color approximations for web hues the design system lacks

    private let blue = Theme.primary           // bg-blue-600 / text-blue-600
    private let amber = Color(red: 0.96, green: 0.62, blue: 0.07) // amber-500/600

    // MARK: Money formatting (web fmtMoney / fmtMoney2)

    private var currencyCode: String { data?.currency ?? "USD" }
    private func fmtMoney(_ n: Double) -> String { money(n, fraction: 0) }
    private func fmtMoney2(_ n: Double) -> String { money(n, fraction: 2) }
    /// Web fmtMoney: toLocaleString("en-US", { style: "currency", currency }) —
    /// honors the account's currency code instead of a hardcoded "$".
    private func money(_ n: Double, fraction: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.locale = Locale(identifier: "en_US")
        f.roundingMode = .halfUp
        f.minimumFractionDigits = fraction
        f.maximumFractionDigits = fraction
        return f.string(from: NSNumber(value: n.isFinite ? n : 0)) ?? "$0"
    }

    // MARK: Utilization health bands (FICO guidance: under 30% is healthy)

    private struct Band {
        let label: String
        let text: Color
        let bar: Color
    }

    private func utilizationBand(_ u: Double?) -> Band {
        guard let u else { return Band(label: "—", text: Theme.mutedForeground, bar: Theme.mutedForeground) }
        if u < 10 { return Band(label: "Excellent", text: Theme.positive, bar: Theme.positive) }
        if u < 30 { return Band(label: "Good", text: Theme.positive, bar: Theme.positive) }
        if u < 50 { return Band(label: "Fair", text: amber, bar: amber) }
        return Band(label: "High", text: Theme.negative, bar: Theme.negative)
    }

    // MARK: Body

    var body: some View {
        FCCard {
            header
            FCCardContent {
                content
                    .padding(.top, 20) // pt-5
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(blue)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "creditcard")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Debt & Credit Utilization")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.cardForeground)
                        Text("Powered by Plaid · soft, no credit inquiry")
                            .font(.system(size: Theme.FontSize.xs))
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
                Spacer(minLength: 8)
                if status == .ready {
                    FCButton(variant: .outline, size: .sm) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                            Text("New")
                        }
                    } action: { reset() }
                }
            }
            .padding(24)

            Divider().overlay(Theme.border) // border-b border-border
        }
    }

    // MARK: Content (state switch)

    @ViewBuilder
    private var content: some View {
        if status == .ready, let data {
            connected(data)
        } else if status == .loading {
            loading
        } else {
            idle
        }
    }

    // MARK: Connected

    private func connected(_ data: LiabilitiesResponse) -> some View {
        let overall = utilizationBand(data.overallUtilization)
        return VStack(alignment: .leading, spacing: 24) { // space-y-6

            // Summary tiles
            HStack(alignment: .top, spacing: 16) {
                summaryTile(title: "Total debt") {
                    Text(fmtMoney(data.totalDebt))
                        .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                        .foregroundColor(Theme.cardForeground)
                }
                summaryTile(title: "Min. payments / mo") {
                    Text(fmtMoney(data.totalMinimumPayments))
                        .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                        .foregroundColor(Theme.cardForeground)
                }
                summaryTile(title: "Overall utilization") {
                    (
                        Text(data.overallUtilization != nil
                             ? "\(CalcFormat.fixed(data.overallUtilization!, 1))%"
                             : "—")
                            .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                        + Text("  \(overall.label)")
                            .font(.system(size: Theme.FontSize.sm, weight: .medium))
                    )
                    .foregroundColor(overall.text)
                }
            }

            // Overall utilization bar
            if let u = data.overallUtilization {
                VStack(alignment: .leading, spacing: 8) {
                    progressBar(value: u, height: 10, fill: overall.bar)
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                        Text("Keeping utilization under 30% helps your credit score.")
                    }
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
                }
            }

            // Credit cards
            if !data.creditLines.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Credit cards")
                    ForEach(data.creditLines) { card in
                        creditCardRow(card)
                    }
                }
            }

            // Other debts (Loans)
            if !data.otherDebts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Loans")
                    ForEach(data.otherDebts) { debt in
                        loanRow(debt)
                    }
                }
            }

            Text("Balances are pulled from your linked accounts via Plaid. This is a soft connection and does not affect your credit score.")
                .font(.system(size: 11))
                .foregroundColor(Theme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryTile<V: View>(title: String, @ViewBuilder value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.sm, weight: .semibold))
            .foregroundColor(Theme.mutedForeground)
    }

    // MARK: Credit card row

    private func creditCardRow(_ c: CreditLine) -> some View {
        let band = utilizationBand(c.utilization)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    (
                        Text(c.name).font(.system(size: Theme.FontSize.base, weight: .semibold))
                        + Text(c.mask != nil ? " ····\(c.mask!)" : "")
                            .font(.system(size: Theme.FontSize.base))
                            .foregroundColor(Theme.mutedForeground)
                    )
                    .foregroundColor(Theme.cardForeground)
                    .lineLimit(1)

                    Text(creditSubtitle(c))
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(c.utilization != nil ? "\(CalcFormat.fixed(c.utilization!, 0))%" : "—")
                        .font(.system(size: Theme.FontSize.base, weight: .bold))
                        .foregroundColor(band.text)
                    Text("utilization")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            .padding(.bottom, 8)

            if let u = c.utilization {
                progressBar(value: u, height: 6, fill: band.bar)
                    .padding(.bottom, 12)
            }

            // Detail chips: APR / min payment / due / overdue
            FlowChips(items: creditChips(c))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private func creditSubtitle(_ c: CreditLine) -> String {
        var s = fmtMoney2(c.balance)
        if let limit = c.limit { s += " of \(fmtMoney2(limit)) limit" }
        return s
    }

    private func creditChips(_ c: CreditLine) -> [Chip] {
        var chips: [Chip] = []
        if let apr = c.apr {
            chips.append(Chip(label: "APR: ", value: "\(CalcFormat.fixed(apr, 2))%"))
        }
        if let min = c.minimumPayment {
            chips.append(Chip(label: "Min payment: ", value: fmtMoney2(min)))
        }
        if let due = c.nextDueDate {
            chips.append(Chip(label: "Due: ", value: due))
        }
        if c.isOverdue {
            chips.append(Chip(label: "", value: "Overdue", emphasisColor: Theme.negative))
        }
        return chips
    }

    // MARK: Loan row

    private func loanRow(_ d: OtherDebt) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Theme.muted)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: d.type == "student" ? "graduationcap" : "house")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.foreground)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name)
                    .font(.system(size: Theme.FontSize.base, weight: .semibold))
                    .foregroundColor(Theme.cardForeground)
                    .lineLimit(1)
                Text(loanSubtitle(d))
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(fmtMoney2(d.balance))
                    .font(.system(size: Theme.FontSize.base, weight: .bold))
                    .foregroundColor(Theme.cardForeground)
                if let min = d.minimumPayment {
                    Text("\(fmtMoney2(min))/mo")
                        .font(.system(size: Theme.FontSize.xs))
                        .foregroundColor(Theme.mutedForeground)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private func loanSubtitle(_ d: OtherDebt) -> String {
        // "{type} loan · {apr}% APR"  (type capitalized)
        var s = "\(d.type.capitalized) loan"
        if let apr = d.apr { s += " · \(CalcFormat.fixed(apr, 2))% APR" }
        return s
    }

    // MARK: Loading

    private var loading: some View {
        VStack(spacing: 0) {
            SpinnerView(color: blue, size: 32)
                .padding(.bottom, 12)
            Text("Importing your accounts…")
                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                .foregroundColor(Theme.cardForeground)
            Text("Crunching balances and limits")
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.mutedForeground)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: Idle / connect prompt

    private var idle: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(blue.opacity(0.12)) // bg-blue-50 / dark bg-blue-950 approximation
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "creditcard")
                        .font(.system(size: 28))
                        .foregroundColor(blue)
                )
                .padding(.bottom, 16)

            Text("See your debt & utilization")
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundColor(Theme.cardForeground)
                .padding(.bottom, 4)

            Text("Securely link your cards and loans to see balances, APRs, minimum payments, and your credit utilization — the second biggest factor in your credit score.")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 384) // max-w-sm
                .padding(.bottom, 20)

            if let error {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16))
                    Text(error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: Theme.FontSize.xs))
                .foregroundColor(Theme.negative)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.negative.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .strokeBorder(Theme.negative.opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: 384)
                .padding(.bottom, 16)
            }

            FCButton(variant: .default) {
                HStack(spacing: 8) {
                    if status == .linking {
                        SpinnerView(color: Theme.primaryForeground, size: 16)
                        Text("Opening…")
                    } else {
                        Image(systemName: "plus.circle")
                        Text("Connect accounts")
                    }
                }
            } action: { initLink() }
            .disabled(status == .linking)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 13))
                Text("Bank-level encryption · soft connection, no credit inquiry")
            }
            .font(.system(size: 11))
            .foregroundColor(Theme.mutedForeground)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: Proportional bar (replaces web's <div> progress)

    private func progressBar(value: Double, height: CGFloat, fill: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.muted)
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 100) / 100))
            }
        }
        .frame(height: height)
    }

    // MARK: Actions / flow

    private func initLink() {
        error = nil
        status = .linking
        Task { @MainActor in
            do {
                let token = try await PlaidService.createLinkToken(product: .liabilities)
                linkToken = token
                openLink(token)
            } catch {
                self.error = "Could not start the connection."
                self.status = .error
            }
        }
    }

    private func openLink(_ token: String) {
        plaid.open(
            linkToken: token,
            onSuccess: { publicToken in
                Task { @MainActor in onPlaidSuccess(publicToken) }
            },
            onExit: {
                Task { @MainActor in
                    // Only revert if we never advanced past linking (web parity).
                    if status == .linking { status = .idle }
                }
            }
        )
    }

    private func onPlaidSuccess(_ publicToken: String) {
        status = .loading
        error = nil
        Task { @MainActor in
            do {
                let response = try await PlaidService.importLiabilities(publicToken: publicToken)
                if response.creditLines.isEmpty && response.otherDebts.isEmpty {
                    throw DebtError.empty
                }
                data = response
                status = .ready
            } catch DebtError.empty {
                error = "No credit cards or loans were found on this account."
                status = .error
            } catch {
                self.error = "Could not load your debts."
                self.status = .error
            }
        }
    }

    private func reset() {
        data = nil
        linkToken = nil
        status = .idle
        error = nil
    }

    private enum DebtError: Error { case empty }
}

// MARK: - Detail chip (label + emphasized value)

private struct Chip: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var emphasisColor: Color? = nil
}

/// Wrapping row of small label/value chips (web `flex flex-wrap gap-x-5 gap-y-1`).
private struct FlowChips: View {
    let items: [Chip]

    var body: some View {
        FlowLayout(hSpacing: 20, vSpacing: 4) {
            ForEach(items) { chip in
                if let color = chip.emphasisColor {
                    Text(chip.value)
                        .font(.system(size: Theme.FontSize.xs, weight: .semibold))
                        .foregroundColor(color)
                } else {
                    (
                        Text(chip.label).foregroundColor(Theme.mutedForeground)
                        + Text(chip.value).fontWeight(.medium).foregroundColor(Theme.foreground)
                    )
                    .font(.system(size: Theme.FontSize.xs))
                }
            }
        }
    }
}

// MARK: - Simple flow layout (iOS 16 compatible, no Layout protocol needed)

/// Wraps subviews left-to-right onto new lines, mirroring CSS `flex-wrap`.
private struct FlowLayout<Content: View>: View {
    let hSpacing: CGFloat
    let vSpacing: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            self.generate(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generate(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            content()
                .padding(.trailing, hSpacing)
                .padding(.bottom, vSpacing)
                .alignmentGuide(.leading) { d in
                    if abs(width - d.width) > geo.size.width {
                        width = 0
                        height -= d.height
                    }
                    let result = width
                    width -= d.width
                    return result
                }
                .alignmentGuide(.top) { _ in
                    let result = height
                    return result
                }
        }
        .background(heightReader)
    }

    private var heightReader: some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async { totalHeight = geo.size.height }
            return Color.clear
        }
    }
}

// MARK: - Spinner (replaces lucide RefreshCw animate-spin)

private struct SpinnerView: View {
    let color: Color
    let size: CGFloat
    @State private var spin = false

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: size * 0.85, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DebtCardView()
            .padding(24)
    }
    .background(Theme.background)
}
