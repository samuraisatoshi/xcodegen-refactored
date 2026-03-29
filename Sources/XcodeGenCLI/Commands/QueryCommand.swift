import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import Version
import XcodeGenKit
import XcodeProj

class QueryCommand: ProjectCommand {

    @Key("--type", "-t", description: "Query type. One of: targets, target, sources, settings, dependencies. Defaults to targets.")
    private var queryType: QueryType?

    @Key("--name", "-n", description: "Target name. Required for: target, sources, settings, dependencies.")
    private var targetName: String?

    @Key("--config", description: "Config name for settings queries (e.g. Debug, Release).")
    private var config: String?

    init(version: Version) {
        super.init(version: version,
                   name: "query",
                   shortDescription: "Query the resolved project spec and return focused JSON")
    }

    override func guideContent(locale: GuideLocale) -> CommandGuide {
        QueryGuide.content(locale: locale)
    }

    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {
        let type = queryType ?? .targets

        switch type {
        case .targets:
            let summaries = project.targets.map { TargetSummary(name: $0.name,
                                                                 type: $0.type.name,
                                                                 platform: $0.platform.rawValue) }
            switch outputFormat {
            case .plain:
                success(try encode(summaries))
            case .llm:
                let dict: [String: Any] = [
                    "targets": summaries.map { ["name": $0.name, "type": $0.type, "platform": $0.platform] as [String: Any] }
                ]
                stdout.print(TOONEncoder().encode(dict))
            case .enriched:
                stdout.print(RichFormatter.table(
                    title: "targets (\(summaries.count))",
                    icon: .info,
                    headers: ["Name", "Type", "Platform"],
                    rows: summaries.map { [$0.name, $0.type, $0.platform] }
                ))
            }

        case .target:
            let name = try requireName(for: type)
            guard let target = project.getTarget(name) else { throw QueryError.targetNotFound(name) }
            let detail = TargetDetail(target: target)
            switch outputFormat {
            case .plain:
                success(try encode(detail))
            case .llm:
                let dict: [String: Any] = [
                    "name": detail.name,
                    "type": detail.type,
                    "platform": detail.platform,
                    "sources": detail.sources,
                    "dependencies": detail.dependencies.map { ["type": $0.type, "reference": $0.reference] as [String: Any] }
                ]
                stdout.print(TOONEncoder().encode(dict))
            case .enriched:
                stdout.print(RichFormatter.box(
                    title: detail.name,
                    icon: .info,
                    rows: [
                        ("Type", detail.type),
                        ("Platform", detail.platform),
                        ("Sources", "\(detail.sources.count)"),
                        ("Dependencies", "\(detail.dependencies.count)")
                    ]
                ))
            }

        case .sources:
            let name = try requireName(for: type)
            guard let target = project.getTarget(name) else { throw QueryError.targetNotFound(name) }
            let paths = target.sources.map { $0.path }
            switch outputFormat {
            case .plain:
                success(try encode(paths))
            case .llm:
                stdout.print(TOONEncoder().encode(["sources": paths]))
            case .enriched:
                stdout.print(RichFormatter.table(
                    title: "\(name) sources (\(paths.count))",
                    icon: .info,
                    headers: ["Path"],
                    rows: paths.map { [$0] }
                ))
            }

        case .settings:
            let name = try requireName(for: type)
            guard let target = project.getTarget(name) else { throw QueryError.targetNotFound(name) }
            let settings: [String: String]
            if let config = config {
                let configSettings = target.settings.configSettings[config]?.buildSettings ?? [:]
                settings = configSettings.mapValues { $0.description }
            } else {
                settings = target.settings.buildSettings.mapValues { $0.description }
            }
            switch outputFormat {
            case .plain:
                success(try encode(settings))
            case .llm:
                let pairs: [[String: Any]] = settings.keys.sorted().map { ["key": $0, "value": settings[$0]!] }
                stdout.print(TOONEncoder().encode(["settings": pairs]))
            case .enriched:
                stdout.print(RichFormatter.table(
                    title: "\(name) settings (\(settings.count))",
                    icon: .info,
                    headers: ["Key", "Value"],
                    rows: settings.keys.sorted().map { [$0, settings[$0]!] }
                ))
            }

        case .dependencies:
            let name = try requireName(for: type)
            guard let target = project.getTarget(name) else { throw QueryError.targetNotFound(name) }
            let deps = target.dependencies.map { DependencySummary(dependency: $0) }
            switch outputFormat {
            case .plain:
                success(try encode(deps))
            case .llm:
                let dict: [String: Any] = [
                    "dependencies": deps.map { ["type": $0.type, "reference": $0.reference] as [String: Any] }
                ]
                stdout.print(TOONEncoder().encode(dict))
            case .enriched:
                stdout.print(RichFormatter.table(
                    title: "\(name) dependencies (\(deps.count))",
                    icon: .info,
                    headers: ["Type", "Reference"],
                    rows: deps.map { [$0.type, $0.reference] }
                ))
            }
        }
    }

    private func requireName(for type: QueryType) throws -> String {
        guard let name = targetName else {
            throw QueryError.missingName(type.rawValue)
        }
        return name
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8)!
    }
}

// MARK: - Query type

private enum QueryType: String, ConvertibleFromString {
    case targets
    case target
    case sources
    case settings
    case dependencies
}

// MARK: - Errors

private enum QueryError: Error, CustomStringConvertible, ProcessError {
    case targetNotFound(String)
    case missingName(String)

    var description: String {
        switch self {
        case let .targetNotFound(name):  return #"{"error":"target '\#(name)' not found"}"#
        case let .missingName(type):     return #"{"error":"--name is required for query type '\#(type)'"}"#
        }
    }

    var message: String? { description }
    var exitStatus: Int32 { 1 }
}

// MARK: - Encodable response types

private struct TargetSummary: Encodable {
    let name: String
    let type: String
    let platform: String
}

private struct TargetDetail: Encodable {
    let name: String
    let type: String
    let platform: String
    let deploymentTarget: String?
    let sources: [String]
    let dependencies: [DependencySummary]

    init(target: Target) {
        self.name = target.name
        self.type = target.type.name
        self.platform = target.platform.rawValue
        self.deploymentTarget = target.deploymentTarget?.description
        self.sources = target.sources.map { $0.path }
        self.dependencies = target.dependencies.map { DependencySummary(dependency: $0) }
    }
}

private struct DependencySummary: Encodable {
    let type: String
    let reference: String

    init(dependency: Dependency) {
        self.reference = dependency.reference
        switch dependency.type {
        case .target:        self.type = "target"
        case .framework:     self.type = "framework"
        case .sdk:           self.type = "sdk"
        case .package:       self.type = "package"
        case .carthage:      self.type = "carthage"
        case .bundle:        self.type = "bundle"
        }
    }
}

