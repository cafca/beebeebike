#if os(iOS)
import SwiftUI

@available(iOS 17.0, *)
@main
struct OrtschaftIOSApp: App {
    var body: some Scene {
        WindowGroup {
            IOSContentView()
        }
    }
}
#else
print("OrtschaftiOS SwiftPM smoke build host stub")
#endif
