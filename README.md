# FinnaCalcIOS

Native SwiftUI port of [FinnaCalc](https://finnacalc.com) (the Next.js web app). The goal is feature and visual parity with the website, reusing the existing Next.js API rather than rebuilding any backend logic in Swift.

See [FinnaCalc-iOS-Port-Plan.md](FinnaCalc-iOS-Port-Plan.md) for the full phased build plan, design tokens, and API endpoint reference.

## Status

- **Phase 1 — Design system:** in progress. Reusable `FC*` components and design tokens live in [`Core/DesignSystem/`](Core/DesignSystem/).

## Getting started

1. Open the project in Xcode (SwiftUI app, iOS 16 deployment target).
2. Add the `Core/` group to the app target.
3. Open `DesignSystemGallery.swift` previews to review the components in light and dark mode.
