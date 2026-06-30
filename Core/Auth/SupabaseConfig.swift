//
//  SupabaseConfig.swift
//  FinnaCalcIOS
//
//  Supabase project credentials — the iOS equivalent of the web app's
//  NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY (see lib/supabase.ts).
//
//  ┌─ HOW TO CONFIGURE ────────────────────────────────────────────────────────┐
//  │ Paste the two values from Supabase → Settings → API below. The anon key is │
//  │ safe to ship in a client build (row-level security protects your data) —   │
//  │ the website embeds the very same key in its browser bundle.                │
//  │                                                                            │
//  │ While these are empty the app runs fully, just signed-out, and never       │
//  │ crashes — mirroring lib/supabase.ts `isSupabaseConfigured === false`.      │
//  └────────────────────────────────────────────────────────────────────────────┘
//

import Foundation

enum SupabaseConfig {
    /// e.g. "https://abcdefgh.supabase.co"
    static let urlString = ""

    /// The public anon key (Settings → API).
    static let anonKey = ""

    static var url: URL? { URL(string: urlString) }

    /// True only when both values are present and the URL parses — the gate the
    /// rest of the auth layer checks before talking to Supabase.
    static var isConfigured: Bool {
        !urlString.isEmpty && !anonKey.isEmpty && url != nil
    }
}
