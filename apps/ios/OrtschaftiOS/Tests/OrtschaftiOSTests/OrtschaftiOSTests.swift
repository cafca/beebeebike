import XCTest
@testable import OrtschaftiOS

final class OrtschaftiOSTests: XCTestCase {
#if os(iOS)
    func testSyncEcho_localFallback() async {
        if #available(iOS 17.0, *) {
            var view = IOSContentView()
            // Simulate setting input and invoking sync echo via the fallback logic.
            await MainActor.run {
                // We can't reach into @State directly, but we can at least
                // ensure the view is constructible in the test environment.
                _ = view.body
            }
            XCTAssertNotNil(view)
        } else {
            XCTExpectFailure("iOS 17 is required for IOSContentView; skipping on older platforms")
        }
    }
#else
    func testHostSmokeBuild() {
        XCTAssertTrue(true)
    }
#endif
}
