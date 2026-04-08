import Foundation

/// Handles username content safety checking via local term lists and PurgoMalum API
class ProfanityFilter {

    /// Reserved system terms that shouldn't be used as usernames
    static let reservedTerms = [
        "admin", "administrator", "mod", "moderator", "system", "official",
        "chordcrack", "support", "help", "test", "demo", "null", "undefined",
        "anonymous", "user", "player", "bot", "ai", "computer", "cpu",
        "staff", "team", "dev", "developer", "root", "superuser"
    ]

    /// Additional inappropriate terms that PurgoMalum might miss
    private static let inappropriateTerms = [
        // Anatomical/Sexual terms
        "penis", "vagina", "dick", "cock", "pussy", "boob", "tit", "breast",
        "testicle", "balls", "anus", "rectum", "genital", "nipple", "clitoris",
        "erection", "orgasm", "masturbat", "ejaculat", "semen", "sperm",

        // Sexual acts/content
        "sex", "porn", "nude", "naked", "xxx", "nsfw", "hentai", "fetish",
        "bdsm", "dildo", "vibrator", "condom", "lubricant", "69", "420",

        // Drug references
        "cocaine", "heroin", "meth", "crack", "weed", "marijuana", "cannabis",
        "ecstasy", "molly", "lsd", "acid", "shroom", "drug", "dealer",

        // Violence/Death
        "kill", "murder", "suicide", "death", "die", "dead", "shoot", "stab",
        "rape", "assault", "abuse", "torture", "terrorist", "bomb", "weapon",

        // Hate/Discrimination
        "nazi", "hitler", "kkk", "isis", "jihad", "racist", "sexist",
        "homophob", "transphob", "xenophob", "bigot", "supremac",

        // Bodily functions
        "poop", "pee", "urine", "feces", "defecate", "urinate", "fart",
        "diarrhea", "vomit", "puke", "menstruat", "period", "tampon",

        // Variations and l33t speak
        "p3nis", "pen1s", "pen!s", "d1ck", "d!ck", "c0ck", "puss", "b00b",
        "s3x", "pr0n", "p0rn", "fuk", "fck", "wtf", "stfu", "gtfo"
    ]

    private static let apiTimeoutSeconds: TimeInterval = 5.0

    /// Check text against local inappropriate terms and PurgoMalum API.
    /// Returns `true` if the text is clean, `false` if it contains profanity.
    /// Local checks always run. If the remote API is unreachable, allows the username
    /// through (local checks already caught the worst offenders).
    static func isClean(_ text: String) async -> Bool {
        let lowercased = text.lowercased()

        // Check for substring matches with inappropriate terms
        for term in inappropriateTerms {
            if lowercased.contains(term.lowercased()) {
                return false
            }
        }

        // Check normalized version (spaces, underscores, dashes removed)
        let normalized = lowercased
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")

        for term in inappropriateTerms {
            let normalizedTerm = term.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")

            if normalized.contains(normalizedTerm) {
                return false
            }
        }

        // Check with PurgoMalum API (fail-open if API is unreachable since
        // local checks above already cover the most important cases)
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.purgomalum.com/service/containsprofanity?text=\(encodedText)"

        guard let url = URL(string: urlString) else {
            return true // Local checks passed, allow if URL can't be constructed
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = apiTimeoutSeconds

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return true // API error — local checks passed, allow
            }

            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result != "true"
        } catch {
            return true // Network error — local checks passed, allow
        }
    }

    /// Check if a username matches a reserved system term
    static func isReserved(_ username: String) -> Bool {
        let lowercased = username.lowercased()
        return reservedTerms.contains { lowercased == $0 || lowercased.hasPrefix($0) }
    }
}
