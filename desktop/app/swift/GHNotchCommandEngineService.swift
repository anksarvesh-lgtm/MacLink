import Foundation

@objc public final class GHNotchCommandEngineService: NSObject, @unchecked Sendable {
    public static let shared = GHNotchCommandEngineService()

    public struct CommandResponse: Sendable {
        public let input: String
        public let output: String
        public let handledLocally: Bool
        public let timestamp: TimeInterval
    }

    public private(set) var lastResponse: CommandResponse?

    private override init() {
        super.init()
    }

    public func start() {
        // Ready
    }

    public func executeCommand(_ rawInput: String) -> String {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return "" }

        let result = evaluate(input)
        let response = CommandResponse(
            input: input,
            output: result.output,
            handledLocally: result.handledLocally,
            timestamp: Date().timeIntervalSince1970
        )
        self.lastResponse = response
        return result.output
    }

    private func evaluate(_ input: String) -> (output: String, handledLocally: Bool) {
        let lowered = input.lowercased()

        if lowered == "help" {
            return ("Commands: calc (e.g. 12 * 8), count <text>, upper <text>, lower <text>, reverse <text>, base64 <text>, timer <duration>", true)
        }
        if lowered == "date" || lowered == "time" || lowered == "now" {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .medium
            return (df.string(from: Date()), true)
        }
        if let rest = remainder(after: "count ", in: input) ?? remainder(after: "wc ", in: input) {
            let words = rest.split { $0.isWhitespace }.count
            let characters = rest.count
            return ("\(words) words · \(characters) characters", true)
        }
        if let rest = remainder(after: "upper ", in: input) {
            return (rest.uppercased(), true)
        }
        if let rest = remainder(after: "lower ", in: input) {
            return (rest.lowercased(), true)
        }
        if let rest = remainder(after: "reverse ", in: input) {
            return (String(rest.reversed()), true)
        }
        if let rest = remainder(after: "base64 ", in: input) {
            return (Data(rest.utf8).base64EncodedString(), true)
        }
        if let rest = remainder(after: "unbase64 ", in: input) {
            guard let data = Data(base64Encoded: rest),
                  let str = String(data: data, encoding: .utf8) else {
                return ("Invalid base64", true)
            }
            return (str, true)
        }

        // Percentage: e.g. "15% of 200" or "20% off 50"
        if let pct = evaluatePercentage(input) {
            return (pct, true)
        }

        // Arithmetic expression evaluation via NSExpression
        if let math = evaluateMath(input) {
            return (math, true)
        }

        // Natural language timer e.g. "timer 5m", "timer 30s"
        if let rest = remainder(after: "timer ", in: input) {
            return ("Timer started for \(rest)", true)
        }

        return ("AI Query: \"\(input)\" (Dispatched to MacLink Assistant)", false)
    }

    private func remainder(after prefix: String, in input: String) -> String? {
        guard input.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
        let idx = input.index(input.startIndex, offsetBy: prefix.count)
        return String(input[idx...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func evaluatePercentage(_ input: String) -> String? {
        let pattern = #"^(\d+(?:\.\d+)?)\s*%\s*(?:of|off)\s*(\d+(?:\.\d+)?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }
        guard let r1 = Range(match.range(at: 1), in: input),
              let r2 = Range(match.range(at: 2), in: input),
              let p = Double(input[r1]),
              let v = Double(input[r2]) else { return nil }

        let result = (p / 100.0) * v
        return formatNumber(result)
    }

    private func evaluateMath(_ input: String) -> String? {
        // Disallow arbitrary letters to prevent code execution
        let allowed = CharacterSet(charactersIn: "0123456789+-*/()., ^%")
        guard input.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        // Sanitize for NSExpression
        let sanitized = input.replacingOccurrences(of: "×", with: "*")
                             .replacingOccurrences(of: "÷", with: "/")
                             .replacingOccurrences(of: "^", with: "**")

        let expr = NSExpression(format: sanitized)
        if let val = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            return formatNumber(val.doubleValue)
        }
        return nil
    }

    private func formatNumber(_ num: Double) -> String {
        if num.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", num)
        } else {
            return String(format: "%.2f", num)
        }
    }

    public func getLastResultJson() -> String {
        guard let resp = lastResponse else {
            return """
            {"hasResult":false,"input":"","output":"","handledLocally":true,"timestamp":0.0}
            """
        }
        let escInput = resp.input.replacingOccurrences(of: "\"", with: "\\\"")
        let escOutput = resp.output.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")

        return """
        {"hasResult":true,"input":"\(escInput)","output":"\(escOutput)","handledLocally":\(resp.handledLocally),"timestamp":\(resp.timestamp)}
        """
    }
}
