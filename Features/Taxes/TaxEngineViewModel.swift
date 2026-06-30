/**
 * TaxEngineViewModel.swift
 *
 * SwiftUI port of the FinnaCalc tax-engine React hooks
 * (components/tax-engine/hooks/useTaxEngine.ts + useLiveCalculation.ts).
 *
 * Mirrors the hook semantics 1:1:
 *   - `useReducer(reducer, {})` with SET / LOAD / RESET actions, where SET and
 *     LOAD funnel through `pruneHidden` -> the `setAnswer` / load-on-init paths.
 *   - `useMemo(() => buildReturn(answers))` -> `taxReturn`.
 *   - `useMemo(() => calculateFederalTax(taxReturn))` (the useLiveCalculation
 *     memo) -> `result`, recomputed whenever `answers` change.
 *   - localStorage hydrate-on-mount + persist-on-change to
 *     "finnacalc:taxReturn:2024:answers", redacting sensitive question ids.
 *
 * The pure engine (Engine/) is NOT modified — this only wraps it for SwiftUI.
 */

import Foundation
import Combine

@MainActor
final class TaxEngineViewModel: ObservableObject {

    // MARK: - Public published state

    /// TS: `answers` returned from `useReducer`. Mutated only through the
    /// reducer-equivalent paths (`setAnswer`, `reset`, load-on-init), so it is
    /// `private(set)` exactly like the hook never hands out a raw setter.
    @Published private(set) var answers: Answers

    /// TS: `result = useMemo(() => calculateFederalTax(taxReturn), [taxReturn])`
    /// (the `useLiveCalculation` memo). Recomputed whenever `answers` change.
    @Published private(set) var result: TaxCalculationResult

    // MARK: - Persistence constants (mirror useTaxEngine.ts)

    /// TS: `STORAGE_KEY`.
    private static let storageKey = "finnacalc:taxReturn:2024:answers"

    /// TS: `SENSITIVE_IDS = new Set(QUESTION_BANK.filter(q => q.sensitive).map(q => q.id))`.
    private static let sensitiveIDs: Set<String> = Set(
        QUESTION_BANK.filter { $0.sensitive == true }.map { $0.id }
    )

    /// Injectable store so this is testable; defaults to `.standard` like the
    /// hook's `window.localStorage`.
    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Start from `useReducer(reducer, {})` — an empty answers map.
        var initial: Answers = [:]

        // TS mount effect: hydrate from localStorage, dispatch LOAD on success.
        //   reducer LOAD: `pruneHidden({ ...state, ...action.answers })`
        // state is `{}` here, so this is `pruneHidden(loadedAnswers)`.
        if let loaded = Self.loadFromDefaults(defaults) {
            initial = pruneHidden(loaded)
        }

        self.answers = initial
        // TS: result = useMemo(() => calculateFederalTax(buildReturn(answers))).
        self.result = calculateFederalTax(buildReturn(initial))

        // TS persist effect runs after mount for the (possibly hydrated) state.
        // Writing the redacted hydrated answers back matches that effect firing.
        Self.persist(initial, to: defaults)
    }

    // MARK: - Reducer-equivalent mutations

    /// TS: `setAnswer(id, value)` -> `dispatch({ type: "SET", id, value })`.
    ///   reducer SET: `pruneHidden({ ...state, [id]: value })`.
    /// The `@Published answers` write drives the recompute + persist (the two
    /// `useEffect([answers])` / `useMemo([answers])` reactions).
    func setAnswer(_ id: String, _ value: AnswerValue) {
        var next = answers
        next[id] = value
        apply(pruneHidden(next))
    }

    /// TS: `reset()` -> `dispatch({ type: "RESET" })` (returns `{}`) then
    /// `localStorage.removeItem(STORAGE_KEY)`.
    func reset() {
        answers = [:]
        result = calculateFederalTax(buildReturn(answers))
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Shared tail for SET/LOAD: store the new answers, recompute the live
    /// result (`useMemo`), and persist redacted (`useEffect([answers])`).
    private func apply(_ next: Answers) {
        answers = next
        result = calculateFederalTax(buildReturn(next)) // useLiveCalculation
        Self.persist(next, to: defaults)
    }

    // MARK: - Derived values (useMemo equivalents)

    /// TS: `taxReturn = useMemo(() => buildReturn(answers), [answers])`.
    var taxReturn: TaxReturn2024 { buildReturn(answers) }

    /// Sections whose `dependsOn(answers)` is nil or true. Delegates to the
    /// engine's `getVisibleSections` (same filter).
    var visibleSections: [Section] { getVisibleSections(answers) }

    /// Visible questions within a section (section gate + own `dependsOn`).
    /// Delegates to the engine's `getQuestionsForSection`.
    func visibleQuestions(in section: Section) -> [Question] {
        getQuestionsForSection(section.id, answers)
    }

    // MARK: - Persistence helpers (mirror useTaxEngine.ts)

    /// TS: `redactForPersistence(answers)` — strip sensitive ids.
    private static func redactForPersistence(_ answers: Answers) -> Answers {
        var out: Answers = [:]
        for (k, v) in answers where !sensitiveIDs.contains(k) {
            out[k] = v
        }
        return out
    }

    /// TS persist effect: `localStorage.setItem(KEY, JSON.stringify(redacted))`,
    /// swallowing serialization/quota errors.
    private static func persist(_ answers: Answers, to defaults: UserDefaults) {
        let redacted = redactForPersistence(answers)
        let codable = redacted.mapValues { CodableAnswerValue($0) }
        do {
            let data = try JSONEncoder().encode(codable)
            defaults.set(data, forKey: storageKey)
        } catch {
            // ignore quota / serialization errors (matches the TS catch)
        }
    }

    /// TS mount effect read + `JSON.parse`, swallowing corrupt storage.
    private static func loadFromDefaults(_ defaults: UserDefaults) -> Answers? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        do {
            let decoded = try JSONDecoder().decode([String: CodableAnswerValue].self, from: data)
            return decoded.mapValues { $0.value }
        } catch {
            return nil // ignore corrupt storage
        }
    }
}

// MARK: - Codable bridge for AnswerValue

/// `AnswerValue` (TaxModels.swift) is not Codable because it is an untagged
/// mirror of TS `string | number | boolean`. This wrapper encodes it the same
/// way `JSON.stringify` does: a bare string, number, or boolean JSON value —
/// so the persisted shape is byte-compatible with the web app's localStorage.
private struct CodableAnswerValue: Codable {
    let value: AnswerValue

    init(_ value: AnswerValue) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        // Decode order matters: Bool must be tried before Double, since JSON
        // `true`/`false` would otherwise not match Double but a stray numeric
        // never matches Bool — so Bool-first is safe and correct.
        if let b = try? c.decode(Bool.self) {
            value = .boolean(b)
        } else if let d = try? c.decode(Double.self) {
            value = .number(d)
        } else if let s = try? c.decode(String.self) {
            value = .string(s)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "AnswerValue must be a string, number, or boolean"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case .string(let s): try c.encode(s)
        case .number(let d): try c.encode(d)
        case .boolean(let b): try c.encode(b)
        }
    }
}
