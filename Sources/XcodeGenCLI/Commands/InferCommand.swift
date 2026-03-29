import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import Version

class InferCommand: ProjectCommand {

    @Key("--xcodeproj", description: "Path to the .xcodeproj to read (auto-detected if omitted)")
    private var xcodeprojPath: String?

    @Key("--output", "-o", description: "Output path for the generated project.yml")
    private var outputPath: String?

    @Flag("--dry-run", description: "Print the inferred YAML to stdout without writing")
    private var dryRun: Bool

    init(version: Version) {
        super.init(version: version,
                   name: "infer",
                   shortDescription: "Generate a project.yml by reading an existing .xcodeproj")
    }

    override func guideContent(locale: GuideLocale) -> CommandGuide {
        InferGuide.content(locale: locale)
    }

    // Fully override execute() — no spec required as input
    override func execute() throws {
        if guide {
            let locale = GuideLocale.resolve(lang)
            stdout.print(try guideContent(locale: locale).jsonString())
            return
        }

        // Locate .xcodeproj
        let projPath: Path
        if let explicit = xcodeprojPath {
            projPath = Path(explicit).absolute()
        } else {
            // Auto-detect: find first .xcodeproj in current directory
            let cwd = Path.current
            let candidates = (try? cwd.children())?.filter { $0.extension == "xcodeproj" } ?? []
            guard let found = candidates.first else {
                throw InferError.noXcodeproj
            }
            projPath = found
        }

        guard projPath.exists else {
            throw InferError.notFound(projPath)
        }

        // Run inferrer
        var inferrer = XcodeProjInferrer(xcodeprojPath: projPath)
        let yamlString: String
        do {
            yamlString = try inferrer.infer()
        } catch {
            throw InferError.readFailed(projPath, error)
        }

        let warnings = inferrer.warnings

        if dryRun {
            stdout.print(yamlString)
            for w in warnings {
                stderr.print("warning: \(w)")
            }
            return
        }

        // Determine output path
        let destination: Path
        if let out = outputPath {
            destination = Path(out).absolute()
        } else {
            destination = projPath.parent() + "project.yml"
        }

        try destination.write(yamlString)

        switch outputFormat {
        case .plain:
            let warnSuffix = warnings.isEmpty ? "" : "\n\(warnings.count) warning(s):"
            success("Inferred \(destination.lastComponent) from \(projPath.lastComponent)\(warnSuffix)")
            for w in warnings { warning(w) }
        case .llm:
            let dict: [String: Any] = [
                "status": "ok",
                "spec": destination.string,
                "warnings": warnings
            ]
            stdout.print(TOONEncoder().encode(dict))
        case .enriched:
            stdout.print(RichFormatter.box(
                title: destination.lastComponent,
                icon: .ok,
                rows: [("Source", projPath.lastComponent)],
                warnings: warnings
            ))
        }
    }

    // Not used — execute() is fully overridden
    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {}
}

// MARK: - Errors

private enum InferError: Error, CustomStringConvertible, ProcessError {
    case noXcodeproj
    case notFound(Path)
    case readFailed(Path, Error)

    var description: String {
        switch self {
        case .noXcodeproj:
            return #"{"error":"no .xcodeproj found in current directory — use --xcodeproj to specify a path"}"#
        case let .notFound(p):
            return #"{"error":"no .xcodeproj found at \#(p.string)"}"#
        case let .readFailed(p, e):
            return #"{"error":"failed to read \#(p.lastComponent): \#(e.localizedDescription)"}"#
        }
    }

    var message: String? { description }
    var exitStatus: Int32 { 1 }
}
