//
//  BudgetAdvisorView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/components/budget-advisor.tsx`.
//
//  The AI Budget Advisor: builds a Codable budget snapshot, streams a
//  personalized analysis from `/api/budget-advisor`, supports quick/deep
//  presets plus free-form follow-ups, and renders the assistant's reply with a
//  lightweight Markdown view (headings, **bold**, bullets, numbered lists,
//  _italic_ footer). Auto-runs a "quick" analysis once on appear when there's
//  budget data.
//

import SwiftUI

// MARK: - Snapshot payload (mirrors the web `snapshot` object)

private struct AdvisorSnapshot: Encodable {
    struct ExpenseSlice: Encodable {
        let category: String
        let amount: Int
        let pctOfIncome: Double?
    }
    struct IncomeSlice: Encodable {
        let source: String
        let amount: Int
    }
    struct Goal: Encodable {
        let name: String
        let target: Double
        let saved: Double
        let monthlyContribution: Double
        let targetDate: String
        let pctComplete: Int
    }

    let budgetType: String
    let monthlyIncome: Int
    let monthlyExpenses: Int
    let monthlyNet: Int
    let savingsRatePct: Double
    let expenseByCategory: [ExpenseSlice]
    let incomeByCategory: [IncomeSlice]
    let savingsGoals: [Goal]
    let totalSavedAcrossGoals: Int
    let emergencyFundMonthsCovered: Double
}

private struct AdvisorMessageDTO: Encodable {
    let role: String
    let content: String
}

private struct AdvisorRequest: Encodable {
    let snapshot: AdvisorSnapshot
    let depth: String
    let messages: [AdvisorMessageDTO]
}

// MARK: - Local view model types

private enum AdvisorDepth: String {
    case quick, deep
}

private enum ChatRole: String {
    case user, assistant
}

private struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: ChatRole
    var content: String
}

// MARK: - BudgetAdvisorView

struct BudgetAdvisorView: View {
    @EnvironmentObject var store: BudgetStore

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isLoading = false
    @State private var depth: AdvisorDepth = .quick
    @State private var errorText: String?
    @State private var autoRan = false
    @State private var streamTask: Task<Void, Never>?

    // Web `blue-600` accent — the design system has no dedicated token, so map to primary.
    private let accentBlue = Theme.primary

    // MARK: Derived (mirrors the web component)

    private var monthlyIncome: Double { store.monthlyIncome }
    private var monthlyExpenses: Double { store.monthlyExpenses }
    private var monthlyNet: Double { store.monthlyNet }

    /// advisor uses net/income, NOT the Savings-category rate.
    private var savingsRate: Double {
        monthlyIncome > 0 ? (monthlyNet / monthlyIncome) * 100 : 0
    }
    private var totalSaved: Double {
        store.goals.reduce(0) { $0 + $1.currentAmount }
    }
    private var emergencyMonths: Double {
        monthlyExpenses > 0 ? totalSaved / monthlyExpenses : 0
    }
    private var topCategories: [CategorySlice] {
        Array(store.expenseByCategory.sorted { $0.value > $1.value }.prefix(3))
    }
    private var hasData: Bool { monthlyIncome > 0 || monthlyExpenses > 0 }

    /// JS Math.round (half toward +∞): floor(x + 0.5).
    private func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

    private var snapshot: AdvisorSnapshot {
        AdvisorSnapshot(
            budgetType: store.budgetType.rawValue,
            monthlyIncome: Int(jsRound(monthlyIncome)),
            monthlyExpenses: Int(jsRound(monthlyExpenses)),
            monthlyNet: Int(jsRound(monthlyNet)),
            savingsRatePct: jsRound(savingsRate * 10) / 10,
            expenseByCategory: store.expenseByCategory.map { c in
                AdvisorSnapshot.ExpenseSlice(
                    category: c.name,
                    amount: Int(jsRound(c.value)),
                    pctOfIncome: monthlyIncome > 0 ? jsRound((c.value / monthlyIncome) * 1000) / 10 : nil
                )
            },
            incomeByCategory: store.incomeByCategory.map { c in
                AdvisorSnapshot.IncomeSlice(source: c.name, amount: Int(jsRound(c.value)))
            },
            savingsGoals: store.goals.map { g in
                AdvisorSnapshot.Goal(
                    name: g.name,
                    target: g.targetAmount,
                    saved: g.currentAmount,
                    monthlyContribution: g.monthlyContribution,
                    targetDate: g.targetDate,
                    pctComplete: g.targetAmount > 0 ? Int(jsRound((g.currentAmount / g.targetAmount) * 100)) : 0
                )
            },
            totalSavedAcrossGoals: Int(jsRound(totalSaved)),
            emergencyFundMonthsCovered: jsRound(emergencyMonths * 10) / 10
        )
    }

    // Hide the seed "analyze" user message (first user message) for a cleaner look.
    private var visibleMessages: [ChatMessage] {
        guard let first = messages.first, first.role == .user else { return messages }
        return Array(messages.dropFirst())
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 24) {
            snapshotCard
            if !messages.isEmpty || isLoading {
                conversationCard
            }
        }
        .onAppear {
            if !autoRan && hasData {
                autoRan = true
                runAnalysis(.quick)
            }
        }
    }

    // MARK: Snapshot card

    private var snapshotCard: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .fill(accentBlue)
                                .frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(Theme.sans(16))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Budget Analysis")
                                .font(Theme.sans(18, weight: .semibold))
                                .foregroundColor(Theme.cardForeground)
                            Text("Personalized insights for your \(store.budgetType.rawValue) budget")
                                .font(Theme.sans(Theme.FontSize.xs))
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                    Spacer()
                    if hasData {
                        FCButton(size: .sm, label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Deep Analysis")
                            }
                        }, action: { runAnalysis(.deep) })
                        .disabled(isLoading)
                    }
                }
                .padding(.bottom, 12)

                Divider().background(Theme.border)
                    .padding(.bottom, 16)

                if !hasData {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(Theme.sans(40))
                            .foregroundColor(Theme.mutedForeground)
                        Text("Add some income and expenses in the Budget tab, then come back for a personalized analysis.")
                            .font(Theme.sans(Theme.FontSize.sm))
                            .foregroundColor(Theme.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    topExpenseLine
                }
            }
        }
    }

    private var topExpenseLine: some View {
        let top = topCategories.first
        var text = Text("Top expense: ")
            .foregroundColor(Theme.mutedForeground)
        text = text + Text(top?.name ?? "—")
            .font(Theme.sans(Theme.FontSize.sm, weight: .semibold))
            .foregroundColor(Theme.foreground)
        if let top {
            text = text + Text(" · \(CalcFormat.currency(top.value, fraction: 0))/mo")
                .foregroundColor(Theme.mutedForeground)
        }
        return text
            .font(Theme.sans(Theme.FontSize.sm))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Conversation card

    private var conversationCard: some View {
        FCCard {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(visibleMessages) { m in
                                messageView(m)
                                    .id(m.id)
                            }
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(depth == .deep ? "Running a deep analysis…" : "Analyzing your budget…")
                                        .font(Theme.sans(Theme.FontSize.sm))
                                        .foregroundColor(Theme.mutedForeground)
                                }
                                .id("loading")
                            }
                            if let errorText {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(Theme.sans(14))
                                        .foregroundColor(Theme.destructive)
                                    Text(errorText)
                                        .font(Theme.sans(Theme.FontSize.xs))
                                        .foregroundColor(Theme.destructive)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.destructive.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                                        .stroke(Theme.destructive.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(Theme.Radius.md)
                                .id("error")
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 640)
                    .onChange(of: messages) { _ in scrollToBottom(proxy) }
                    .onChange(of: isLoading) { _ in scrollToBottom(proxy) }
                }

                Divider().background(Theme.border)

                HStack(spacing: 8) {
                    FCTextField(
                        "Ask a follow-up — e.g. how do I free up $300/month?",
                        text: $input
                    )
                    .disabled(isLoading)
                    .onSubmit { send() }

                    FCButton(size: .icon, label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                    }, action: { send() })
                    .disabled(isLoading || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func messageView(_ m: ChatMessage) -> some View {
        if m.role == .assistant {
            MarkdownText(text: m.content)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Spacer(minLength: 0)
                Text(m.content)
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(accentBlue)
                    .clipShape(BubbleShape())
                    .frame(maxWidth: 300, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.15)) {
                if isLoading {
                    proxy.scrollTo("loading", anchor: .bottom)
                } else if let last = visibleMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: Actions

    private func runAnalysis(_ d: AdvisorDepth) {
        guard !isLoading else { return }
        depth = d
        let seed = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: d == .deep
                ? "Give me a full, deep analysis of my budget with your best personalized recommendations."
                : "Give me a quick, concise summary of my budget with the top quick wins."
        )
        messages = [seed]
        stream(history: [seed], depth: d)
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }
        let next = messages + [ChatMessage(id: UUID().uuidString, role: .user, content: trimmed)]
        messages = next
        input = ""
        stream(history: next, depth: depth)
    }

    private func stream(history: [ChatMessage], depth d: AdvisorDepth) {
        streamTask?.cancel()
        isLoading = true
        errorText = nil
        let assistantId = UUID().uuidString

        let request = AdvisorRequest(
            snapshot: snapshot,
            depth: d.rawValue,
            messages: history.map { AdvisorMessageDTO(role: $0.role.rawValue, content: $0.content) }
        )

        streamTask = Task { @MainActor in
            var appended = false
            var acc = ""
            do {
                let stream = APIClient.shared.postTextStream("/api/budget-advisor", body: request)
                for try await text in stream {
                    acc = text
                    if !appended {
                        messages.append(ChatMessage(id: assistantId, role: .assistant, content: acc))
                        appended = true
                    } else if let i = messages.firstIndex(where: { $0.id == assistantId }) {
                        messages[i].content = acc
                    }
                }
                if acc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messages.removeAll { $0.id == assistantId }
                    errorText = "No response received. Please try again."
                }
            } catch is CancellationError {
                messages.removeAll { $0.id == assistantId }
            } catch {
                messages.removeAll { $0.id == assistantId }
                errorText = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
            }
            isLoading = false
        }
    }
}

// MARK: - Right-aligned chat bubble shape

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        // rounded-2xl with a flattened bottom-right corner (rounded-br-sm).
        let big: CGFloat = 16
        let small: CGFloat = 4
        return Path(
            roundedCornersPath(rect: rect, topLeft: big, topRight: big, bottomRight: small, bottomLeft: big)
        )
    }
}

private func roundedCornersPath(rect: CGRect, topLeft: CGFloat, topRight: CGFloat, bottomRight: CGFloat, bottomLeft: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let minX = rect.minX, minY = rect.minY, maxX = rect.maxX, maxY = rect.maxY
    path.move(to: CGPoint(x: minX + topLeft, y: minY))
    path.addLine(to: CGPoint(x: maxX - topRight, y: minY))
    path.addArc(tangent1End: CGPoint(x: maxX, y: minY), tangent2End: CGPoint(x: maxX, y: minY + topRight), radius: topRight)
    path.addLine(to: CGPoint(x: maxX, y: maxY - bottomRight))
    path.addArc(tangent1End: CGPoint(x: maxX, y: maxY), tangent2End: CGPoint(x: maxX - bottomRight, y: maxY), radius: bottomRight)
    path.addLine(to: CGPoint(x: minX + bottomLeft, y: maxY))
    path.addArc(tangent1End: CGPoint(x: minX, y: maxY), tangent2End: CGPoint(x: minX, y: maxY - bottomLeft), radius: bottomLeft)
    path.addLine(to: CGPoint(x: minX, y: minY + topLeft))
    path.addArc(tangent1End: CGPoint(x: minX, y: minY), tangent2End: CGPoint(x: minX + topLeft, y: minY), radius: topLeft)
    path.closeSubpath()
    return path
}

// MARK: - Lightweight Markdown renderer

/// Ports the web `Markdown` component: ## / ### headings, **bold**, "- "/"* "
/// bullets, "1." numbered lists, and a trailing _italic_ footer line.
private struct MarkdownText: View {
    let text: String

    private enum Block: Identifiable {
        case heading(id: Int, level: Int, text: String)
        case paragraph(id: Int, text: String)
        case italic(id: Int, text: String)
        case list(id: Int, ordered: Bool, items: [String])

        var id: Int {
            switch self {
            case .heading(let id, _, _), .paragraph(let id, _),
                 .italic(let id, _), .list(let id, _, _):
                return id
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parse()) { block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case let .heading(_, level, text):
            inline(text)
                .font(Theme.sans(level <= 2 ? Theme.FontSize.base : Theme.FontSize.sm,
                              weight: level <= 2 ? .bold : .semibold))
                .padding(.top, level <= 2 ? 10 : 8)
                .padding(.bottom, 2)
        case let .paragraph(_, text):
            inline(text)
                .font(Theme.sans(Theme.FontSize.sm))
                .foregroundColor(Theme.cardForeground)
                .lineSpacing(3)
                .padding(.vertical, 2)
        case let .italic(_, text):
            inline(text)
                .font(Theme.sans(Theme.FontSize.xs).italic())
                .foregroundColor(Theme.mutedForeground)
                .padding(.top, 8)
        case let .list(_, ordered, items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(ordered ? "\(idx + 1)." : "•")
                            .font(Theme.sans(Theme.FontSize.sm))
                            .foregroundColor(Theme.cardForeground)
                        inline(item)
                            .font(Theme.sans(Theme.FontSize.sm))
                            .foregroundColor(Theme.cardForeground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.leading, 4)
        }
    }

    // Inline **bold** rendering using Text concatenation.
    private func inline(_ raw: String) -> Text {
        let parts = raw.components(separatedBy: "**")
        var result = Text("")
        for (i, part) in parts.enumerated() {
            // Odd indices are inside ** ** → bold. Strip stray single * from plain runs.
            if i % 2 == 1 {
                result = result + Text(part).bold()
            } else {
                result = result + Text(part.replacingOccurrences(of: "*", with: ""))
            }
        }
        return result
    }

    private func parse() -> [Block] {
        var blocks: [Block] = []
        var pendingItems: [String] = []
        var pendingOrdered = false
        var hasPending = false
        var counter = 0
        func nextID() -> Int { counter += 1; return counter }

        func flushList() {
            guard hasPending else { return }
            blocks.append(.list(id: nextID(), ordered: pendingOrdered, items: pendingItems))
            pendingItems = []
            hasPending = false
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
            if line.isEmpty {
                flushList()
                continue
            }
            // Heading: #{1,4} text
            if let h = matchHeading(line) {
                flushList()
                blocks.append(.heading(id: nextID(), level: h.level, text: h.text))
                continue
            }
            // Ordered list: leading digits then . or )
            if let item = matchOrdered(line) {
                if !hasPending || !pendingOrdered {
                    flushList()
                    pendingOrdered = true
                    hasPending = true
                }
                pendingItems.append(item)
                continue
            }
            // Unordered list: -, *, •
            if let item = matchUnordered(line) {
                if !hasPending || pendingOrdered {
                    flushList()
                    pendingOrdered = false
                    hasPending = true
                }
                pendingItems.append(item)
                continue
            }
            flushList()
            // Italic footer: _text_ or *text*
            if let em = matchItalic(line) {
                blocks.append(.italic(id: nextID(), text: em))
                continue
            }
            blocks.append(.paragraph(id: nextID(), text: line))
        }
        flushList()
        return blocks
    }

    private func matchHeading(_ line: String) -> (level: Int, text: String)? {
        var hashes = 0
        for ch in line {
            if ch == "#" { hashes += 1 } else { break }
        }
        guard hashes >= 1, hashes <= 4 else { return nil }
        let rest = line.dropFirst(hashes)
        guard let firstAfter = rest.first, firstAfter == " " || firstAfter == "\t" else { return nil }
        return (hashes, String(rest).trimmingCharacters(in: .whitespaces))
    }

    private func matchOrdered(_ line: String) -> String? {
        var idx = line.startIndex
        var digits = 0
        while idx < line.endIndex, line[idx].isNumber {
            digits += 1
            idx = line.index(after: idx)
        }
        guard digits > 0, idx < line.endIndex, line[idx] == "." || line[idx] == ")" else { return nil }
        idx = line.index(after: idx)
        guard idx < line.endIndex, line[idx] == " " else { return nil }
        return String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
    }

    private func matchUnordered(_ line: String) -> String? {
        guard let first = line.first, first == "-" || first == "*" || first == "•" else { return nil }
        let rest = line.dropFirst()
        guard let second = rest.first, second == " " else { return nil }
        return String(rest).trimmingCharacters(in: .whitespaces)
    }

    private func matchItalic(_ line: String) -> String? {
        if line.count >= 2, line.hasPrefix("_"), line.hasSuffix("_") {
            return String(line.dropFirst().dropLast())
        }
        if line.count >= 2, line.hasPrefix("*"), line.hasSuffix("*"), !line.hasPrefix("**") {
            return String(line.dropFirst().dropLast())
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    let store: BudgetStore = {
        let s = BudgetStore()
        s.items = [
            BudgetItem(id: "1", category: "Salary", subcategory: "Job", amount: 5000, frequency: .monthly, type: .income, isFixed: true, budgetType: .personal, importDate: nil),
            BudgetItem(id: "2", category: "Housing", subcategory: "Rent", amount: 1800, frequency: .monthly, type: .expense, isFixed: true, budgetType: .personal, importDate: nil),
            BudgetItem(id: "3", category: "Food", subcategory: "Groceries", amount: 600, frequency: .monthly, type: .expense, isFixed: false, budgetType: .personal, importDate: nil),
        ]
        s.goals = [
            SavingsGoal(id: "g1", name: "Emergency Fund", targetAmount: 10000, currentAmount: 4000, targetDate: "2026-12-31", monthlyContribution: 500),
        ]
        return s
    }()

    return ScrollView {
        BudgetAdvisorView()
            .environmentObject(store)
            .padding()
    }
    .background(Theme.background)
}
