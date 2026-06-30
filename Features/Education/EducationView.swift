//
//  EducationView.swift
//  FinnaCalcIOS
//
//  Native SwiftUI port of the FinnaCalc web Education tab:
//    - `../FinnaCalc/app/education/page.tsx`            (topic grid + search)
//    - `../FinnaCalc/components/financial-education-hub.tsx` (lessons/articles hub)
//    - `../FinnaCalc/lib/education-content.ts`          (content data + search)
//
//  This is the Education tab root. RootView already wraps it in a
//  NavigationStack, so the web's internal `activeSection` swap (grid ⇄ hub) is
//  modeled with a NavigationLink push to `EducationHubView`. The web Dialog (an
//  empty "content embedded here" placeholder) is dropped in favor of the real
//  behavior the cards imply: video lessons open YouTube and reading resources
//  open the article — both via SwiftUI `Link`.
//

import SwiftUI

// MARK: - Content model (ported from lib/education-content.ts)

/// A single education item — a video lesson or a reading resource.
struct EduItem: Hashable {
    let title: String
    let url: String
}

/// A flattened, searchable document (mirrors `EduSearchDoc`).
struct EduSearchDoc: Hashable, Identifiable {
    enum Kind: String { case video, article }
    let topic: String
    let topicName: String
    let type: Kind
    let title: String
    let url: String
    let index: Int

    var id: String { "\(type.rawValue)-\(topic)-\(index)" }
}

/// Shared catalog + relevance search, ported 1:1 from `lib/education-content.ts`.
enum EducationContent {

    /// `EDU_TOPICS` — ordered topic list used by both the grid and the hub.
    static let topics: [(id: String, name: String)] = [
        ("credit", "Credit & Debt"),
        ("investing", "Investing"),
        ("budgeting", "Budgeting"),
        ("retirement", "Retirement"),
        ("taxes", "Tax Planning"),
    ]

    static func topicName(_ id: String) -> String {
        topics.first { $0.id == id }?.name ?? id
    }

    /// `videoLessons` — YouTube lessons keyed by topic id.
    static let videoLessons: [String: [EduItem]] = [
        "credit": [
            EduItem(title: "What Is a Credit Score?", url: "https://www.youtube.com/watch?v=jwML94IOW0s"),
            EduItem(title: "What Can Change Your Credit Score?", url: "https://www.youtube.com/watch?v=IZN5IT28iHo"),
            EduItem(title: "Understanding Loans and Debt", url: "https://www.youtube.com/watch?v=E2dzSPOhUOI"),
            EduItem(title: "Good Debt vs. Bad Debt", url: "https://www.youtube.com/watch?v=MFCdA2vGVh4"),
            EduItem(title: "What Is APR and Why It Matters", url: "https://www.youtube.com/watch?v=MqqXTrEEZ7Y"),
            EduItem(title: "Understanding Your FICO Score", url: "https://www.youtube.com/watch?v=8AtM1R9NmwM"),
        ],
        "investing": [
            EduItem(title: "What Are Stocks?", url: "https://www.youtube.com/watch?v=98qfFzqDKR8"),
            EduItem(title: "Bonds vs. Stocks: What's the Difference?", url: "https://www.youtube.com/watch?v=rs1md3e4aYU"),
            EduItem(title: "Understanding Risk and Return", url: "https://www.youtube.com/watch?v=7mo167ohvJw"),
            EduItem(title: "A Beginner's Guide to Investing", url: "https://www.youtube.com/watch?v=8_iWSsoiNXs"),
            EduItem(title: "Index Funds vs. Mutual Funds vs. ETFs", url: "https://www.youtube.com/watch?v=ugBs333NhbI"),
        ],
        "retirement": [
            EduItem(title: "What Is a 401(k)?", url: "https://www.youtube.com/watch?v=d8rNitoPZeo"),
            EduItem(title: "An Introduction to Traditional IRAs", url: "https://www.youtube.com/watch?v=UV8kgqk_DAY"),
            EduItem(title: "The Power of a Roth IRA", url: "https://www.youtube.com/watch?v=Xd8VXDqXtkE"),
            EduItem(title: "Managing Your 401(k) When You Change Jobs", url: "https://www.youtube.com/watch?v=PLZHTIrazF8"),
        ],
        "budgeting": [
            EduItem(title: "How to Budget Your Paycheck", url: "https://www.youtube.com/watch?v=5tQuez0kbOY"),
            EduItem(title: "How to Stop Living Paycheck to Paycheck", url: "https://www.youtube.com/watch?v=NSpMFtcXxcc"),
            EduItem(title: "How to Manage Your Money (The 50/30/20 Rule)", url: "https://www.youtube.com/watch?v=HQzoZfc3GwQ"),
            EduItem(title: "How to Manage Your Money (The 70/20/10 Rule)", url: "https://www.youtube.com/watch?v=HkNPZVu-jZM"),
            EduItem(title: "A Beginner's Guide to Paying Off Debt", url: "https://www.youtube.com/watch?v=_LdpjN2oDNo"),
        ],
        "taxes": [
            EduItem(title: "What Are Taxes?", url: "https://www.youtube.com/watch?v=kdfk22Ck4nM"),
            EduItem(title: "How Tax Brackets Work", url: "https://www.youtube.com/watch?v=AhgR3X--bbY"),
            EduItem(title: "An Introduction to Tax Deductions", url: "https://www.youtube.com/watch?v=GypHy3gnG5E"),
            EduItem(title: "Understanding Tax Credits", url: "https://www.youtube.com/watch?v=4gYvlMwvdnw"),
            EduItem(title: "A Guide to Common Tax Forms (Part 1)", url: "https://www.youtube.com/watch?v=boklbFhF8l8"),
            EduItem(title: "A Guide to Common Tax Forms (Part 2)", url: "https://www.youtube.com/watch?v=W1562KoBExA"),
        ],
    ]

    /// `readingResources` — curated articles keyed by topic id.
    static let readingResources: [String: [EduItem]] = [
        "credit": [
            EduItem(title: "An Introduction to Credit and Loans", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:loans-and-debt/xa6995ea67a8e9fdd:borrowing-money/a/loans-and-credit"),
            EduItem(title: "How to Raise Your Credit Score", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:consumer-credit/xa6995ea67a8e9fdd:credit-score/a/how-do-i-raise-my-credit-score"),
        ],
        "investing": [
            EduItem(title: "How to Invest with Confidence", url: "https://www.investopedia.com/articles/basics/11/3-s-simple-investing.asp"),
            EduItem(title: "How and Where to Start Investing", url: "https://www.investopedia.com/terms/i/investment.asp"),
        ],
        "retirement": [
            EduItem(title: "How to Invest for Retirement", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:investments-retirement/xa6995ea67a8e9fdd:investing/a/how-to-invest-in-your-retirement-account"),
            EduItem(title: "Building a Strong Foundation for Retirement", url: "https://www.khanacademy.org/college-careers-more/personal-finance/pf-investment-vehicles-insurance-and-retirement/pf-ira-401ks/a/building-a-foundation-for-retirement"),
            EduItem(title: "The Effect of Time on Your Retirement Savings", url: "https://www.khanacademy.org/college-careers-more/personal-finance/pf-investment-vehicles-insurance-and-retirement/pf-ira-401ks/a/the-effect-of-time-on-your-retirement-account"),
            EduItem(title: "Pensions, 403(b)s, and SIMPLE IRAs Explained", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:investments-retirement/xa6995ea67a8e9fdd:saving-for-retirement/a/what-is-a-pension-403-b-simple-ira-and-others"),
        ],
        "budgeting": [
            EduItem(title: "What Is a Budget?", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:budgeting-and-saving/xa6995ea67a8e9fdd:budgeting/a/what-is-a-budget"),
            EduItem(title: "A Step-by-Step Guide to Creating a Budget", url: "https://www.khanacademy.org/college-careers-more/personal-finance/pf-saving-and-budgeting/tips-for-tracking-and-saving-money/a/creating-a-budget"),
            EduItem(title: "How to Balance Your Budget", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:budgeting-and-saving/xa6995ea67a8e9fdd:budgeting/a/balancing-your-budget"),
            EduItem(title: "Understanding Budgeting Constraints and Decisions", url: "https://www.khanacademy.org/economics-finance-domain/microeconomics/choices-opp-cost-tutorial/utility-maximization-with-indifference-curves/a/how-individuals-make-choices-based-on-their-budget-constraint-cnx"),
        ],
        "taxes": [
            EduItem(title: "An Overview of Common Tax Forms", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:taxes-and-tax-forms/xa6995ea67a8e9fdd:tax-forms/a/tax-forms"),
            EduItem(title: "Your Guide to Key Tax Terms", url: "https://www.khanacademy.org/math/grade-7-math-tx/xa876d090ec748f45:number-and-operations/xa876d090ec748f45:income-tax-withholding/a/your-guide-to-key-tax-terms-brought-to-you-by-better-money-habits"),
            EduItem(title: "Understanding the Taxes You Pay", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:taxes-and-tax-forms/xa6995ea67a8e9fdd:what-are-taxes/a/understanding-the-taxes-you-pay"),
            EduItem(title: "A Guide to Taxes for the Self-Employed", url: "https://www.khanacademy.org/college-careers-more/financial-literacy/xa6995ea67a8e9fdd:employment/xa6995ea67a8e9fdd:non-typical-pay-structures/a/tax-responsibilities-for-self-employed-individuals"),
        ],
    ]

    /// `EDU_SEARCH_INDEX` — every video + article flattened for search.
    static let searchIndex: [EduSearchDoc] = {
        var docs: [EduSearchDoc] = []
        for (topic, _) in topics {
            for (index, item) in (videoLessons[topic] ?? []).enumerated() {
                docs.append(EduSearchDoc(topic: topic, topicName: topicName(topic),
                                         type: .video, title: item.title, url: item.url, index: index))
            }
        }
        for (topic, _) in topics {
            for (index, item) in (readingResources[topic] ?? []).enumerated() {
                docs.append(EduSearchDoc(topic: topic, topicName: topicName(topic),
                                         type: .article, title: item.title, url: item.url, index: index))
            }
        }
        return docs
    }()

    // MARK: Relevance search (ported from `searchEducation`)

    private static let stopWords: Set<String> = [
        "how", "to", "what", "is", "are", "a", "an", "the", "and", "or", "of", "in", "for",
        "my", "do", "i", "on", "with", "you", "your", "vs", "me", "can", "should", "about",
        "best", "way", "ways", "tips", "guide", "explain", "explained",
    ]

    private static func tokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for ch in s.lowercased() {
            if ch.isASCII && (ch.isLetter || ch.isNumber) {
                current.append(ch)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens.filter { $0.count > 1 && !stopWords.contains($0) }
    }

    /// Mirrors the JS `stem` regex `(ings|ing|ies|ied|ed|es|s)$`.
    private static func stem(_ t: String) -> String {
        for suffix in ["ings", "ing", "ies", "ied", "ed", "es", "s"] {
            if t.count > suffix.count, t.hasSuffix(suffix) {
                return String(t.dropLast(suffix.count))
            }
        }
        return t
    }

    /// Ranks education content against a free-text query (forgiving stem/prefix/
    /// substring match). Returns `[]` when nothing is reasonably related.
    static func search(_ query: String) -> [EduSearchDoc] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.count < 2 { return [] }

        let qTokens = tokenize(q).map(stem)
        if qTokens.isEmpty {
            // All-stopword query → plain substring match.
            return searchIndex.filter { "\($0.title) \($0.topicName)".lowercased().contains(q) }
        }

        let scored: [(doc: EduSearchDoc, score: Double)] = searchIndex.map { doc in
            let titleText = doc.title.lowercased()
            let fullText = "\(doc.title) \(doc.topicName)".lowercased()
            let docTokens = tokenize(fullText).map(stem)
            var score = 0.0

            if titleText.contains(q) { score += 12 }
            else if fullText.contains(q) { score += 8 }

            var matched = 0
            for qt in qTokens {
                if docTokens.contains(qt) {
                    score += 5; matched += 1
                } else if docTokens.contains(where: { $0.hasPrefix(qt) || qt.hasPrefix($0) }) {
                    score += 3; matched += 1
                } else if fullText.contains(qt) {
                    score += 1.5; matched += 1
                }
            }
            if matched == qTokens.count && qTokens.count > 1 { score += 3 }

            return (doc, score)
        }

        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(24)
            .map { $0.doc }
    }
}

// MARK: - Topic grid model (page.tsx TOPICS)

private struct EducationTopicCard: Identifiable {
    let id: String
    let title: String
    let icon: String         // SF Symbol approximating the lucide icon
    let items: [String]
}

private let educationTopicCards: [EducationTopicCard] = [
    EducationTopicCard(id: "credit", title: "Credit & Debt", icon: "dollarsign.circle",
                       items: ["Understanding credit scores", "How to improve credit", "Debt payoff strategies"]),
    EducationTopicCard(id: "investing", title: "Investing", icon: "chart.line.uptrend.xyaxis",
                       items: ["What are stocks & bonds?", "Risk vs reward explained", "Portfolio diversification"]),
    EducationTopicCard(id: "budgeting", title: "Budgeting", icon: "chart.pie",
                       items: ["Creating a budget", "Tracking expenses", "Emergency fund planning"]),
    EducationTopicCard(id: "retirement", title: "Retirement", icon: "shield",
                       items: ["401(k) vs IRA explained", "Compound interest power", "Retirement calculators"]),
    EducationTopicCard(id: "taxes", title: "Tax Planning", icon: "doc.text",
                       items: ["Understanding tax brackets", "Deductions vs credits", "Business vs personal taxes"]),
]

// MARK: - Hub destination (where a topic / search result lands)

/// Encodes which topic the hub opens on and which lesson/article is pre-selected.
private struct HubDestination: Hashable {
    let topic: String
    let videoIndex: Int
    let articleIndex: Int
}

// MARK: - EducationView (tab root)

struct EducationView: View {
    @State private var query: String = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [EduSearchDoc] {
        EducationContent.search(query)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) { // space-y-8
                header
                searchField

                if trimmedQuery.isEmpty {
                    topicGrid
                } else if results.isEmpty {
                    emptyResults
                } else {
                    resultsList
                }
            }
            .padding(.horizontal, 16) // px-4
            .padding(.vertical, 32)   // py-8
            .frame(maxWidth: 720)     // container max width
            .frame(maxWidth: .infinity)
        }
        .background(Theme.muted.opacity(0.4).ignoresSafeArea()) // bg-muted/40
        .navigationTitle("Education")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HubDestination.self) { dest in
            EducationHubView(
                initialTopic: dest.topic,
                initialVideoIndex: dest.videoIndex,
                initialArticleIndex: dest.articleIndex
            )
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 16) {
            Text("Build Financial Confidence")
                .font(.system(size: 30, weight: .bold)) // text-3xl
                .foregroundColor(Theme.primary)
                .multilineTextAlignment(.center)
            Text("Master personal finance fundamentals with easy-to-understand lessons, videos, and expert guidance.")
                .font(.system(size: 18)) // text-lg
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.mutedForeground)
            FCTextField(
                "Search lessons & articles — e.g. how to invest, paying off debt",
                text: $query
            )
        }
    }

    // MARK: Topic grid

    private var topicGrid: some View {
        VStack(spacing: 24) { // gap-6
            ForEach(educationTopicCards) { topic in
                NavigationLink(value: HubDestination(topic: topic.id, videoIndex: 0, articleIndex: 0)) {
                    topicCard(topic)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func topicCard(_ topic: EducationTopicCard) -> some View {
        FCCard {
            FCCardHeader {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.primary)
                            .frame(width: 48, height: 48)
                        Image(systemName: topic.icon)
                            .font(.system(size: 24))
                            .foregroundColor(Theme.primaryForeground)
                    }
                    Text(topic.title)
                        .font(.system(size: Theme.FontSize.base, weight: .semibold))
                        .foregroundColor(Theme.cardForeground)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            FCCardContent {
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        ForEach(topic.items, id: \.self) { item in
                            Text(item)
                                .font(.system(size: Theme.FontSize.sm))
                                .foregroundColor(Theme.mutedForeground)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Web renders an outline "Learn More" button; the whole card
                    // is the tap target (NavigationLink), so this reads as a
                    // visual affordance rather than a separate control.
                    Text("Learn More")
                        .font(.system(size: Theme.FontSize.sm, weight: .medium))
                        .foregroundColor(Theme.foreground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.input, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: Results list

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(results.count) result\(results.count != 1 ? "s" : "") for \u{201C}\(trimmedQuery)\u{201D}")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                ForEach(results) { doc in
                    NavigationLink(value: HubDestination(
                        topic: doc.topic,
                        videoIndex: doc.type == .video ? doc.index : 0,
                        articleIndex: doc.type == .article ? doc.index : 0
                    )) {
                        resultRow(doc)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func resultRow(_ doc: EduSearchDoc) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill((doc.type == .video ? Theme.destructive : Theme.primary).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: doc.type == .video ? "play.fill" : "book")
                    .font(.system(size: 18))
                    .foregroundColor(doc.type == .video ? Theme.destructive : Theme.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title)
                    .font(.system(size: Theme.FontSize.base, weight: .semibold))
                    .foregroundColor(Theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Text("\(doc.type == .video ? "Video lesson" : "Article") · \(doc.topicName)")
                    .font(.system(size: Theme.FontSize.xs))
                    .foregroundColor(Theme.mutedForeground)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    // MARK: Empty results

    private var emptyResults: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Theme.mutedForeground)
                .padding(.bottom, 4)
            Text("We couldn\u{2019}t find anything for \u{201C}\(trimmedQuery)\u{201D}")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.foreground)
                .multilineTextAlignment(.center)
            Text("Try different words, or browse the topics below. We may not have a lesson on that yet.")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            FCButton("Browse all topics", variant: .outline) {
                query = ""
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - EducationHubView (financial-education-hub.tsx)

/// The Financial Education Hub: a topic selector, a paged Video Lessons card,
/// and a paged Reading Resources card. Pushed onto the navigation stack from the
/// topic grid or a search result. Mirrors the web hub's prev/next paging and
/// per-topic reset behavior.
private struct EducationHubView: View {
    let initialTopic: String
    let initialVideoIndex: Int
    let initialArticleIndex: Int

    @State private var activeTopic: String
    @State private var videoIndex: Int
    @State private var articleIndex: Int

    init(initialTopic: String, initialVideoIndex: Int, initialArticleIndex: Int) {
        self.initialTopic = initialTopic
        self.initialVideoIndex = initialVideoIndex
        self.initialArticleIndex = initialArticleIndex
        _activeTopic = State(initialValue: initialTopic)
        _videoIndex = State(initialValue: initialVideoIndex)
        _articleIndex = State(initialValue: initialArticleIndex)
    }

    private var videos: [EduItem] { EducationContent.videoLessons[activeTopic] ?? [] }
    private var articles: [EduItem] { EducationContent.readingResources[activeTopic] ?? [] }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) { // space-y-6
                hubHeader
                topicSelector
                videoCard
                readingCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.muted.opacity(0.4).ignoresSafeArea())
        .navigationTitle("Education Hub")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var hubHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Financial Education Hub")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Theme.foreground)
            Text("Your journey to financial confidence starts here")
                .font(.system(size: Theme.FontSize.base))
                .foregroundColor(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Topic selector (horizontal pill row)

    private var topicSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EducationContent.topics, id: \.id) { topic in
                    FCButton(
                        topic.name,
                        variant: activeTopic == topic.id ? .default : .outline,
                        size: .sm
                    ) {
                        activeTopic = topic.id
                        videoIndex = 0
                        articleIndex = 0
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Video Lessons card

    private var videoCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Video Lessons")
                FCCardDescription("Short, engaging videos to explain key concepts")
            }
            FCCardContent {
                if videos.isEmpty {
                    Text("No video lessons for this topic yet.")
                        .font(.system(size: Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                } else {
                    pagedContent(
                        index: $videoIndex,
                        count: videos.count,
                        title: videos[safe: videoIndex]?.title ?? ""
                    ) {
                        videoTile(videos[safe: videoIndex])
                    }
                }
            }
        }
    }

    private func videoTile(_ item: EduItem?) -> some View {
        Group {
            if let item, let url = URL(string: item.url) {
                Link(destination: url) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .fill(Theme.destructive.opacity(0.12))
                        VStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(Theme.destructive)
                            Text("Watch on YouTube")
                                .font(.system(size: Theme.FontSize.sm, weight: .medium))
                                .foregroundColor(Theme.foreground)
                        }
                    }
                    .frame(height: 160)
                }
            }
        }
    }

    // MARK: Reading Resources card

    private var readingCard: some View {
        FCCard {
            FCCardHeader {
                FCCardTitle("Reading Resources")
                FCCardDescription("Curated articles and guides from trusted experts")
            }
            FCCardContent {
                if articles.isEmpty {
                    Text("No reading resources for this topic yet.")
                        .font(.system(size: Theme.FontSize.sm))
                        .foregroundColor(Theme.mutedForeground)
                } else {
                    pagedContent(
                        index: $articleIndex,
                        count: articles.count,
                        title: articles[safe: articleIndex]?.title ?? ""
                    ) {
                        articleTile(articles[safe: articleIndex])
                    }
                }
            }
        }
    }

    private func articleTile(_ item: EduItem?) -> some View {
        Group {
            if let item, let url = URL(string: item.url) {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        Image(systemName: "book")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.primary)
                        Text("Click to read more")
                            .font(.system(size: Theme.FontSize.sm))
                            .foregroundColor(Theme.mutedForeground)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(Theme.mutedForeground)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: Paging shell (prev/next + "n / total" counter)

    @ViewBuilder
    private func pagedContent<TileContent: View>(
        index: Binding<Int>,
        count: Int,
        title: String,
        @ViewBuilder tile: () -> TileContent
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                FCButton(variant: .ghost, size: .icon) {
                    Image(systemName: "chevron.left")
                } action: {
                    index.wrappedValue = max(0, index.wrappedValue - 1)
                }
                .disabled(index.wrappedValue == 0)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: Theme.FontSize.base, weight: .semibold))
                        .foregroundColor(Theme.cardForeground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    tile()
                }
                .frame(maxWidth: .infinity)

                FCButton(variant: .ghost, size: .icon) {
                    Image(systemName: "chevron.right")
                } action: {
                    index.wrappedValue = min(count - 1, index.wrappedValue + 1)
                }
                .disabled(index.wrappedValue == count - 1)
            }

            Text("\(index.wrappedValue + 1) / \(count)")
                .font(.system(size: Theme.FontSize.sm))
                .foregroundColor(Theme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Safe index helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EducationView()
    }
}
