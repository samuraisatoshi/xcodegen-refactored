import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import XcodeProj
import Yams
import Version

class PatchCommand: ProjectCommand {

    @Key("--operation", "-o", description: "Patch operation: add-source, add-dependency, set-setting")
    private var operation: PatchOperation?

    @Key("--target", description: "Target name to patch (required)")
    private var targetName: String?

    @Key("--path", description: "Source file path (for add-source)")
    private var sourcePath: String?

    @Key("--sdk", description: "SDK framework to add, e.g. CoreML.framework (for add-dependency)")
    private var sdkName: String?

    @Key("--package", description: "SPM package product to add (for add-dependency)")
    private var packageName: String?

    @Key("--key", description: "Build setting key (for set-setting)")
    private var settingKey: String?

    @Key("--value", description: "Build setting value (for set-setting)")
    private var settingValue: String?

    @Key("--config", description: "Config name for set-setting (omit for base settings)")
    private var configName: String?

    @Flag("--dry-run", description: "Print the modified YAML without writing or generating")
    private var dryRun: Bool

    init(version: Version) {
        super.init(version: version,
                   name: "patch",
                   shortDescription: "Semantically edit the spec and regenerate atomically")
    }

    override func guideContent(locale: GuideLocale) -> CommandGuide {
        PatchGuide.content(locale: locale)
    }

    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {
        guard let operation = operation else {
            throw PatchError.missingOperation
        }
        guard let targetName = targetName else {
            throw PatchError.missingTarget
        }

        // Load raw YAML dictionary for mutation
        guard var dict = specLoader.projectDictionary else {
            throw PatchError.missingDictionary
        }

        // Verify target exists in the resolved project
        guard project.getTarget(targetName) != nil else {
            throw PatchError.targetNotFound(targetName)
        }

        // Apply the patch to the dictionary
        let patcher = XcodeSpecPatcher()
        switch operation {
        case .addSource:
            guard let path = sourcePath else { throw PatchError.missingParam("--path") }
            dict = try patcher.addSource(to: dict, target: targetName, path: path)

        case .addDependency:
            if let sdk = sdkName {
                dict = try patcher.addSDKDependency(to: dict, target: targetName, sdk: sdk)
            } else if let pkg = packageName {
                dict = try patcher.addPackageDependency(to: dict, target: targetName, package: pkg)
            } else {
                throw PatchError.missingParam("--sdk or --package")
            }

        case .setSetting:
            guard let key = settingKey else { throw PatchError.missingParam("--key") }
            guard let value = settingValue else { throw PatchError.missingParam("--value") }
            dict = try patcher.setSetting(in: dict, target: targetName, key: key, value: value, config: configName)
        }

        // Serialize back to YAML (note: comments and key order are not preserved — documented trade-off)
        let yamlString = try Yams.dump(object: dict)

        if dryRun {
            success(yamlString)
            return
        }

        // Write spec
        try projectSpecPath.write(yamlString)
        info("Patched \(projectSpecPath.lastComponent)")

        // Regenerate
        let projectDirectory = projectSpecPath.parent()
        let projectPath = projectDirectory + "\(project.name).xcodeproj"

        let specLoader2 = SpecLoader(version: version)
        let variables: [String: String] = disableEnvExpansion ? [:] : ProcessInfo.processInfo.environment
        let updatedProject = try specLoader2.loadProject(path: projectSpecPath, projectRoot: projectRoot, variables: variables)

        try updatedProject.validateMinimumXcodeGenVersion(version)
        try updatedProject.validate()

        let fileWriter = FileWriter(project: updatedProject)
        try fileWriter.writePlists()

        let projectGenerator = ProjectGenerator(project: updatedProject)
        guard let userName = ProcessInfo.processInfo.environment["USER"] else {
            throw GenerationError.missingUsername
        }

        let xcodeProject = try projectGenerator.generateXcodeProject(in: projectDirectory, userName: userName)
        try fileWriter.writeXcodeProject(xcodeProject, to: projectPath)

        switch outputFormat {
        case .plain:
            success("Created project at \(projectPath)")
        case .llm:
            let dict: [String: Any] = [
                "status": "ok",
                "spec": projectSpecPath.string,
                "project": projectPath.string
            ]
            stdout.print(TOONEncoder().encode(dict))
        case .enriched:
            stdout.print(RichFormatter.box(
                title: projectPath.lastComponent,
                icon: .ok,
                rows: [
                    ("Spec", projectSpecPath.lastComponent),
                    ("Operation", operation.rawValue)
                ]
            ))
        }
    }

}

// MARK: - Operation enum

private enum PatchOperation: String, ConvertibleFromString {
    case addSource      = "add-source"
    case addDependency  = "add-dependency"
    case setSetting     = "set-setting"
}

// MARK: - Errors

private enum PatchError: Error, CustomStringConvertible, ProcessError {
    case missingOperation
    case missingTarget
    case missingDictionary
    case targetNotFound(String)
    case missingParam(String)

    var description: String {
        switch self {
        case .missingOperation:        return #"{"error":"--operation is required: add-source, add-dependency, set-setting"}"#
        case .missingTarget:           return #"{"error":"--target is required"}"#
        case .missingDictionary:       return #"{"error":"could not load project dictionary"}"#
        case let .targetNotFound(n):   return #"{"error":"target '\#(n)' not found"}"#
        case let .missingParam(p):     return #"{"error":"missing required parameter: \#(p)"}"#
        }
    }

    var message: String? { description }
    var exitStatus: Int32 { 1 }
}
