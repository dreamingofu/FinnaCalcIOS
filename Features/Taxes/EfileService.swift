//
//  EfileService.swift
//  FinnaCalcIOS
//
//  Client wrapper around the FinnaCalc Next.js e-file endpoint (POST /api/efile).
//  The provider API key lives only on the server; the client just transmits the
//  neutral EfileBundle and surfaces the transmitter's result.
//
//  Mirrors app/api/efile/route.ts: the route returns
//      { provider, status, message, providerRef? }
//  with HTTP 200 for accepted/queued and HTTP 501 for unsupported/rejected.
//  Because APIClient maps every non-2xx response to a thrown APIError, the 501
//  "not supported" stub path is caught here and converted into a normal,
//  non-throwing EfileResult so callers can render the capability-gap message.
//

import Foundation

/// Decoded shape of the /api/efile response.
/// TS route returns: `{ provider, ...EfileSubmissionResult }`, i.e.
/// `{ provider, status, message, providerRef? }`.
public struct EfileResult: Decodable, Equatable {
    public var provider: String?   // absent on the route's 400 path
    public var status: EfileSubmissionStatus
    public var message: String
    public var providerRef: String?

    public init(provider: String? = nil, status: EfileSubmissionStatus, message: String, providerRef: String? = nil) {
        self.provider = provider
        self.status = status
        self.message = message
        self.providerRef = providerRef
    }
}

public enum EfileService {
    /// Submit a computed return's bundle to the server-side e-file endpoint.
    ///
    /// The route returns its `{ provider, status, message, providerRef? }` result
    /// for BOTH success (HTTP 200, accepted/queued) and the structural-stub path
    /// (HTTP 501, unsupported/rejected). We therefore decode the body regardless
    /// of status so the real status (rejected vs unsupported) and the clean
    /// human-readable message are preserved. Only genuine networking/decoding
    /// failures throw.
    public static func submit(_ bundle: EfileBundle) async throws -> EfileResult {
        let (data, status) = try await APIClient.shared.postAllowingErrorStatus("/api/efile", body: bundle)
        if let result = try? JSONDecoder().decode(EfileResult.self, from: data) {
            return result
        }
        throw APIError.from(data: data, status: status)
    }
}
