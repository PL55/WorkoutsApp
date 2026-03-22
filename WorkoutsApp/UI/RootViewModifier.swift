// WorkoutsApp/UI/RootViewModifier.swift
import SwiftUI

struct RootViewAppearance: ViewModifier {
    internal let inspection = Inspection<Self>()

    func body(content: Content) -> some View {
        content
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
}
