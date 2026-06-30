//
//  BondsPageView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/components/bonds-page.tsx`.
//
//  The web component is a small informational placeholder: a back button, an
//  "Bonds" heading, and a single paragraph noting that content is forthcoming.
//  This port mirrors that content faithfully using the FinnaCalc design system.
//  The `onBack` prop is intentionally dropped — the Investing tab's
//  NavigationStack provides the Back affordance.
//

import SwiftUI

struct BondsPageView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // h1: text-2xl font-bold — "Bonds"
                Text("Bonds")
                    .font(.system(size: Theme.FontSize.xl2, weight: .bold))
                    .foregroundStyle(Theme.foreground)

                // p: "Content about bond investing will go here."
                FCCard {
                    FCCardContent {
                        Text("Content about bond investing will go here.")
                            .font(.system(size: Theme.FontSize.base))
                            .foregroundStyle(Theme.foreground)
                            .padding(.top, 24) // restore the header's top padding (content uses pt-0)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Bonds")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("BondsPageView — Light") {
    NavigationStack { BondsPageView() }
        .preferredColorScheme(.light)
}

#Preview("BondsPageView — Dark") {
    NavigationStack { BondsPageView() }
        .preferredColorScheme(.dark)
}
