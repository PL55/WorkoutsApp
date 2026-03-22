//
//  HelpersTests.swift
//  UnitTests
//
//  Created by Alexey Naumov on 27.04.2020.
//  Copyright © 2020 Alexey Naumov. All rights reserved.
//

import Foundation
import Testing
@testable import WorkoutsApp

@Suite struct HelpersTests {

    @Test func localizedDefaultLocale() {
        let sut = "Countries".localized(Locale.backendDefault)
        #expect(sut == "Countries")
    }

    @Test func localizedKnownLocale() {
        let sut = "Countries".localized(Locale(identifier: "de"))
        #expect(sut == "Länder")
    }

    @Test func localizedUnknownLocale() {
        let sut = "Countries".localized(Locale(identifier: "ch"))
        #expect(sut == "Countries")
    }

    @Test func resultIsSuccess() {
        let sut1 = Result<Void, Error>.success(())
        let sut2 = Result<Void, Error>.failure(NSError.test)
        #expect(sut1.isSuccess)
        #expect(!sut2.isSuccess)
    }
}

@Suite struct ExerciseTypeTests {
    @Test func rawValues() {
        #expect(ExerciseType.strength.rawValue == "strength")
        #expect(ExerciseType.cardio.rawValue == "cardio")
    }

    @Test func allCases() {
        #expect(ExerciseType.allCases.count == 2)
    }
}

@Suite struct ExerciseInputTests {
    @Test func strengthNameExtraction() {
        let input = ExerciseInput.strength(name: "Bench Press", sets: 3, reps: 10, weight: 80.0)
        #expect(input.name == "Bench Press")
        #expect(input.exerciseType == .strength)
    }

    @Test func cardioNameExtraction() {
        let input = ExerciseInput.cardio(name: "Running", durationMinutes: 30.0)
        #expect(input.name == "Running")
        #expect(input.exerciseType == .cardio)
    }
}
