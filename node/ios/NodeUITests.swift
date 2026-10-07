import XCTest

final class NodeUITests:XCTestCase {
    private func launch(_ scenario:String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ATTESTNODE_UI_SCENARIO"] = scenario
        app.launch()
        XCTAssertTrue(app.staticTexts["SIMULATOR SCENARIO — no hardware attestation or NFT transaction"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["SIMULATOR SCENARIO — no hardware attestation or NFT transaction"].isHittable)
        return app
    }
    private func capture(_ label:String) {
        let evidence = XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        evidence.name = label;evidence.lifetime = .keepAlways;add(evidence)
    }
    func testUnsupportedSimulatorAndPersistentIdentity() throws {
        let app = XCUIApplication()
        func participant() throws -> String {
            app.launch()
            XCTAssertTrue(app.staticTexts["Couldn’t join the network"].waitForExistence(timeout:10))
            app.buttons["Technical details"].tap()
            let report = app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@", "appAttestSupported")).firstMatch.label
            let events = try report.split(separator:"\n").map {try JSONSerialization.jsonObject(with:Data($0.utf8)) as! [String:Any]}
            XCTAssertTrue(events.contains {($0["appAttestSupported"] as? Bool) == false})
            XCTAssertFalse(events.contains {$0["event"] as? String == "badge claimed"})
            return try XCTUnwrap(events.first {$0["event"] as? String == "configured"}?["participant"] as? String)
        }
        let first = try participant()
        capture("REAL-simulator-unsupported")
        app.terminate()
        XCTAssertEqual(try participant(),first,"Restart must retain participant identity")
    }
    func testAttesting() {
        let app = launch("attesting")
        XCTAssertTrue(app.staticTexts["Verifying this app…"].exists)
        XCTAssertFalse(app.buttons["Listen"].exists)
        XCTAssertFalse(app.textViews.firstMatch.exists)
        capture("SIMULATED-attesting")
    }
    func testClaimed() {
        let app = launch("claimed")
        XCTAssertTrue(app.staticTexts["You’re connected"].exists)
        XCTAssertTrue(app.staticTexts["Participant NFT #42 confirmed"].exists)
        capture("SIMULATED-claimed")
    }
    func testRetry() {
        let app = launch("retry")
        XCTAssertTrue(app.staticTexts["Waiting to reconnect…"].exists)
        capture("SIMULATED-retry")
    }
    func testFailureReport() {
        let app = launch("apple-failure")
        XCTAssertTrue(app.staticTexts["Couldn’t join the network"].exists)
        app.buttons["Technical details"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@", "attestKey")).firstMatch.exists)
        capture("SIMULATED-apple-failure-details")
        app.buttons["Technical details"].tap()
        app.buttons["Share diagnostic report"].tap()
        XCTAssertTrue(app.cells["Copy"].waitForExistence(timeout:5))
        capture("SIMULATED-share-report")
        app.cells["Copy"].tap()
    }
}
