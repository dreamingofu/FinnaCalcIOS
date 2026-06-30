//
//  FCWordmark.swift
//  FinnaCalcIOS
//
//  The "Finna" + "Calc" wordmark from components/header.tsx, where "Calc" is
//  tinted with the brand blue (text-blue-600 / dark:text-blue-400 ≈ primary).
//

import SwiftUI

struct FCWordmark: View {
    var size: CGFloat = 20 // text-xl in the header

    var body: some View {
        (
            // `Text + Text` needs the Text-returning color modifier; the
            // foregroundStyle overload that returns Text is iOS 17+, so use
            // foregroundColor here to keep the iOS 16 deployment target.
            Text("Finna").foregroundColor(Theme.foreground) +
            Text("Calc").foregroundColor(Theme.primary)
        )
        .font(.system(size: size, weight: .bold))
    }
}

#Preview {
    VStack(spacing: 16) {
        FCWordmark()
        FCWordmark(size: 34)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
}
