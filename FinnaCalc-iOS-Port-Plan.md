# FinnaCalc → iOS (Swift / SwiftUI) — Port Plan

This is a working plan for porting FinnaCalc (Next.js, `Big5Buda/FinnaCalc`) into a native iOS app with the same features, screens, and branding. It's based on a direct read of the live repo — actual routes, API handlers, auth code, and design tokens — not generic web-to-iOS advice.

## How to actually use this with Claude Code

Save this file inside the new iOS project's repo (e.g. `FinnaCalcIOS/PLAN.md`), and make sure your local FinnaCalc clone is reachable from the same machine — same parent folder is easiest. Claude Code can read files directly, so you don't need to copy-paste big prompt blocks. A session start looks like:

> "Read PLAN.md. Reference the FinnaCalc repo at `../FinnaCalc` for exact UI and logic when porting. We're doing Phase 3 only right now — don't start on later phases."

That's enough — Claude Code pulls whatever detail it needs from this doc and from the real source files. The phase prompts below are just a starting line for each session, not the full spec.

**The one rule that matters most: one phase per session.** Nine phases of a fintech app with three external integrations is not a one-shot job. Asking for all of it at once is the most reliable way to get something that half-works everywhere instead of something that fully works in pieces.

## Architecture

Both the iOS app and the existing website call the same Next.js API on Vercel — nothing on the backend gets rewritten in Swift. The iOS app is a second client, not a replacement.

Why: `components/tax-engine/` alone is ~450KB of calculation logic, plus the e-file flow, Plaid, SnapTrade, and Gemini access all already exist as working server routes. Re-implementing any of that in Swift means maintaining two versions of the same business logic, which is the easiest way to have them quietly drift apart. The website keeps working exactly as it does today.

What "exact carbon copy" means in practice — three places it can't be literal:
- SnapTrade's connection flow is a hosted web portal (see Phase 5) — it opens in `SFSafariViewController`, not a fully native screen.
- The TradingView widgets (`tradingview-chart.tsx`, `-mini.tsx`, `-news.tsx`) are embeddable JS widgets with no free native iOS SDK. Plan A for v1 is wrapping the same widgets in `WKWebView`; native Swift Charts replacements are a later nice-to-have, not a blocker.
- Hover states, browser-style modals, and anything that assumes a mouse get native equivalents (sheets, tap targets) — same content and intent, native interaction.

## Phase 0 — Backend readiness (recommended, do first)

Two things stood out reading the actual route handlers, both of which matter once there are two clients (web + iOS) instead of one:

1. **No request-level auth check.** `/api/plaid/*`, `/api/snaptrade/*`, `/api/budget-advisor` don't verify a Supabase session — they trust whatever body they're sent. Add a helper that reads `Authorization: Bearer <token>`, calls `supabase.auth.getUser(token)`, and rejects on failure. Keep the web app on cookies; have the iOS app send this header instead.
2. **SnapTrade identity lives in a cookie, not your user table.** `lib/snaptrade.ts` stores `{ userId, userSecret }` in an httpOnly cookie — the code comment already calls this a stopgap. Move it to a Supabase table keyed by `auth.uid()` (e.g. `user_snaptrade_credentials`), and do the same for Plaid — there's currently no persisted `access_token` at all; `/api/plaid/transactions` re-exchanges a fresh `public_token` every time rather than reusing a stored token.

Skip this if you're fine with the iOS app and the website registering as separate identities with Plaid/SnapTrade for now — just know that's the tradeoff. This is regular backend work in the existing Next.js repo; it doesn't touch Swift at all.

**Session start:** "Read the Phase 0 section of PLAN.md. Add Bearer-token auth verification to the API routes listed, then move SnapTrade and Plaid credentials from cookie/re-exchange into Supabase tables keyed by the user's id."

## Backend endpoint reference

All 14 existing routes the iOS app will call, unchanged:

| Endpoint | Purpose | Used in phase |
|---|---|---|
| `POST /api/plaid/create-link-token` | Starts a Plaid Link session | 4 |
| `POST /api/plaid/transactions` | Bank transactions (90 days) | 4 |
| `POST /api/plaid/holdings` | Investment holdings via Plaid | 4 |
| `POST /api/plaid/liabilities` | Loans/credit liabilities | 4 |
| `POST /api/snaptrade/connect` | Generates brokerage connection portal URL | 5 |
| `GET /api/snaptrade/accounts` | Connected brokerage accounts | 5 |
| `POST /api/snaptrade/disconnect` | Unlinks a brokerage | 5 |
| `GET /api/stock` | Single stock quote | 5 |
| `GET /api/stock-search` | Ticker search/autocomplete | 5 |
| `GET /api/screener` | Stock screener results | 5 |
| `GET /api/top-movers` | Market top movers | 5 |
| `GET /api/market-overview` | Market summary data | 5 |
| `POST /api/budget-advisor` | AI budget recommendations | 4 |
| `POST /api/chat` | FinnaBot (Gemini, plain UTF-8 text stream — no SSE/data-stream parsing needed) | 7 |
| `POST /api/efile` | Tax e-file submission | 6 |

## Phase 1 — Xcode project + design system

**You do this part** (Claude Code can't drive the Xcode GUI):
- Apple Developer Program enrollment if not already done — needed for Associated Domains and Sign in with Apple to behave correctly, not just simulator testing.
- Xcode → New Project → iOS → App → SwiftUI interface, Swift. Deployment target iOS 16 (gets you Swift Charts and current SwiftUI without losing meaningful device coverage).
- Add two Swift packages (File → Add Package Dependencies): `https://github.com/supabase/supabase-swift` and `https://github.com/plaid/plaid-link-ios-spm.git`.
- Signing & Capabilities → add Sign in with Apple, and Associated Domains (`applinks:finnacalc.com`).
- On the web side (or via Claude Code in the FinnaCalc repo): publish `https://finnacalc.com/.well-known/apple-app-site-association`, required for Plaid's OAuth bank redirects to work on iOS.

Exact color tokens, pulled from `app/globals.css` (HSL, as written in the CSS):

| Token | Light | Dark |
|---|---|---|
| background | 0 0% 100% | 222.2 84% 4.9% |
| foreground | 222.2 84% 4.9% | 210 40% 98% |
| card / popover | 0 0% 100% | 222.2 84% 4.9% |
| primary | 221.2 83.2% 53.3% | 217.2 91.2% 59.8% |
| secondary / muted / accent | 210 40% 96% | 217.2 32.6% 17.5% |
| destructive | 0 84.2% 60.2% | 0 62.8% 30.6% |
| border / input | 214.3 31.8% 91.4% | 217.2 32.6% 17.5% |
| ring | 221.2 83.2% 53.3% | 224.3 76.3% 48% |
| radius | 0.75rem (12pt) | — |

A starting point for the color extension, so the values plug in directly instead of needing a hex conversion pass:

```swift
extension Color {
    init(h: Double, s: Double, l: Double) {
        let s = s / 100, l = l / 100
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r, g, b): (Double, Double, Double) =
            h < 60  ? (c, x, 0) : h < 120 ? (x, c, 0) : h < 180 ? (0, c, x) :
            h < 240 ? (0, x, c) : h < 300 ? (x, 0, c) : (c, 0, x)
        self.init(red: r + m, green: g + m, blue: b + m)
    }
}
```

**Session start:** "Read the Phase 1 section of PLAN.md. Build `Theme.swift` with light/dark palettes using the HSL table and the `Color(h:s:l:)` extension given. Then build `FCButton` (primary/secondary/destructive/ghost), `FCCard`, `FCTextField`, and `FCBadge`, matching the variants in `../FinnaCalc/components/ui`."

## Phase 2 — Auth + navigation shell

Port `lib/auth.tsx` into an `AuthManager: ObservableObject` wrapping `supabase-swift`: email/password sign in/up, native Apple sign-in via `AuthenticationServices` → `signInWithIdToken`, native Google sign-in (add `GoogleSignIn-iOS` if you want this on day one, or stub it and add later), sign out, and session restore on launch. Port `components/header.tsx`'s navigation structure into a `TabView` or `NavigationSplitView` shell.

**Session start:** "Implement Phase 2 from PLAN.md. Reference `../FinnaCalc/lib/auth.tsx` and `../FinnaCalc/components/header.tsx` for the exact auth methods and nav structure to mirror."

## Phase 3 — Standalone calculators (good first wins)

No backend calls, no third-party SDKs — just UI + pure calculation logic. Good place to validate the design system before anything harder:

`loan-calculator`, `roi-calculator`, `break-even-calculator`, `profit-margin-calculator`, `startup-cost-calculator`, `pricing-calculator`, `cash-flow-calculator`, `emergency-fund-calculator`, `employee-contractor-calculator`.

**Session start:** "Implement Phase 3 from PLAN.md, one calculator at a time, starting with loan-calculator. Port the calculation logic and form layout from `../FinnaCalc/app/loan-calculator` exactly."

## Phase 4 — Budgeting + Plaid

`bank-connect.tsx` → LinkKit's `.plaidLink(isPresented:token:onSuccess:onExit:)` SwiftUI modifier, fed by `/api/plaid/create-link-token`. `debt-card.tsx` and `budget-advisor.tsx` → native views calling `/api/plaid/holdings`, `/api/plaid/liabilities`, `/api/budget-advisor`. Covers everything under `app/budgeting`.

**Session start:** "Implement Phase 4 from PLAN.md. Reference `../FinnaCalc/components/bank-connect.tsx`, `debt-card.tsx`, and `budget-advisor.tsx`. Use the Plaid LinkKit SwiftUI modifier, not the older Handler-based API."

## Phase 5 — Investing, SnapTrade, and market data

`brokerage-connect.tsx` → open the URL from `/api/snaptrade/connect` in `SFSafariViewController`, with a custom URL scheme (e.g. `finnacalc://snaptrade-callback`) as the redirect target, registered as a URL Type in Info.plist and handled via `.onOpenURL`. Then `/api/snaptrade/accounts` and `/api/snaptrade/disconnect`.

`stocks-page.tsx`, `bonds-page.tsx`, `safe-investment-options.tsx`, `investing-options.tsx`, `investment-education.tsx` → views over `/api/stock`, `/api/stock-search`, `/api/screener`, `/api/top-movers`, `/api/market-overview`. `markets-dashboard.tsx`, `dashboard-screener.tsx`, `dashboard-watchlist.tsx` → Swift Charts for anything currently in `recharts`.

`tradingview-chart.tsx`, `-mini.tsx`, `-news.tsx` → wrap the same widget URLs in a thin `WKWebView` SwiftUI representable for v1 (see the carbon-copy caveats above).

**Session start:** "Implement Phase 5 from PLAN.md. Start with `brokerage-connect.tsx`'s SnapTrade flow using SFSafariViewController and a custom URL scheme, then move to the market data views."

## Phase 6 — Taxes

The largest and riskiest single phase: `tax-calculator` route, `taxes` route, `tax-calculators.tsx`, `tax-education.tsx`, `tax-filing-interface.tsx`, all of `components/tax-engine/` (~450KB), and `/api/efile`. Treat this as its own multi-session effort.

**Session start:** "Don't write any Swift yet. Read through `../FinnaCalc/components/tax-engine` and produce an inventory of its calculation modules and how they depend on each other, so we can port it module by module instead of all at once."

## Phase 7 — FinnaBot chat

Port `Chatbot.tsx` into a SwiftUI chat view calling `/api/chat`. The endpoint returns a plain UTF-8 text stream — `URLSession.bytes(for:)` and appending chunks as they arrive is enough; there's no SSE or versioned data-stream protocol to parse.

**Session start:** "Implement Phase 7 from PLAN.md. Reference `../FinnaCalc/components/Chatbot.tsx`. Stream `/api/chat`'s response with `URLSession.bytes(for:)`, appending raw text chunks to the active message as they arrive."

## Phase 8 — Remaining pages + polish

`about`, `advising`, `education` (`financial-education-hub.tsx`), `premium`, `pricing-calculator`, `sign-in`/`sign-up` forms, `privacy`, `terms`. Then: app icon from the existing logo assets in `public/`, launch screen, a dark-mode pass (the tokens already support it), accessibility (VoiceOver labels, Dynamic Type), and TestFlight.

## Suggested project structure

```
FinnaCalcIOS/
  App/                    entry point, root navigation
  Core/
    Networking/           APIClient, endpoint definitions, auth header injection
    Auth/                 AuthManager (wraps supabase-swift)
    DesignSystem/         Theme.swift, FCButton, FCCard, FCTextField, FCBadge
  Features/
    Calculators/
    Budgeting/
    Investing/
    Taxes/
    Chat/
  Models/                 Codable structs matching the API's JSON shapes
```

## Suggested order

Phase 0 and 1 first — auth and the design system are the foundation everything else sits on. After that, Phase 3 (calculators) is the fastest way to get something real running and confirm the design system reads correctly before tackling Plaid, SnapTrade, or the tax engine. Phase 6 (taxes) is worth saving for when the rest of the app's patterns are already established, since it's the biggest single chunk of logic to port faithfully.
