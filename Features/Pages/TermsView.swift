//
//  TermsView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/app/terms/page.tsx`.
//
//  The Terms of Service page: a scroll of headed cards carrying the full legal
//  text. The web page renders a centered "Terms of Service" title followed by a
//  series of `<Card>`s, several with a colored lucide icon in the title. Those
//  icons map to SF Symbols and their Tailwind hues (blue-600, green-600, etc.)
//  to approximate Color values here.
//
//  The web `router.back()` "Back" button maps to the surrounding
//  NavigationStack dismiss; an `onBack` closure is exposed so the host can wire
//  it up, defaulting to the environment `dismiss` action.
//

import SwiftUI

struct TermsView: View {

    @Environment(\.dismiss) private var dismiss

    /// Optional override for the "Back" action; defaults to dismissing the
    /// current navigation destination (mirrors the web `router.back()`).
    var onBack: (() -> Void)?

    // Tailwind hue approximations for the colored title icons.
    private let blue   = Color(h: 221, s: 83, l: 47)   // blue-600
    private let green  = Color(h: 142, s: 71, l: 36)   // green-600
    private let purple = Color(h: 271, s: 81, l: 56)   // purple-600
    private let yellow = Color(h: 45,  s: 93, l: 47)   // yellow-600
    private let red    = Color(h: 0,   s: 72, l: 51)   // red-600

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) { // space-y-8

                // ── Back button ──
                FCButton(variant: .outline) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                } action: {
                    if let onBack { onBack() } else { dismiss() }
                }

                // ── Header ──
                Text("Terms of Service") // text-4xl font-bold text-foreground
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                // ── Agreement ──
                FCCard {
                    titledHeader(icon: "doc.text", iconColor: blue, title: "Terms of Service Agreement")
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 16) {
                            paragraph("These Terms of Service govern your use of FinnaCalc's website and services. By accessing or using the services, you agree to be bound by these Terms. If you disagree with any part of these terms, then you may and should not access the services.")
                            paragraph("The right to update these Terms at any time is reserved. Changes will be effective immediately upon posting. Your continued use of the services after changes are posted constitutes acceptance of the new Terms.")
                        }
                    }
                }

                // ── Description of Service ──
                FCCard {
                    titledHeader(icon: "person.2", iconColor: green, title: "Description of Service")
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 16) {
                            paragraph("FinnaCalc provides free financial calculators and planning tools for personal and business use. The services include but are not limited to:")
                            bulletList([
                                "Business financial calculators (startup costs, break-even analysis, ROI, etc.)",
                                "Personal finance tools (tax calculators, loan analyzers, etc.)",
                                "Educational content and financial planning resources",
                                "Data export and sharing capabilities",
                            ])
                            // bg-blue-50 callout
                            (Text("Important: ").bold()
                                + Text("The calculators provide estimates for planning purposes only. Results should not be considered as professional financial, tax, or legal advice."))
                                .font(.system(size: Theme.FontSize.sm))
                                .foregroundColor(Color(h: 221, s: 70, l: 40)) // text-blue-800
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color(h: 210, s: 100, l: 96)) // bg-blue-50
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                        }
                    }
                }

                // ── User Responsibilities ──
                FCCard {
                    titledHeader(icon: "shield", iconColor: purple, title: "User Responsibilities")
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 16) {
                            paragraph("By using the services, you agree to:")
                            bulletList([
                                "Use the service only for lawful purposes and in accordance with these Terms",
                                "Provide accurate information when using the calculators",
                                "Not attempt to interfere with or disrupt the services",
                                "Not use automated systems to access the services without permission",
                                "Respect intellectual property rights",
                                "Not share or distribute malicious content",
                                "Comply with all applicable laws and regulations",
                            ])
                        }
                    }
                }

                // ── Important Disclaimers ──
                FCCard {
                    titledHeader(icon: "exclamationmark.triangle", iconColor: yellow, title: "Important Disclaimers")
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 24) { // space-y-6
                            subsection(
                                heading: "Financial Advice Disclaimer",
                                body: "FinnaCalc does not provide financial, investment, tax, or legal advice. The calculators and tools are for informational and educational purposes only. Results are estimates based on the information you provide and should not be relied upon for making financial decisions without consulting qualified professionals."
                            )
                            subsection(
                                heading: "Accuracy Disclaimer",
                                body: "While efforts are made for accuracy, no warranties are made about the completeness, reliability, or accuracy of the calculators or information. Financial regulations, tax laws, and market conditions change frequently, and the tools may not reflect the most current information."
                            )
                            subsection(
                                heading: "No Warranty",
                                body: "The services are provided \"as is\" without any warranty of any kind, either express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, or non-infringement."
                            )
                        }
                    }
                }

                // ── Limitation of Liability ──
                FCCard {
                    titledHeader(icon: "hammer", iconColor: red, title: "Limitation of Liability")
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 16) {
                            paragraph("To the fullest extent permitted by law, FinnaCalc shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to:")
                            bulletList([
                                "Financial losses resulting from use of the calculators",
                                "Business interruption or loss of profits",
                                "Data loss or corruption",
                                "Third-party claims or damages",
                            ])
                            paragraph("Total liability for any claims arising from your use of the services shall not exceed the amount paid for the services (which is $0 for free services).")
                        }
                    }
                }

                // ── Intellectual Property Rights ──
                FCCard {
                    FCCardHeader {
                        FCCardTitle("Intellectual Property Rights")
                    }
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 16) {
                            paragraph("The FinnaCalc website, including its content, features, and functionality, is owned by FinnaCalc and is protected by copyright, trademark, and other intellectual property laws.")
                            paragraph("You may use the services for personal and business purposes, but you may not:")
                            bulletList([
                                "Copy, modify, or distribute content without permission",
                                "Use trademarks or branding without authorization",
                                "Create derivative works based on the services",
                                "Reverse engineer or attempt to extract source code",
                            ])
                        }
                    }
                }

                // ── Privacy and Data Protection ──
                FCCard {
                    FCCardHeader {
                        FCCardTitle("Privacy and Data Protection")
                    }
                    FCCardContent {
                        (Text("Your privacy is important. The collection and use of personal information is governed by the ")
                            + Text("Privacy Policy").foregroundColor(Theme.primary)
                            + Text(", which is incorporated into these Terms by reference. By using the services, you consent to the collection and use of information as described in the Privacy Policy."))
                            .font(.system(size: Theme.FontSize.base))
                            .foregroundColor(Theme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // ── Termination ──
                FCCard {
                    FCCardHeader {
                        FCCardTitle("Termination")
                    }
                    FCCardContent {
                        paragraph("Access to the services may be terminated or suspended immediately, without prior notice or liability, for any reason, including breach of these Terms. Upon termination, your right to use the services will cease immediately.")
                    }
                }

                // ── Governing Law and Jurisdiction ──
                FCCard {
                    FCCardHeader {
                        FCCardTitle("Governing Law and Jurisdiction")
                    }
                    FCCardContent {
                        paragraph("These Terms shall be governed by and construed in accordance with the laws of the United States, without regard to conflict of law principles. Any disputes arising from these Terms or your use of the services shall be resolved through binding arbitration or in the courts of competent jurisdiction.")
                    }
                }

                // ── Severability and Entire Agreement ──
                FCCard {
                    FCCardHeader {
                        FCCardTitle("Severability and Entire Agreement")
                    }
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 16) {
                            paragraph("If any provision of these Terms is held to be invalid or unenforceable, the remaining provisions will remain in full force and effect.")
                            paragraph("These Terms, together with the Privacy Policy, constitute the entire agreement between you and FinnaCalc regarding your use of the services.")
                        }
                    }
                }

                // ── Contact Information ──
                FCCard {
                    FCCardHeader {
                        FCCardTitle("Contact Information")
                    }
                    FCCardContent {
                        VStack(alignment: .leading, spacing: 16) {
                            paragraph("If you have any questions about these Terms of Service, please make contact:")
                            VStack(alignment: .leading, spacing: 8) {
                                contactRow(label: "Help & Assistance:", email: "helpfinnacalc@gmail.com")
                                contactRow(label: "Inquiries:", email: "finnacalc@gmail.com")
                            }
                        }
                    }
                }
            }
            .padding(16) // px-4 py-8 (mobile)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.muted.opacity(0.4)) // bg-muted/40
    }

    // MARK: - Building blocks

    /// A card header with a colored leading icon, mirroring the web
    /// `<CardTitle className="flex items-center gap-2">` + lucide icon.
    @ViewBuilder
    private func titledHeader(icon: String, iconColor: Color, title: String) -> some View {
        FCCardHeader {
            HStack(alignment: .center, spacing: 8) { // gap-2
                Image(systemName: icon)
                    .font(.system(size: 22)) // h-6 w-6
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: Theme.FontSize.xl2, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundColor(Theme.cardForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// `text-muted-foreground` body paragraph.
    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.base))
            .foregroundColor(Theme.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A bulleted list rendered with leading "•" markers (`space-y-2`).
    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) { // space-y-2
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                        .font(.system(size: Theme.FontSize.base))
                        .foregroundColor(Theme.mutedForeground)
                    Text(item)
                        .font(.system(size: Theme.FontSize.base))
                        .foregroundColor(Theme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// A disclaimer subsection: bold heading + paragraph (`<h3>` + `<p>`).
    private func subsection(heading: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) { // mb-3
            Text(heading) // text-lg font-semibold text-foreground
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            paragraph(body)
        }
    }

    /// A contact line: bold label + a tappable mailto link.
    private func contactRow(label: String, email: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: Theme.FontSize.base, weight: .bold))
                .foregroundColor(Theme.mutedForeground)
            Link(email, destination: URL(string: "mailto:\(email)")!)
                .font(.system(size: Theme.FontSize.base))
                .foregroundColor(Theme.primary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TermsView()
    }
}
