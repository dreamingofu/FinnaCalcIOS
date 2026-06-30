//
//  PrivacyView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/app/privacy/page.tsx`.
//  The Privacy Policy: a stack of titled cards (Introduction, Information
//  Collected, How Information Is Used, Sharing, Data Security, Cookies, Your
//  Rights, Children's Privacy, Changes, Contact). Each card's title carries the
//  same colored SF Symbol the web uses (lucide icons), body copy is
//  muted-foreground, bulleted lists mirror the web `<ul>`s, and the two
//  highlighted callouts (blue "Important", yellow "Note") are preserved.
//

import SwiftUI

struct PrivacyView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) { // space-y-8

                // Back button (web: <Button variant="outline" onClick={router.back}>)
                FCButton(variant: .outline, size: .default) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                } action: {
                    dismiss()
                }

                // Header — text-4xl font-bold, centered
                Text("Privacy Policy")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)

                // MARK: Introduction
                section(icon: "eye", iconColor: blue, title: "Introduction") {
                    paragraph(
                        "FinnaCalc is committed to protecting your privacy. This Privacy Policy explains how information is collected, used, disclosed, and safeguarded when you visit the website and use the financial calculators and tools."
                    )
                    paragraph(
                        "By using FinnaCalc, you agree to the collection and use of information in accordance with this policy. If you do not agree with the policies and practices outlined, please do not use the services."
                    )
                }

                // MARK: Information Collected
                section(icon: "cylinder.split.1x2", iconColor: green, title: "Information Collected") {
                    subheading("Information You Provide")
                    bulletList([
                        "Calculator inputs and financial data (processed locally, not stored)",
                        "Contact information when you reach out",
                        "Feedback and suggestions you provide",
                    ])

                    subheading("Automatically Collected Information")
                    bulletList([
                        "Usage data and analytics (page views, time spent, features used)",
                        "Device information (browser type, operating system, screen resolution)",
                        "IP address and general location information",
                        "Cookies and similar tracking technologies",
                    ])

                    callout(
                        boldLead: "Important:",
                        body: " All financial calculations are performed locally in your browser. Your personal financial data entered into the calculators is not stored, transmitted, or accessed.",
                        tint: calloutBlue,
                        textColor: calloutBlueText
                    )
                }

                // MARK: How Information Is Used
                section(icon: "person.2", iconColor: purple, title: "How Information Is Used") {
                    leadBulletList([
                        ("Service Provision:", " To provide and maintain financial calculators and tools"),
                        ("Improvement:", " To analyze usage patterns and improve services"),
                        ("Communication:", " To respond to inquiries and provide customer support"),
                        ("Security:", " To detect, prevent, and address technical issues and security threats"),
                        ("Legal Compliance:", " To comply with applicable laws and regulations"),
                    ])
                }

                // MARK: Information Sharing and Disclosure
                section(icon: "lock", iconColor: red, title: "Information Sharing and Disclosure") {
                    paragraph(
                        "Personal information is not sold, traded, or otherwise transferred to third parties except in the following circumstances:"
                    )
                    leadBulletList([
                        ("Service Providers:", " Trusted third parties who assist in operating the website and conducting business"),
                        ("Legal Requirements:", " When required by law or to protect rights and safety"),
                        ("Business Transfers:", " In connection with a merger, acquisition, or sale of assets"),
                        ("Consent:", " When you have given explicit consent for sharing"),
                    ])
                }

                // MARK: Data Security
                section(icon: "shield", iconColor: orange, title: "Data Security") {
                    paragraph(
                        "Appropriate technical and organizational security measures are implemented to protect your information against unauthorized access, alteration, disclosure, or destruction."
                    )
                    bulletList([
                        "SSL encryption for data transmission",
                        "Regular security assessments and updates",
                        "Limited access to personal information on a need-to-know basis",
                        "Secure hosting infrastructure",
                    ])
                    callout(
                        boldLead: "Note:",
                        body: " While efforts are made to protect your information, no method of transmission over the internet or electronic storage is 100% secure. Absolute security cannot be guaranteed.",
                        tint: calloutYellow,
                        textColor: calloutYellowText
                    )
                }

                // MARK: Cookies and Tracking Technologies
                section(title: "Cookies and Tracking Technologies") {
                    paragraph(
                        "Cookies and similar tracking technologies are used to enhance your experience on the website:"
                    )
                    leadBulletList([
                        ("Essential Cookies:", " Required for basic website functionality"),
                        ("Analytics Cookies:", " To understand how visitors use the site"),
                        ("Preference Cookies:", " To remember your settings and preferences"),
                    ])
                    paragraph(
                        "You can control cookies through your browser settings. However, disabling certain cookies may affect website functionality."
                    )
                }

                // MARK: Your Privacy Rights
                section(title: "Your Privacy Rights") {
                    paragraph("Depending on your location, you may have the following rights:")
                    leadBulletList([
                        ("Access:", " Request information about the personal data held about you"),
                        ("Correction:", " Request correction of inaccurate or incomplete information"),
                        ("Deletion:", " Request deletion of your personal information"),
                        ("Portability:", " Request a copy of your data in a structured format"),
                        ("Objection:", " Object to certain processing of your information"),
                    ])
                }

                // MARK: Children's Privacy
                section(title: "Children's Privacy") {
                    paragraph(
                        "The services are not intended for children under 13 years of age. Personal information from children under 13 is not knowingly collected. If you are a parent or guardian and believe your child has provided personal information, please make contact immediately."
                    )
                }

                // MARK: Changes to This Privacy Policy
                section(icon: "doc.text", iconColor: blue, title: "Changes to This Privacy Policy") {
                    paragraph(
                        "This Privacy Policy may be updated from time to time. You will be notified of any changes by posting the new Privacy Policy on this page. You are advised to review this Privacy Policy periodically for any changes."
                    )
                }

                // MARK: Contact Us
                section(title: "Contact Us") {
                    paragraph(
                        "If you have any questions about this Privacy Policy or privacy practices, please make contact:"
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        contactLine(label: "Help & Assistance:", email: "helpfinnacalc@gmail.com")
                        contactLine(label: "Inquiries:", email: "finnacalc@gmail.com")
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32) // py-8
            .frame(maxWidth: 768, alignment: .leading) // max-w-4xl, centered below
            .frame(maxWidth: .infinity)
        }
        .background(Theme.muted.opacity(0.4)) // bg-muted/40
    }

    // MARK: - Section card

    /// A titled `FCCard` whose title optionally carries a colored leading icon.
    @ViewBuilder
    private func section<Content: View>(
        icon: String? = nil,
        iconColor: Color = Theme.foreground,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        FCCard {
            FCCardHeader {
                HStack(spacing: 8) { // flex items-center gap-2
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: Theme.FontSize.xl2 * 0.85, weight: .regular))
                            .foregroundColor(iconColor)
                    }
                    Text(title)
                        .font(.system(size: Theme.FontSize.xl2, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundColor(Theme.cardForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FCCardContent {
                VStack(alignment: .leading, spacing: 16) { // space-y-4 / space-y-6
                    content()
                }
            }
        }
    }

    // MARK: - Content builders

    /// `text-muted-foreground` body paragraph.
    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.base))
            .foregroundColor(Theme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `text-lg font-semibold text-foreground` subsection heading.
    private func subheading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(Theme.foreground)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, -4) // tighten before list (mb-3 minus list spacing)
    }

    /// Plain bulleted list (`• item`).
    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) { // space-y-2
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: Theme.FontSize.base))
                .foregroundColor(Theme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Bulleted list where each item leads with a bold label (`• **Lead:** rest`).
    private func leadBulletList(_ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) { // space-y-3 / space-y-2
            ForEach(items, id: \.0) { lead, rest in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                    (Text(lead).fontWeight(.bold) + Text(rest))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: Theme.FontSize.base))
                .foregroundColor(Theme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Highlighted callout box (web `bg-*-50` with `text-*-800`).
    private func callout(boldLead: String, body: String, tint: Color, textColor: Color) -> some View {
        (Text(boldLead).fontWeight(.bold) + Text(body))
            .font(.system(size: Theme.FontSize.sm))
            .foregroundColor(textColor)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16) // p-4
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)) // rounded-lg
    }

    /// `**Label:** email` line, email rendered as a mailto Link.
    private func contactLine(label: String, email: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .fontWeight(.bold)
                .foregroundColor(Theme.mutedForeground)
            if let url = URL(string: "mailto:\(email)") {
                Link(email, destination: url)
                    .foregroundColor(Theme.primary)
            } else {
                Text(email).foregroundColor(Theme.mutedForeground)
            }
        }
        .font(.system(size: Theme.FontSize.base))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Icon / callout colors (lucide hue approximations)

    private let blue   = Color(red: 0.15, green: 0.39, blue: 0.92) // blue-600
    private let green  = Color(red: 0.13, green: 0.55, blue: 0.27) // green-600
    private let purple = Color(red: 0.49, green: 0.23, blue: 0.93) // purple-600
    private let red    = Color(red: 0.86, green: 0.15, blue: 0.15) // red-600
    private let orange = Color(red: 0.92, green: 0.34, blue: 0.05) // orange-600

    private let calloutBlue     = Color(red: 0.94, green: 0.96, blue: 1.0)   // blue-50
    private let calloutBlueText = Color(red: 0.12, green: 0.25, blue: 0.69)  // blue-800
    private let calloutYellow     = Color(red: 1.0, green: 0.98, blue: 0.92) // yellow-50
    private let calloutYellowText = Color(red: 0.52, green: 0.33, blue: 0.04) // yellow-800
}

#Preview("Privacy — Light") {
    PrivacyView().preferredColorScheme(.light)
}

#Preview("Privacy — Dark") {
    PrivacyView().preferredColorScheme(.dark)
}
