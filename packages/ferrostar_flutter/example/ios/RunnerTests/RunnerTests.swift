import Flutter
import UIKit
import XCTest


@testable import ferrostar_flutter

class RunnerTests: XCTestCase {

  func testSmokeTestReturnsFerrostarSampleLocation() {
    let plugin = FerrostarFlutterPlugin()

    let call = FlutterMethodCall(methodName: "smokeTest", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as? String, "location created at 52.52, 13.405")
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
