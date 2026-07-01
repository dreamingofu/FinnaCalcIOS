//
//  FCTextField.swift
//  FinnaCalcIOS
//
//  Native port of `../FinnaCalc/components/ui/input.tsx`.
//
//      flex h-10 w-full rounded-md border border-input bg-background px-3 py-2
//      text-base ... placeholder:text-muted-foreground
//      focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2
//      disabled:cursor-not-allowed disabled:opacity-50
//
//  The web input is `text-base` on mobile (`md:text-sm` only kicks in at the
//  desktop breakpoint), so we use 16pt to match the phone rendering.
//

import SwiftUI

/// A single-line text field styled to match the web `<Input>`, including the
/// focus ring. Pass `isSecure: true` for password entry.
struct FCTextField: View {
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool
    private let keyboardType: UIKeyboardType

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // placeholder:text-muted-foreground — overlaid so we control the
            // exact color (SwiftUI's built-in placeholder ignores it).
            if text.isEmpty {
                Text(placeholder).foregroundStyle(Theme.mutedForeground)
            }
            field
        }
        .font(Theme.sans(Theme.FontSize.base)) // text-base (16)
        .foregroundStyle(Theme.foreground)
        .tint(Theme.primary)                      // caret color
        .keyboardType(keyboardType)
        .focused($isFocused)
        .frame(height: 40)                        // h-10
        .padding(.horizontal, 12)                 // px-3
        .frame(maxWidth: .infinity)               // w-full
        .background(Theme.background)             // bg-background
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.input, lineWidth: 1) // border border-input
        )
        .overlay(focusRing)
        .opacity(isEnabled ? 1 : 0.5)             // disabled:opacity-50
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField("", text: $text)
        } else {
            TextField("", text: $text)
        }
    }

    /// focus-visible:ring-2 ring-ring ring-offset-2 — a 2pt ring sitting 2pt
    /// outside the field, shown only while focused.
    @ViewBuilder
    private var focusRing: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: Theme.Radius.md + 2, style: .continuous)
                .stroke(Theme.ring, lineWidth: 2)
                .padding(-4) // 2pt offset gap + 2pt ring, drawn outside the border
        }
    }
}

// MARK: - Previews

#Preview("FCTextField — Light") {
    FCTextFieldGallery().preferredColorScheme(.light)
}

#Preview("FCTextField — Dark") {
    FCTextFieldGallery().preferredColorScheme(.dark)
}

private struct FCTextFieldGallery: View {
    @State private var email = ""
    @State private var password = ""
    @State private var amount = "1000"

    var body: some View {
        VStack(spacing: 20) {
            FCTextField("you@example.com", text: $email, keyboardType: .emailAddress)
            FCTextField("Password", text: $password, isSecure: true)
            FCTextField("Amount", text: $amount, keyboardType: .decimalPad)
            FCTextField("Disabled", text: .constant("")).disabled(true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }
}
