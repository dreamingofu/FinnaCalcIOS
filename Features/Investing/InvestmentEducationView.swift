//
//  InvestmentEducationView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of `../FinnaCalc/components/investment-education.tsx`.
//  Educational content: a community advert card, video lessons, recommended
//  reading resources, and a step-by-step learning path. Video lessons and
//  reading resources collapse/expand via DisclosureGroup so the long content
//  reads comfortably on a phone.
//

import SwiftUI

struct InvestmentEducationView: View {

    // MARK: - Models (ported from the web `videoLessons` / `readingResources` arrays)

    private struct VideoLesson: Identifiable {
        let id = UUID()
        let title: String
        let duration: String
        let level: String           // "Beginner" | "Intermediate"
        let lessonDescription: String
    }

    private struct ReadingResource: Identifiable {
        let id = UUID()
        let title: String
        let author: String
        let type: String            // "Book" | "Website"
        let resourceDescription: String
        let link: String            // "#" for placeholder links
    }

    private let videoLessons: [VideoLesson] = [
        VideoLesson(
            title: "What Are Stocks and Bonds?",
            duration: "6 min",
            level: "Beginner",
            lessonDescription: "Learn the basic building blocks of investing in simple terms."
        ),
        VideoLesson(
            title: "Understanding Risk vs Reward",
            duration: "8 min",
            level: "Beginner",
            lessonDescription: "How to balance potential gains with potential losses."
        ),
        VideoLesson(
            title: "Building a Diversified Portfolio",
            duration: "10 min",
            level: "Intermediate",
            lessonDescription: "Don't put all your eggs in one basket - learn why and how."
        ),
        VideoLesson(
            title: "Retirement Planning Basics",
            duration: "12 min",
            level: "Beginner",
            lessonDescription: "401(k), IRA, and other retirement accounts explained."
        ),
        VideoLesson(
            title: "Reading Financial Statements",
            duration: "15 min",
            level: "Intermediate",
            lessonDescription: "Understand income statements, balance sheets, and cash flow."
        ),
        VideoLesson(
            title: "Dollar-Cost Averaging Strategy",
            duration: "7 min",
            level: "Beginner",
            lessonDescription: "How to invest regularly to reduce timing risk."
        ),
    ]

    private let readingResources: [ReadingResource] = [
        ReadingResource(
            title: "The Simple Path to Wealth",
            author: "JL Collins",
            type: "Book",
            resourceDescription: "Straightforward advice on index fund investing and financial independence.",
            link: "#"
        ),
        ReadingResource(
            title: "A Random Walk Down Wall Street",
            author: "Burton Malkiel",
            type: "Book",
            resourceDescription: "Classic guide to passive investing and market efficiency.",
            link: "#"
        ),
        ReadingResource(
            title: "SEC Investor.gov",
            author: "U.S. Securities and Exchange Commission",
            type: "Website",
            resourceDescription: "Official government resource for investment education.",
            link: "https://investor.gov"
        ),
        ReadingResource(
            title: "Bogleheads Investment Philosophy",
            author: "Bogleheads Community",
            type: "Website",
            resourceDescription: "Simple, low-cost investing principles from Vanguard founder Jack Bogle.",
            link: "https://bogleheads.org"
        ),
    ]

    // Learning-path steps (web "Your Investment Learning Path").
    private struct LearningStep: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let detail: String
    }

    private let learningSteps: [LearningStep] = [
        LearningStep(
            number: 1,
            title: "Start with the Basics",
            detail: "Watch \"What Are Stocks and Bonds?\" and \"Understanding Risk vs Reward\""
        ),
        LearningStep(
            number: 2,
            title: "Learn About Diversification",
            detail: "Understand why spreading risk is crucial for long-term success"
        ),
        LearningStep(
            number: 3,
            title: "Plan for Retirement",
            detail: "Learn about 401(k)s, IRAs, and the power of compound interest"
        ),
        LearningStep(
            number: 4,
            title: "Start Investing",
            detail: "Apply what you've learned with our safe investment options"
        ),
    ]

    // MARK: - State

    @State private var safariURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { // space-y-6

                header

                communityCard

                videoLessonsCard

                readingResourcesCard

                learningPathCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Investment Education")
                .font(Theme.sans(30, weight: .bold)) // text-3xl
                .foregroundColor(Theme.foreground)
            Text("Master the fundamentals of smart investing")
                .font(Theme.sans(Theme.FontSize.base))
                .foregroundColor(Theme.mutedForeground)
        }
    }

    // MARK: - Advertisement / community card

    private var communityCard: some View {
        FCCard {
            FCCardContent {
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(Theme.sans(28))
                            .foregroundColor(Theme.positive) // text-green-600
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Join Our Investment Community")
                                .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                                .foregroundColor(Theme.foreground)
                            Text("Connect with other beginner investors")
                                .font(Theme.sans(Theme.FontSize.sm))
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                    Spacer(minLength: 8)
                    FCButton(variant: .outline, size: .sm) {
                        HStack(spacing: 4) {
                            Text("Join Now")
                            Image(systemName: "arrow.up.right.square")
                                .font(Theme.sans(12))
                        }
                    } action: {}
                }
                .padding(.top, 16) // restore content padding (p-4 in web; content has pt-0)
            }
        }
        // bg-gradient-to-r from-green-50 to-blue-50 → soft green→blue tint
        .background(
            LinearGradient(
                colors: [Theme.positive.opacity(0.10), Theme.primary.opacity(0.10)],
                startPoint: .leading, endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        )
    }

    // MARK: - Video lessons

    private var videoLessonsCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Video Lessons")
                FCCardDescription("Short, engaging videos that explain complex topics simply")
            }
            FCCardContent {
                VStack(spacing: 12) {
                    ForEach(videoLessons) { video in
                        DisclosureGroup {
                            Text(video.lessonDescription)
                                .font(Theme.sans(Theme.FontSize.sm))
                                .foregroundColor(Theme.mutedForeground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        } label: {
                            videoRowLabel(video)
                        }
                        .padding(12)
                        .background(Theme.muted.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func videoRowLabel(_ video: VideoLesson) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Play button affordance
            ZStack {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 36, height: 36)
                Image(systemName: "play.fill")
                    .font(Theme.sans(14))
                    .foregroundColor(Theme.primaryForeground)
                    .offset(x: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                    .foregroundColor(Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    FCBadge(variant: video.level == "Beginner" ? .default : .secondary) {
                        Text(video.level)
                    }
                    FCBadge(variant: .secondary) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(Theme.sans(10))
                            Text(video.duration)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reading resources

    private var readingResourcesCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Recommended Reading")
                FCCardDescription("Curated articles and resources from trusted financial experts")
            }
            FCCardContent {
                VStack(spacing: 12) {
                    ForEach(readingResources) { resource in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(resource.resourceDescription)
                                    .font(Theme.sans(Theme.FontSize.sm))
                                    .foregroundColor(Theme.mutedForeground)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                FCButton(variant: .outline, size: .sm) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(Theme.sans(12))
                                        Text("View Resource")
                                    }
                                    .frame(maxWidth: .infinity)
                                } action: {
                                    openResource(resource)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 8)
                        } label: {
                            readingRowLabel(resource)
                        }
                        .padding(12)
                        .background(Theme.muted.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func readingRowLabel(_ resource: ReadingResource) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(resource.title)
                    .font(Theme.sans(Theme.FontSize.base, weight: .semibold))
                    .foregroundColor(Theme.foreground)
                Text("by \(resource.author)")
                    .font(Theme.sans(Theme.FontSize.sm))
                    .foregroundColor(Theme.mutedForeground)
                FCBadge(variant: .outline) {
                    Text(resource.type)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "book")
                .font(Theme.sans(18))
                .foregroundColor(Theme.mutedForeground)
        }
    }

    private func openResource(_ resource: ReadingResource) {
        guard resource.link != "#", let url = URL(string: resource.link) else { return }
        safariURL = url
    }

    // MARK: - Learning path

    private var learningPathCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Your Investment Learning Path")
                FCCardDescription("Follow this step-by-step guide to build your knowledge")
            }
            FCCardContent {
                VStack(spacing: 16) { // space-y-4
                    ForEach(learningSteps) { step in
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary)
                                    .frame(width: 32, height: 32)
                                Text("\(step.number)")
                                    .font(Theme.sans(Theme.FontSize.sm, weight: .bold))
                                    .foregroundColor(Theme.primaryForeground)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(Theme.sans(Theme.FontSize.base, weight: .medium))
                                    .foregroundColor(Theme.foreground)
                                Text(step.detail)
                                    .font(Theme.sans(Theme.FontSize.sm))
                                    .foregroundColor(Theme.mutedForeground)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        // bg-blue-50 border-blue-200 → soft blue tint
        .background(
            Theme.primary.opacity(0.06)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        )
    }
}

// Allow URL to drive a `.sheet(item:)`.
extension URL: Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    NavigationStack {
        InvestmentEducationView()
    }
}
