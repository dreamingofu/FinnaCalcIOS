//
//  TaxReviewViews.swift
//  FinnaCalcIOS
//
//  SwiftUI port of the tax-engine review/filing UI:
//    - components/tax-engine/ui/ReviewScreen.tsx   -> struct ReviewScreen
//    - components/tax-engine/ui/FilingScreen.tsx   -> struct FilingScreen
//    - components/tax-engine/ui/AuditRiskPanel.tsx -> struct AuditRiskPanel
//
//  These observe a `TaxEngineViewModel` (the SwiftUI port of useTaxEngine /
//  useLiveCalculation) so the rendered numbers track the live `result` exactly
//  like the web screens read the memoized calculation.
//
//  Fidelity notes vs. the web:
//    * ReviewScreen here is scoped to the line-by-line 1040 (via build1040Summary
//      + result.trace), the deduction check, the section "edit" jump list, and
//      the AuditRiskPanel — matching the React component minus the separately
//      ported SmartSuggestions widget. The "Continue to filing" CTA is exposed
//      through an optional `onFile` closure so the host can navigate.
//    * FilingScreen wires the real `EfileService.submit`. The current backend is
//      a structural stub that answers 501 "unsupported" for individual 1040
//      returns; that path returns a normal `EfileResult` (status `.unsupported`)
//      rather than throwing, so the capability-gap message renders inline —
//      faithful to the web's "E-file is coming soon" stub.
//    * iOS 16: post-`await` @State writes are wrapped in `Task { @MainActor in }`.
//

import SwiftUI

// MARK: - ReviewScreen

/// TS: `ReviewScreen({ result, answers, sections, onEdit, onFile })`.
///
/// Reads everything off the live view model. `onEdit` jumps back to a section
/// (by id); `onFile` advances to the filing step. Both are optional so the view
/// previews and composes standalone.
struct ReviewScreen: View {
    @ObservedObject var vm: TaxEngineViewModel

    /// TS: `onEdit(sectionId)`.
    var onEdit: ((String) -> Void)? = nil
    /// TS: `onFile()`.
    var onFile: (() -> Void)? = nil

    private var result: TaxCalculationResult { vm.result }
    private var summary: Form1040Summary { build1040Summary(result) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) { // space-y-6
                header
                deductionCheck
                answersCard
                lineByLineCard
                AuditRiskPanel(result: result)

                // Separator + right-aligned "Continue to filing" CTA.
                if onFile != nil {
                    Divider().background(Theme.border)
                    HStack {
                        Spacer()
                        FCButton(size: .default, label: {
                            HStack(spacing: 8) {
                                Text("Continue to filing")
                                Image(systemName: "arrow.right")
                            }
                        }, action: { onFile?() })
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background)
    }

    // MARK: Header

    /// TS: centered "Review your estimate" + refund/owe line.
    private var header: some View {
        VStack(spacing: 4) { // space-y-1
            Text("Review your estimate")
                .font(Theme.sans(Theme.FontSize.xl2, weight: .bold))
                .foregroundStyle(Theme.foreground)
            Text(
                result.owes
                    ? "You owe an estimated \(CalcFormat.currency(abs(result.refundOrOwed), fraction: 0))."
                    : "You're getting an estimated \(CalcFormat.currency(result.refundOrOwed, fraction: 0)) refund."
            )
            .font(Theme.sans(Theme.FontSize.sm))
            .foregroundStyle(Theme.mutedForeground)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Deduction check

    /// TS: "Deduction check" card — standard vs itemized with the chosen outcome.
    private var deductionCheck: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Deduction check")
                FCCardDescription(deductionCopy)
            }
        }
    }

    private var deductionCopy: String {
        let std = CalcFormat.currency(result.standardDeduction, fraction: 0)
        let item = CalcFormat.currency(result.itemizedDeduction, fraction: 0)
        let outcome = result.deductionUsed == .itemized
            ? "we itemized and saved you about \(CalcFormat.currency(result.itemizedSavings, fraction: 0))."
            : "the standard deduction is better for you."
        return "Standard \(std) vs. itemized \(item) — \(outcome)"
    }

    // MARK: Section edit list

    /// TS: "Your answers" card — a row per visible section with an Edit jump.
    private var answersCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Your answers")
                FCCardDescription("Jump back to any section to make changes.")
            }
            FCCardContent {
                VStack(spacing: 4) { // space-y-1
                    ForEach(vm.visibleSections, id: \.id) { section in
                        HStack {
                            Text(section.title)
                                .font(Theme.sans(Theme.FontSize.sm))
                                .foregroundStyle(Theme.foreground)
                            Spacer()
                            FCButton(variant: .ghost, size: .sm, label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                        .imageScale(.small)
                                    Text("Edit")
                                }
                            }, action: { onEdit?(section.id) })
                            .disabled(onEdit == nil)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: Full line-by-line return

    /// TS: "Your 1040, line by line" — every entry in `result.trace`.
    private var lineByLineCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Your 1040, line by line")
            }
            FCCardContent {
                VStack(spacing: 6) { // space-y-1.5
                    ForEach(result.trace, id: \.id) { line in
                        HStack(alignment: .firstTextBaseline) {
                            // label + dimmed form ref
                            (
                                Text(line.label)
                                    .foregroundColor(Theme.mutedForeground)
                                + Text("  \(line.formRef)")
                                    .foregroundColor(Theme.mutedForeground.opacity(0.7))
                            )
                            .font(Theme.sans(Theme.FontSize.sm))
                            Spacer()
                            Text(CalcFormat.currency(line.amount))
                                .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
                                .monospacedDigit() // tabular-nums
                                .foregroundColor(Theme.foreground)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AuditRiskPanel

/// TS: `AuditRiskPanel({ result })` — surfaces audit flags and not-fully-modeled
/// warnings. Renders nothing when both lists are empty (matches the early-return).
struct AuditRiskPanel: View {
    let result: TaxCalculationResult

    var body: some View {
        if result.auditFlags.isEmpty && result.warnings.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 12) { // space-y-3
                ForEach(Array(result.auditFlags.enumerated()), id: \.offset) { _, flag in
                    AlertBox(
                        destructive: flag.severity == .high,
                        systemImage: flag.severity == .high ? "exclamationmark.shield" : "info.circle",
                        title: flag.severity == .info ? "Heads up" : "Check this",
                        message: flag.message
                    )
                }
                ForEach(result.warnings, id: \.code) { warning in
                    AlertBox(
                        destructive: false,
                        systemImage: "info.circle",
                        title: nil,
                        message: warning.message
                    )
                }
            }
        }
    }
}

// MARK: - FilingScreen

/// TS: `FilingScreen({ result, onBack })`.
///
/// Print/PDF in the web is `window.print()`; on iOS the equivalent affordance is
/// the system share sheet, surfaced here as a "Save / share summary" action over
/// a plain-text rendering of `build1040Summary`. E-file goes through
/// `EfileService.submit(buildEfileBundle(result))`; the result (including the
/// 501 "unsupported" stub message) is shown inline.
struct FilingScreen: View {
    @ObservedObject var vm: TaxEngineViewModel

    /// TS: `onBack()`.
    var onBack: (() -> Void)? = nil

    @State private var acknowledged = false
    @State private var isSubmitting = false
    @State private var efileResult: EfileResult? = nil
    @State private var efileError: String? = nil
    @State private var showShareSheet = false

    private var result: TaxCalculationResult { vm.result }
    private var summary: Form1040Summary { build1040Summary(result) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { // space-y-6
                if onBack != nil {
                    FCButton(variant: .outline, size: .sm, label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                            Text("Back to review")
                        }
                    }, action: { onBack?() })
                }

                FCCard {
                    FCCardHeader {
                        FCCardTitle(headlineText)
                        FCCardDescription("Save a copy or share your estimate for your records.")
                    }
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 16) { // space-y-4
                            FCButton(variant: .outline, label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Save / share summary")
                                }
                            }, action: { showShareSheet = true })

                            // Alert: e-file capability note.
                            AlertBox(
                                destructive: false,
                                systemImage: "info.circle",
                                title: "E-file is coming soon",
                                message: "Electronic filing of your federal return goes through the IRS Modernized e-File system and requires an authorized provider. This is wired as a stub for now — your data stays on your device and is never transmitted."
                            )

                            // Acknowledgment checkbox (web <Checkbox> + label).
                            Button {
                                acknowledged.toggle()
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: acknowledged ? "checkmark.square.fill" : "square")
                                        .foregroundColor(acknowledged ? Theme.primary : Theme.mutedForeground)
                                        .padding(.top, 1)
                                    Text("I understand this is an estimate and want to continue.")
                                        .font(Theme.sans(Theme.FontSize.sm))
                                        .foregroundColor(Theme.mutedForeground)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)

                            // E-file submit.
                            FCButton(label: {
                                HStack(spacing: 8) {
                                    if isSubmitting {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(Theme.primaryForeground)
                                    } else {
                                        Image(systemName: "paperplane")
                                    }
                                    Text(isSubmitting ? "Submitting…" : "E-file")
                                }
                            }, action: submit)
                            .disabled(!acknowledged || isSubmitting)

                            efileOutcome
                        }
                    }
                }

                // The printable/shareable summary, rendered inline (web PrintableSummary).
                summaryCard
            }
            .padding(20)
        }
        .background(Theme.background)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [renderSummaryText()])
        }
    }

    // MARK: Headline

    private var headlineText: String {
        result.owes
            ? "Estimated balance due: \(CalcFormat.currency(abs(result.refundOrOwed), fraction: 0))"
            : "Estimated refund: \(CalcFormat.currency(result.refundOrOwed, fraction: 0))"
    }

    // MARK: E-file outcome

    @ViewBuilder
    private var efileOutcome: some View {
        if let error = efileError {
            AlertBox(
                destructive: true,
                systemImage: "exclamationmark.triangle",
                title: "Couldn't submit",
                message: error
            )
        } else if let r = efileResult {
            AlertBox(
                destructive: r.status == .rejected,
                systemImage: outcomeIcon(for: r.status),
                title: outcomeTitle(for: r.status),
                message: outcomeMessage(for: r)
            )
        }
    }

    private func outcomeIcon(for status: EfileSubmissionStatus) -> String {
        switch status {
        case .accepted, .queued: return "checkmark.circle"
        case .rejected:          return "exclamationmark.triangle"
        case .unsupported:       return "info.circle"
        }
    }

    private func outcomeTitle(for status: EfileSubmissionStatus) -> String {
        switch status {
        case .accepted:    return "Accepted"
        case .queued:      return "Queued"
        case .rejected:    return "Rejected"
        case .unsupported: return "E-file not available yet"
        }
    }

    private func outcomeMessage(for r: EfileResult) -> String {
        if let ref = r.providerRef, !ref.isEmpty {
            return "\(r.message) (reference \(ref))"
        }
        return r.message
    }

    // MARK: Submit

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        efileResult = nil
        efileError = nil
        let bundle = buildEfileBundle(result)
        Task {
            do {
                let res = try await EfileService.submit(bundle)
                await MainActor.run {
                    efileResult = res
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    efileError = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }

    // MARK: Printable summary (web PrintableSummary)

    private var summaryCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Your \(summary.taxYear) federal return")
                FCCardDescription("Filing status: \(summary.filingStatusLabel)")
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(summary.groups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.title)
                                .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                                .foregroundColor(Theme.foreground)
                            ForEach(Array(group.lines.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .firstTextBaseline) {
                                    (
                                        Text(line.label)
                                            .foregroundColor(Theme.mutedForeground)
                                        + Text(line.formRef.map { "  \($0)" } ?? "")
                                            .foregroundColor(Theme.mutedForeground.opacity(0.7))
                                    )
                                    .font(Theme.sans(Theme.FontSize.sm))
                                    Spacer()
                                    Text(CalcFormat.currency(line.amount))
                                        .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundColor(Theme.foreground)
                                }
                            }
                        }
                    }

                    Divider().background(Theme.border)

                    HStack(alignment: .firstTextBaseline) {
                        Text(summary.headline.label)
                            .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                            .foregroundColor(Theme.foreground)
                        Spacer()
                        Text(CalcFormat.currency(summary.headline.amount, fraction: 0))
                            .font(Theme.sans(Theme.FontSize.base, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(summary.headline.owes ? Theme.destructive : Theme.primary)
                    }

                    if let state = summary.state {
                        Divider().background(Theme.border)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(state.name)
                                .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                                .foregroundColor(Theme.foreground)
                            if state.hasIncomeTax {
                                summaryRow("State tax", CalcFormat.currency(state.tax))
                                summaryRow(
                                    state.refundOrOwed >= 0 ? "State refund" : "State balance due",
                                    CalcFormat.currency(abs(state.refundOrOwed))
                                )
                            } else if let note = state.note {
                                Text(note)
                                    .font(Theme.sans(Theme.FontSize.sm))
                                    .foregroundColor(Theme.mutedForeground)
                            }
                        }
                    }
                }
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.sans(Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
            Spacer()
            Text(value)
                .font(Theme.sans(Theme.FontSize.sm, weight: .medium))
                .monospacedDigit()
                .foregroundColor(Theme.foreground)
        }
    }

    // MARK: Plain-text rendering for the share sheet

    private func renderSummaryText() -> String {
        var lines: [String] = []
        lines.append("FinnaCalc — \(summary.taxYear) Federal Tax Estimate")
        lines.append("Filing status: \(summary.filingStatusLabel)")
        lines.append("")
        for group in summary.groups {
            lines.append(group.title.uppercased())
            for line in group.lines {
                let ref = line.formRef.map { " (\($0))" } ?? ""
                lines.append("  \(line.label)\(ref): \(CalcFormat.currency(line.amount))")
            }
            lines.append("")
        }
        lines.append("\(summary.headline.label): \(CalcFormat.currency(summary.headline.amount, fraction: 0))")
        if let state = summary.state {
            lines.append("")
            lines.append(state.name.uppercased())
            if state.hasIncomeTax {
                lines.append("  State tax: \(CalcFormat.currency(state.tax))")
                lines.append("  \(state.refundOrOwed >= 0 ? "State refund" : "State balance due"): \(CalcFormat.currency(abs(state.refundOrOwed)))")
            } else if let note = state.note {
                lines.append("  \(note)")
            }
        }
        lines.append("")
        lines.append("This is an estimate, not a filed return.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - AlertBox (web <Alert>)

/// Native equivalent of the web `<Alert>` (default + destructive variants): a
/// bordered, tinted box with a leading icon, optional title, and message.
private struct AlertBox: View {
    let destructive: Bool
    let systemImage: String
    let title: String?
    let message: String

    private var accent: Color { destructive ? Theme.destructive : Theme.foreground }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .foregroundColor(destructive ? Theme.destructive : Theme.foreground)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
                        .foregroundColor(destructive ? Theme.destructive : Theme.foreground)
                }
                Text(message)
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundColor(destructive ? Theme.destructive : Theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(destructive ? Theme.destructive.opacity(0.08) : Theme.muted.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(destructive ? Theme.destructive.opacity(0.5) : Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - ShareSheet

/// Thin `UIActivityViewController` wrapper for the "Save / share summary" action
/// (the iOS analogue of the web's `window.print()` / save-as-PDF).
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: 32) {
                ReviewScreen(vm: TaxEngineViewModel(), onEdit: { _ in }, onFile: {})
                FilingScreen(vm: TaxEngineViewModel(), onBack: {})
            }
        }
        .background(Theme.background)
    }
}
