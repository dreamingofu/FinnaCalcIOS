//
//  SnapTradeService.swift
//  FinnaCalcIOS
//
//  SnapTrade brokerage API calls, ported from brokerage-connect.tsx.
//  connect() returns the hosted portal URL to open in SFSafariViewController;
//  after the user links a broker (and dismisses Safari), call accounts().
//

import Foundation

enum SnapTradeService {
    /// POST /api/snaptrade/connect → portal URL (registers the user + sets the
    /// session cookie on first call).
    static func connect() async throws -> URL {
        let response: SnapTradeConnectResponse = try await APIClient.shared.postJSON(
            "/api/snaptrade/connect", body: EmptyBody())
        guard let url = URL(string: response.redirectURI) else {
            throw APIError.message("No connection link returned.")
        }
        return url
    }

    /// GET /api/snaptrade/accounts → connected accounts + positions.
    static func accounts() async throws -> SnapTradeAccountsResponse {
        try await APIClient.shared.getJSON("/api/snaptrade/accounts")
    }

    /// POST /api/snaptrade/disconnect → clears the session cookie.
    static func disconnect() async throws {
        _ = try await APIClient.shared.postData("/api/snaptrade/disconnect", body: EmptyBody())
    }

    private struct EmptyBody: Encodable {}
}
