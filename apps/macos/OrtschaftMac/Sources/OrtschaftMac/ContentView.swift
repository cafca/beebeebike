import SwiftUI
// import OrtschaftCore

public struct ContentView: View {
    public init() {}

    @State private var input: String = ""
    @State private var syncResult: String = ""
    @State private var asyncResult: String = ""
    @State private var errorMessage: String?
    @State private var isCallingAsync: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ortschaft macOS UniFFI Demo")
                .font(.title)

            TextField("Enter text to echo", text: $input)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.trailing)

            HStack {
                Button("Sync Echo") {
                    callSyncEcho()
                }
                Button(isCallingAsync ? "Async Echo…" : "Async Echo") {
                    callAsyncEcho()
                }
                .disabled(isCallingAsync)
            }

            if !syncResult.isEmpty {
                Text("Sync result: \(syncResult)")
            }
            if !asyncResult.isEmpty {
                Text("Async result: \(asyncResult)")
            }
            if let errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 480, minHeight: 320)
    }

    private func callSyncEcho() {
        // TODO: Wire to OrtschaftCore once UniFFI Swift bindings are available.
        let result = input
        syncResult = result
        errorMessage = nil
    }

    private func callAsyncEcho() {
        isCallingAsync = true
        Task {
            // TODO: Wire to OrtschaftCore once UniFFI Swift bindings are available.
            let result = input
            asyncResult = result
            errorMessage = nil
            isCallingAsync = false
        }
    }
}
