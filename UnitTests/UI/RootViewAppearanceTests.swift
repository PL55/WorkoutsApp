// UnitTests/UI/RootViewAppearanceTests.swift
import Testing
import SwiftUI
import ViewInspector
@testable import WorkoutsApp

@MainActor
@Suite struct RootViewAppearanceTests {

    @Test func appliesModifierWithoutCrash() async throws {
        let sut = RootViewAppearance()
        let container = DIContainer(interactors: .mocked())
        let view = EmptyView().modifier(sut)
            .inject(container)
        try await ViewHosting.host(view) {
            try await sut.inspection.inspect { modifier in
                _ = try modifier.implicitAnyView().viewModifierContent()
            }
        }
    }
}
