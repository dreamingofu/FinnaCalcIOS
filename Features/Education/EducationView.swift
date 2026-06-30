//
//  EducationView.swift
//  FinnaCalcIOS
//

import SwiftUI

struct EducationView: View {
    var body: some View {
        ComingSoonView(
            icon: "book",
            title: "Education",
            message: "The financial-education hub: guides and explainers across budgeting, investing, and taxes.",
            phase: "Coming in Phase 8"
        )
    }
}

#Preview { EducationView() }
