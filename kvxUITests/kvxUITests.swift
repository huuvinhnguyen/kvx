//
//  kvxUITests.swift
//  kvxUITests
//
//  Created by Vinh Nguyen on 21/4/26.
//

import XCTest

final class kvxUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testSessionGateAndLogoutNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        let login = app.navigationBars["Đăng nhập Binblog"]
        let devices = app.navigationBars["Devices"]
        XCTAssertTrue(login.waitForExistence(timeout: 5) || devices.waitForExistence(timeout: 5))
        if devices.exists {
            app.buttons["Tài khoản"].tap()
            app.buttons["Đăng xuất"].tap()
        }
        XCTAssertTrue(login.waitForExistence(timeout: 5))
        XCTAssertFalse(devices.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
