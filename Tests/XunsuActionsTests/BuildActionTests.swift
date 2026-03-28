//
//  BuildActionTests.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Testing
@testable import XunsuActions
@testable import XunsuCore

@Suite("BuildAction Tests")
struct BuildActionTests {
    @Test("Validate requires scheme")
    func testValidateRequiresScheme() throws {
        let action = BuildAction()
        let options = BuildOptions(scheme: "")

        #expect(throws: ActionError.self) {
            try action.validate(options: options)
        }
    }

    @Test("Valid options pass validation")
    func testValidOptionsPass() throws {
        let action = BuildAction()
        let options = BuildOptions(scheme: "MyApp")

        #expect(throws: Never.self) {
            try action.validate(options: options)
        }
    }
}
