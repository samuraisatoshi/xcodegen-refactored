import Foundation

/// Structured guidance emitted by `--guide` for consumption by LLM agents and MCP servers.
struct CommandGuide: Encodable {
    /// Short command name (e.g. "generate").
    let command: String
    /// One-sentence purpose of the command.
    let purpose: String
    /// Dense summary for an agent deciding which command to call.
    let agentSummary: String
    /// Situations where this command should be invoked.
    let whenToUse: [String]
    /// Ordered steps the command executes internally.
    let workflow: [String]
    /// All accepted flags and keys.
    let parameters: [Parameter]
    /// Concrete invocation examples with expected output snippets.
    let examples: [Example]
    /// Known failure modes with causes and remediation.
    let commonErrors: [CommonError]
    /// Other commands relevant to this one.
    let relatedCommands: [String]

    struct Parameter: Encodable {
        /// CLI flag name (e.g. "--spec").
        let name: String
        let required: Bool
        /// "flag" | "key" — flag is boolean, key takes a value.
        let kind: String
        let description: String
        let defaultValue: String?
        let example: String?
    }

    struct Example: Encodable {
        let description: String
        let command: String
        let expectedOutput: String?
    }

    struct CommonError: Encodable {
        let error: String
        let cause: String
        let fix: String
    }
}

extension CommandGuide {
    /// Serialise to pretty-printed JSON suitable for stdout.
    func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
