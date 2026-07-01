//
//  FontRegistration.swift
//  FinnaCalcIOS
//
//  Registers the bundled IBM Plex fonts (App/Fonts/*.ttf) with CoreText at
//  launch, so `Font.custom("IBMPlexSans-…" / "IBMPlexMono-…", …)` resolves to
//  the real faces. Programmatic registration avoids an Info.plist UIAppFonts
//  entry. If a face is missing, SwiftUI's Font.custom falls back to the system
//  font automatically.
//

import Foundation
import CoreText

/// Register every bundled IBM Plex TTF. Safe to call once at app launch.
func registerBundledFonts() {
    let faces = [
        "IBMPlexSans-Regular", "IBMPlexSans-Medium", "IBMPlexSans-SemiBold", "IBMPlexSans-Bold",
        "IBMPlexMono-Regular", "IBMPlexMono-Medium", "IBMPlexMono-SemiBold",
    ]
    for face in faces {
        guard let url = Bundle.main.url(forResource: face, withExtension: "ttf") else { continue }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
