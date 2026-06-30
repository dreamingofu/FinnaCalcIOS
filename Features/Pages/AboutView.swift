//
//  AboutView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/app/about/page.tsx`.
//  The About page: a hero statement, Mission & Vision cards, "What We Offer",
//  "Our Core Values", "Why Choose FinnaCalc?", and a "Get in Touch" contact
//  block. Content is ported faithfully from the web reference.
//
//  Web uses a responsive grid (1/2/3/4 columns); on a phone everything stacks
//  vertically, which is the natural single-column collapse of those grids.
//  The lucide brand-color icons (blue/red/green/purple/orange) are approximated
//  with hue-matched colors, mirroring the web's per-icon tint.
//

import SwiftUI

struct AboutView: View {

    // MARK: - Approximated lucide brand-icon hues

    private enum IconColor {
        static let blue   = Color(h: 217, s: 91, l: 60)  // text-blue-600
        static let red    = Color(h: 0,   s: 72, l: 51)  // text-red-600
        static let green  = Color(h: 142, s: 71, l: 45)  // text-green-600
        static let purple = Color(h: 271, s: 81, l: 56)  // text-purple-600
        static let orange = Color(h: 25,  s: 95, l: 53)  // text-orange-600
    }

    // MARK: - Models

    private struct OfferItem: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let title: String
        let body: String
    }

    private struct ValueItem: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let title: String
        let body: String
    }

    private struct ReasonItem: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    private let offerItems: [OfferItem] = [
        OfferItem(
            icon: "function",
            tint: IconColor.green,
            title: "Business Calculators",
            body: "Startup costs, break-even analysis, ROI calculations, cash flow projections, and pricing strategies to help businesses plan and grow."
        ),
        OfferItem(
            icon: "person.2.fill",
            tint: IconColor.purple,
            title: "Personal Finance",
            body: "Tax calculators, loan analyzers, investment tools, and budgeting calculators designed for individuals and families."
        ),
        OfferItem(
            icon: "shield.fill",
            tint: IconColor.blue,
            title: "Professional Grade",
            body: "All calculations are based on current financial formulas and regulations, ensuring accuracy and reliability for professional use."
        ),
    ]

    private let valueItems: [ValueItem] = [
        ValueItem(
            icon: "shield.fill",
            tint: IconColor.blue,
            title: "Accuracy",
            body: "Every calculation is thoroughly tested and based on current financial standards and regulations."
        ),
        ValueItem(
            icon: "heart.fill",
            tint: IconColor.green,
            title: "Accessibility",
            body: "Financial planning tools should be available to everyone, regardless of their economic background."
        ),
        ValueItem(
            icon: "person.2.fill",
            tint: IconColor.purple,
            title: "Simplicity",
            body: "Complex financial concepts made simple and understandable for users of all experience levels."
        ),
        ValueItem(
            icon: "rosette",
            tint: IconColor.orange,
            title: "Excellence",
            body: "Continuous improvement and innovation to provide the best possible user experience."
        ),
    ]

    private let reasonItems: [ReasonItem] = [
        ReasonItem(
            title: "Free & Accessible",
            body: "All basic calculations and personal finance tools are completely free to use. No hidden fees, no subscriptions, no barriers to financial planning."
        ),
        ReasonItem(
            title: "Professional Quality",
            body: "Our calculators use the same formulas and methodologies employed by financial professionals and institutions worldwide."
        ),
        ReasonItem(
            title: "User-Friendly Design",
            body: "Clean, intuitive interfaces that make complex financial calculations simple and straightforward for everyone to use."
        ),
        ReasonItem(
            title: "Constantly Updated",
            body: "We regularly update our calculators to reflect current tax rates, interest rates, and financial regulations."
        ),
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) { // space-y-12
                hero
                missionVision
                whatWeOffer
                coreValues
                whyChoose
                getInTouch
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.muted.opacity(0.4)) // bg-muted/40
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 16) {
            Text("Empowering Smart Financial Decisions")
                .font(.system(size: 32, weight: .bold)) // text-4xl
                .foregroundColor(Theme.foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("FinnaCalc is your trusted partner in financial planning, providing professional-grade calculators and planning tools to help individuals and businesses make informed financial decisions.")
                .font(.system(size: Theme.FontSize.xl2 * 0.83)) // ~text-xl (20pt)
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mission & Vision

    private var missionVision: some View {
        VStack(spacing: 24) { // gap-8 (stacks on phone)
            statementCard(
                icon: "target",
                tint: IconColor.blue,
                title: "Our Mission",
                body: "To democratize financial planning by providing free, accurate, and easy-to-use financial calculators and personal finance tools that empower everyone to make better financial decisions, regardless of their background or experience level."
            )
            statementCard(
                icon: "heart.fill",
                tint: IconColor.red,
                title: "Our Vision",
                body: "To become the world's most trusted platform for financial calculations and personal finance planning tools, helping millions of people achieve their financial goals through informed decision-making."
            )
        }
    }

    private func statementCard(icon: String, tint: Color, title: String, body: String) -> some View {
        FCCard {
            FCCardHeader {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(tint)
                    Text(title)
                        .font(.system(size: Theme.FontSize.xl2, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundColor(Theme.cardForeground)
                }
            }
            FCCardContent {
                Text(body)
                    .font(.system(size: Theme.FontSize.base))
                    .foregroundColor(Theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - What We Offer

    private var whatWeOffer: some View {
        VStack(spacing: 32) { // space-y-8
            VStack(spacing: 16) {
                Text("What We Offer")
                    .font(.system(size: 28, weight: .bold)) // text-3xl
                    .foregroundColor(Theme.foreground)
                    .multilineTextAlignment(.center)
                Text("Comprehensive financial tools designed for real-world applications")
                    .font(.system(size: 18)) // text-lg
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 24) { // gap-6 (stacks on phone)
                ForEach(offerItems) { item in
                    offerCard(item)
                }
            }
        }
    }

    private func offerCard(_ item: OfferItem) -> some View {
        FCCard {
            FCCardHeader {
                HStack(spacing: 8) {
                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundColor(item.tint)
                    Text(item.title)
                        .font(.system(size: Theme.FontSize.xl2, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundColor(Theme.cardForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FCCardContent {
                Text(item.body)
                    .font(.system(size: Theme.FontSize.base))
                    .foregroundColor(Theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Our Core Values

    private var coreValues: some View {
        VStack(spacing: 32) { // space-y-8
            Text("Our Core Values")
                .font(.system(size: 28, weight: .bold)) // text-3xl
                .foregroundColor(Theme.foreground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            VStack(spacing: 24) { // gap-6 (stacks on phone)
                ForEach(valueItems) { item in
                    valueRow(item)
                }
            }
        }
    }

    private func valueRow(_ item: ValueItem) -> some View {
        VStack(spacing: 12) { // text-center space-y-3
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.15)) // bg-{color}-100
                    .frame(width: 64, height: 64)   // w-16 h-16
                Image(systemName: item.icon)
                    .font(.system(size: 28))        // h-8 w-8
                    .foregroundColor(item.tint)
            }
            Text(item.title)
                .font(.system(size: Theme.FontSize.base, weight: .semibold))
                .foregroundColor(Theme.foreground)
            Text(item.body)
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Why Choose FinnaCalc

    private var whyChoose: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) { // space-y-4 mb-8
                Text("Why Choose FinnaCalc?")
                    .font(.system(size: 28, weight: .bold)) // text-3xl
                    .foregroundColor(Theme.foreground)
                    .multilineTextAlignment(.center)
                Text("We're committed to providing the most reliable and user-friendly financial tools available")
                    .font(.system(size: 18)) // text-lg
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 32) { // gap-8 (stacks on phone)
                ForEach(reasonItems) { item in
                    VStack(alignment: .leading, spacing: 16) { // space-y-4
                        Text(item.title)
                            .font(.system(size: Theme.FontSize.xl2 * 0.83, weight: .semibold)) // text-xl
                            .foregroundColor(Theme.foreground)
                        Text(item.body)
                            .font(.system(size: Theme.FontSize.base))
                            .foregroundColor(Theme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(24) // p-8
        .frame(maxWidth: .infinity)
        // bg-background rounded-lg shadow-sm
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // MARK: - Get in Touch

    private var getInTouch: some View {
        VStack(spacing: 16) { // text-center space-y-4
            Text("Get in Touch")
                .font(.system(size: Theme.FontSize.xl2, weight: .bold)) // text-2xl
                .foregroundColor(Theme.foreground)
                .multilineTextAlignment(.center)
            Text("Have questions, suggestions, or feedback? We'd love to hear from you. Our team is committed to continuously improving FinnaCalc based on user needs and feedback.")
                .font(.system(size: Theme.FontSize.base))
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) { // space-y-2
                contactRow(label: "Help & Assistance:", email: "helpfinnacalc@gmail.com")
                contactRow(label: "Business Inquiries:", email: "finnacalc@gmail.com")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func contactRow(label: String, email: String) -> some View {
        // <strong>label</strong> email — strong is bold, address links via mailto.
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: Theme.FontSize.base, weight: .bold))
                .foregroundColor(Theme.mutedForeground)
            if let url = URL(string: "mailto:\(email)") {
                Link(email, destination: url)
                    .font(.system(size: Theme.FontSize.base))
                    .foregroundColor(Theme.primary)
            } else {
                Text(email)
                    .font(.system(size: Theme.FontSize.base))
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("About — Light") {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.light)
}

#Preview("About — Dark") {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
