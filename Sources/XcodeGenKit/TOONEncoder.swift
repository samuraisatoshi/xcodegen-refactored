import Foundation

/// Encodes a [String: Any] dictionary to TOON (Token-Optimized Object Notation).
/// TOON spec: https://toonformat.dev/reference/spec.html
///
/// Rules:
/// - Objects: `key: value` lines, nested with 2-space indent
/// - Primitive arrays: `key[N]: v1,v2,v3`
/// - Tabular arrays (uniform-keyed objects): `key[N]{f1,f2}:\n  v1,v2`
/// - Mixed arrays: `key[N]:\n  - item`
/// - Empty arrays: `key[0]:`
public struct TOONEncoder {

    public init() {}

    /// Encodes a top-level dictionary to TOON string.
    public func encode(_ dict: [String: Any]) -> String {
        encodeObject(dict, indent: 0)
    }

    // MARK: - Core encoding

    private func encodeObject(_ dict: [String: Any], indent: Int) -> String {
        var lines: [String] = []

        for key in dict.keys.sorted() {
            let value = dict[key]!
            lines.append(contentsOf: encodePair(key: key, value: value, indent: indent))
        }

        return lines.joined(separator: "\n")
    }

    private func encodePair(key: String, value: Any, indent: Int) -> [String] {
        let pad = String(repeating: " ", count: indent)
        let quotedKey = quoteIfNeeded(key)

        // Nested object
        if let nested = value as? [String: Any] {
            if nested.isEmpty {
                return ["\(pad)\(quotedKey):"]
            }
            var result = ["\(pad)\(quotedKey):"]
            result.append(encodeObject(nested, indent: indent + 2))
            return result
        }

        // Array
        if let array = value as? [Any] {
            return encodeArray(key: quotedKey, array: array, indent: indent)
        }

        // Scalar
        return ["\(pad)\(quotedKey): \(encodeScalar(value))"]
    }

    // MARK: - Array encoding

    private func encodeArray(key: String, array: [Any], indent: Int) -> [String] {
        let pad = String(repeating: " ", count: indent)
        let n = array.count

        // Empty array
        if n == 0 {
            return ["\(pad)\(key)[0]:"]
        }

        // Primitive array: all scalars
        if array.allSatisfy({ isScalar($0) }) {
            let values = array.map { encodeScalar($0) }.joined(separator: ",")
            return ["\(pad)\(key)[\(n)]: \(values)"]
        }

        // Tabular array: all dicts with same keys
        if let dicts = array as? [[String: Any]],
           let firstKeys = dicts.first?.keys.sorted(),
           !firstKeys.isEmpty,
           dicts.allSatisfy({ Set($0.keys) == Set(firstKeys) }) {

            let fields = firstKeys.joined(separator: ",")
            var result = ["\(pad)\(key)[\(n)]{\(fields)}:"]
            for dict in dicts {
                let row = firstKeys.map { k in
                    let v = dict[k]!
                    if let nested = v as? [String: Any], nested.isEmpty { return "" }
                    return encodeScalar(v)
                }.joined(separator: ",")
                result.append("\(pad)  \(row)")
            }
            return result
        }

        // Mixed array
        var result = ["\(pad)\(key)[\(n)]:"]
        for item in array {
            if let dict = item as? [String: Any] {
                // First key on same line as dash, rest indented
                let keys = dict.keys.sorted()
                if let first = keys.first {
                    let firstLine = "\(pad)  - \(quoteIfNeeded(first)): \(encodeScalar(dict[first]!))"
                    result.append(firstLine)
                    for k in keys.dropFirst() {
                        result.append(contentsOf: encodePair(key: k, value: dict[k]!, indent: indent + 4))
                    }
                }
            } else {
                result.append("\(pad)  - \(encodeScalar(item))")
            }
        }
        return result
    }

    // MARK: - Scalar encoding

    private func encodeScalar(_ value: Any) -> String {
        switch value {
        case is NSNull:
            return "null"
        case let b as Bool:
            return b ? "true" : "false"
        case let i as Int:
            return String(i)
        case let d as Double:
            if d.isNaN || d.isInfinite { return "null" }
            return d.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(d))
                : String(d)
        case let s as String:
            return quoteIfNeeded(s)
        default:
            return quoteIfNeeded(String(describing: value))
        }
    }

    private func isScalar(_ value: Any) -> Bool {
        switch value {
        case is Bool, is Int, is Double, is String, is NSNull: return true
        default:
            if value is [Any] || value is [String: Any] { return false }
            return true
        }
    }

    // MARK: - Quoting

    /// Quotes a string if it contains characters that would be ambiguous in TOON.
    public func quoteIfNeeded(_ s: String) -> String {
        guard !s.isEmpty else { return "\"\"" }

        let mustQuote =
            s == "true" || s == "false" || s == "null" ||    // keywords
            s == "-" ||                                        // list marker
            looksLikeNumber(s) ||                             // numeric literal
            s.contains(":") || s.contains(",") ||
            s.contains("\"") || s.contains("\\") ||
            s.contains("[") || s.contains("]") ||
            s.contains("{") || s.contains("}") ||
            s.contains("\n") || s.contains("\t") || s.contains("\r") ||
            s.hasPrefix(" ") || s.hasSuffix(" ")

        guard mustQuote else { return s }
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private func looksLikeNumber(_ s: String) -> Bool {
        // Starts with digit, or minus followed by digit
        guard let first = s.first else { return false }
        if first.isNumber { return true }
        if first == "-", let second = s.dropFirst().first, second.isNumber { return true }
        return false
    }
}
