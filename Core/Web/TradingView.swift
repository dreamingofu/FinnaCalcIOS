//
//  TradingView.swift
//  FinnaCalcIOS
//
//  TradingView widgets wrapped in WKWebView (no free native iOS SDK). Ports
//  tradingview-chart.tsx (tv.js Advanced Chart), tradingview-mini.tsx
//  (mini symbol overview), and tradingview-news.tsx (timeline) by loading the
//  same widget scripts in a web view — the Phase 5 plan's "Plan A".
//

import SwiftUI
import WebKit

// MARK: - WKWebView host

/// Loads an HTML string once and reloads only when it changes.
struct TradingViewWebView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.tradingview.com"))
    }

    final class Coordinator {
        var lastHTML: String?
    }
}

// MARK: - HTML builders

enum TradingViewHTML {
    static func advancedChart(symbol: String, theme: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>html,body{margin:0;padding:0;height:100%;background:transparent;}#tv{height:100vh;width:100%;}</style>
        </head><body>
        <div id="tv"></div>
        <script src="https://s3.tradingview.com/tv.js"></script>
        <script>
        new TradingView.widget({autosize:true,symbol:"\(symbol)",interval:"D",timezone:"Etc/UTC",theme:"\(theme)",style:"1",locale:"en",enable_publishing:false,allow_symbol_change:true,hide_side_toolbar:false,withdateranges:true,container_id:"tv"});
        </script>
        </body></html>
        """
    }

    static func mini(symbol: String, theme: String, height: Int) -> String {
        embed(
            script: "embed-widget-mini-symbol-overview.js",
            config: #"{"symbol":"\#(symbol)","width":"100%","height":\#(height),"locale":"en","dateRange":"1M","colorTheme":"\#(theme)","isTransparent":true,"autosize":false,"largeChartUrl":""}"#
        )
    }

    static func news(theme: String, height: Int) -> String {
        embed(
            script: "embed-widget-timeline.js",
            config: #"{"feedMode":"market","market":"stock","isTransparent":true,"displayMode":"regular","width":"100%","height":\#(height),"colorTheme":"\#(theme)","locale":"en"}"#
        )
    }

    private static func embed(script: String, config: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>html,body{margin:0;padding:0;background:transparent;}</style>
        </head><body>
        <div class="tradingview-widget-container">
        <script type="text/javascript" src="https://s3.tradingview.com/external-embedding/\(script)">
        \(config)
        </script>
        </div>
        </body></html>
        """
    }
}

// MARK: - SwiftUI convenience views (theme follows the color scheme)

struct TradingViewChart: View {
    let symbol: String
    var height: CGFloat = 460
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        TradingViewWebView(html: TradingViewHTML.advancedChart(symbol: symbol, theme: scheme == .dark ? "dark" : "light"))
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}

struct TradingViewMini: View {
    let symbol: String
    var height: CGFloat = 140
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        TradingViewWebView(html: TradingViewHTML.mini(symbol: symbol, theme: scheme == .dark ? "dark" : "light", height: Int(height)))
            .frame(height: height)
    }
}

struct TradingViewNews: View {
    var height: CGFloat = 600
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        TradingViewWebView(html: TradingViewHTML.news(theme: scheme == .dark ? "dark" : "light", height: Int(height)))
            .frame(height: height)
    }
}
