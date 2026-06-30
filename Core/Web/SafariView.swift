//
//  SafariView.swift
//  FinnaCalcIOS
//
//  SFSafariViewController wrapper for SwiftUI — used to open the SnapTrade
//  hosted connection portal. The user links a broker, then taps Done; the
//  caller refreshes accounts on dismiss.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
