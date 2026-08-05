import Foundation

@main
struct KeyboardLayoutRecoveryTests {
    static func main() {
        expectCandidate(input: "גןג טםו דאשרא שמםאיקר נשאבי?", expected: "did you start another batch?")
        expectCandidate(input: "אפשר להתחיל מחר?", expected: "tpar kv,jhk njr?")
        expect(KeyboardLayoutRecovery.candidate(for: "Hello שלום") == nil, "Mixed scripts should not be converted")
        expect(KeyboardLayoutRecovery.candidate(for: "Polish this text") == nil, "English text should not be wrapped")

        let request = KeyboardLayoutRecovery.prepare(
            text: "גןג טםו דאשרא שמםאיקר נשאבי?",
            systemPrompt: "Polish the text and return only the result."
        )
        expect(request.inputText.contains("did you start another batch?"), "Request should include the exact candidate")
        expect(request.systemPrompt.contains("Never translate or invent"), "Request should include recovery instructions")

        let unchangedRequest = KeyboardLayoutRecovery.prepare(
            text: "Polish this text",
            systemPrompt: "Polish the text and return only the result."
        )
        expect(unchangedRequest.inputText == "Polish this text", "English input should remain unchanged")
        expect(
            unchangedRequest.systemPrompt == "Polish the text and return only the result.",
            "English requests should not add recovery instructions"
        )

        print("KeyboardLayoutRecovery tests passed")
    }

    private static func expectCandidate(input: String, expected: String) {
        let candidate = KeyboardLayoutRecovery.candidate(for: input)
        expect(candidate == expected, "Unexpected candidate for \(input)")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Test failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
