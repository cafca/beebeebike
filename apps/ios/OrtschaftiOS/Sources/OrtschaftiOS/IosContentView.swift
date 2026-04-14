#if os(iOS)
import SwiftUI

@available(iOS 17.0, *)
public struct IOSContentView: View {
    public init() {}

    @State private var input: String = ""
    @State private var syncResult: String = ""
    @State private var asyncResult: String = ""
    @State private var errorMessage: String?
    @State private var isCallingAsync: Bool = false

    public var body: some View {
        NavigationStack {
            Form {
                Section("Input") {
                    TextField("Enter text to echo", text: $input)
                }

                Section("Actions") {
                    Button("Sync Echo") {
                        callSyncEcho()
                    }
                    Button(isCallingAsync ? "Async Echo…" : "Async Echo") {
                        callAsyncEcho()
                    }
                    .disabled(isCallingAsync)
                }

                if !syncResult.isEmpty {
                    Section("Sync Result") {
                        Text(syncResult)
                    }
                }

                if !asyncResult.isEmpty {
                    Section("Async Result") {
                        Text(asyncResult)
                    }
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Ortschaft iOS")
        }
    }

    private func callSyncEcho() {
        // TODO: Wire to shared UniFFI Swift bindings when available.
        let result = input
        syncResult = result
        errorMessage = nil
    }

    private func callAsyncEcho() {
        isCallingAsync = true
        Task {
            // TODO: Wire to shared UniFFI Swift bindings when available.
            let result = input
            await MainActor.run {
                asyncResult = result
                errorMessage = nil
                isCallingAsync = false
            }
        }
    }
}
#endif
