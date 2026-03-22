// UnitTests/UI/RootViewTests.swift
import Testing
import ViewInspector
import SwiftUI
@testable import WorkoutsApp

@MainActor
@Suite struct RootViewTests {

    @Test func showsProgressViewWhileLoading() async throws {
        let sut = RootView(launchState: .isLoading(last: nil, cancelBag: .test))
        try await ViewHosting.host(sut) {
            try await sut.inspection.inspect { view in
                #expect(throws: Never.self) { try view.find(ViewType.ProgressView.self) }
            }
        }
    }

    @Test func showsErrorViewOnFailure() async throws {
        let sut = RootView(launchState: .failed(NSError.test))
        try await ViewHosting.host(sut) {
            try await sut.inspection.inspect { view in
                #expect(throws: Never.self) { try view.find(text: "Unable to load database") }
                #expect(throws: Never.self) { try view.find(button: "Retry") }
            }
        }
    }

    @Test func showsErrorDescriptionOnFailure() async throws {
        let error = NSError(domain: "test", code: 42,
                            userInfo: [NSLocalizedDescriptionKey: "Disk full"])
        let sut = RootView(launchState: .failed(error))
        try await ViewHosting.host(sut) {
            try await sut.inspection.inspect { view in
                #expect(throws: Never.self) { try view.find(text: "Disk full") }
            }
        }
    }
}
