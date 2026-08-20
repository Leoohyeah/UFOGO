//
//  UFOGeoUITests.swift
//  UFOGeoUITests
//
//  Created by Stephen on 3/26/25.
//

import XCTest

final class UFOGeoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCoreNavigationIsAvailable() throws {
        let app = XCUIApplication()
        app.launch()

        if app.alerts["需要配對文件"].waitForExistence(timeout: 2) {
            app.alerts["需要配對文件"].buttons["稍後"].tap()
        }

        XCTAssertTrue(app.tabBars.buttons["定位"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["路線"].exists)

        app.tabBars.buttons["路線"].tap()
        XCTAssertTrue(app.staticTexts["尚未建立路線"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
