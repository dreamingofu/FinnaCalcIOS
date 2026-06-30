//
//  PlaidLink.swift
//  FinnaCalcIOS
//
//  Presents Plaid Link (LinkKit) from SwiftUI. LinkKit ships no SwiftUI API, so
//  this wraps `Plaid.create` + `handler.open(presentUsing: .viewController(...))`
//  and presents from the current top view controller. The handler is retained
//  for the duration of the flow.
//
//  Guarded with `#if canImport(LinkKit)` so the app still builds if the package
//  is ever absent (the flow then just reports an exit).
//
//  Requires PLAID_CLIENT_ID / PLAID_SECRET configured on the API side; the link
//  token is created server-side via PlaidService.
//

import SwiftUI

#if canImport(LinkKit)
import LinkKit
import UIKit

@MainActor
final class PlaidLinkCoordinator: ObservableObject {
    private var handler: Handler?

    /// Open Plaid Link for the given link token. `onSuccess` receives the public
    /// token to exchange server-side; `onExit` fires if the user backs out or
    /// the handler can't be created.
    func open(linkToken: String,
              onSuccess: @escaping (String) -> Void,
              onExit: @escaping () -> Void) {
        var configuration = LinkTokenConfiguration(token: linkToken) { success in
            onSuccess(success.publicToken)
        }
        configuration.onExit = { _ in onExit() }

        switch Plaid.create(configuration) {
        case .success(let handler):
            self.handler = handler
            guard let presenter = Self.topViewController() else {
                onExit()
                return
            }
            handler.open(presentUsing: .viewController(presenter))
        case .failure:
            onExit()
        }
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

#else

@MainActor
final class PlaidLinkCoordinator: ObservableObject {
    func open(linkToken: String,
              onSuccess: @escaping (String) -> Void,
              onExit: @escaping () -> Void) {
        onExit()
    }
}

#endif
