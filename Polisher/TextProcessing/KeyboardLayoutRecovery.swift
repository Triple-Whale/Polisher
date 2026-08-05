import Foundation

struct KeyboardLayoutRequest {
    let inputText: String
    let systemPrompt: String
}

enum KeyboardLayoutRecovery {
    private static let instructions = """
    <keyboard_layout_recovery>
    Apply this before translation or polishing when the user message contains keyboard-layout alternatives.
    - The candidate is a deterministic conversion to the characters on the same physical keys in the other keyboard layout.
    - Use the English candidate only when the Hebrew-script original is nonsensical and the candidate is clearly coherent English.
    - If the original is coherent Hebrew, ignore the candidate and continue with the normal polishing and translation instructions.
    - Never translate or invent a semantic meaning for a nonsensical original.
    - Return only the polished selected text. Never return the wrapper, labels, or both alternatives.
    </keyboard_layout_recovery>
    """

    private static let keyPairs: [(english: Character, hebrew: Character)] = [
        ("q", "/"), ("w", "'"), ("e", "ק"), ("r", "ר"), ("t", "א"),
        ("y", "ט"), ("u", "ו"), ("i", "ן"), ("o", "ם"), ("p", "פ"),
        ("[", "]"), ("]", "["), ("\\", "\\"),
        ("a", "ש"), ("s", "ד"), ("d", "ג"), ("f", "כ"), ("g", "ע"),
        ("h", "י"), ("j", "ח"), ("k", "ל"), ("l", "ך"), (";", "ף"),
        ("'", ","),
        ("z", "ז"), ("x", "ס"), ("c", "ב"), ("v", "ה"), ("b", "נ"),
        ("n", "מ"), ("m", "צ"), (",", "ת"), (".", "ץ"), ("/", "."),
    ]

    private static let hebrewToEnglish = Dictionary(
        uniqueKeysWithValues: keyPairs.map { ($0.hebrew, $0.english) }
    )

    static func prepare(text: String, systemPrompt: String) -> KeyboardLayoutRequest {
        guard let candidate = candidate(for: text) else {
            return KeyboardLayoutRequest(inputText: text, systemPrompt: systemPrompt)
        }

        let inputText = """
        <keyboard_layout_alternatives>
        <original_text>
        \(text)
        </original_text>
        <candidate target_language="English">
        \(candidate)
        </candidate>
        </keyboard_layout_alternatives>
        """

        return KeyboardLayoutRequest(
            inputText: inputText,
            systemPrompt: systemPrompt + "\n\n" + instructions
        )
    }

    static func candidate(for text: String) -> String? {
        let hebrewLetterCount = text.reduce(into: 0) { count, character in
            if isHebrewLetter(character) {
                count += 1
            }
        }
        let englishLetterCount = text.reduce(into: 0) { count, character in
            if isEnglishLetter(character) {
                count += 1
            }
        }

        if hebrewLetterCount >= 2 && englishLetterCount == 0 {
            return convert(text, using: hebrewToEnglish)
        }

        return nil
    }

    private static func convert(_ text: String, using mapping: [Character: Character]) -> String {
        return String(text.map { mapping[$0] ?? $0 })
    }

    private static func isHebrewLetter(_ character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy { scalar in
            (0x05D0...0x05EA).contains(scalar.value)
        }
    }

    private static func isEnglishLetter(_ character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy { scalar in
            (0x0041...0x005A).contains(scalar.value) ||
                (0x0061...0x007A).contains(scalar.value)
        }
    }
}
