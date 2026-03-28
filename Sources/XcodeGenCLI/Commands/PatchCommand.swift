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
        switch operation {
        case .addSource:
            guard let path = sourcePath else { throw PatchError.missingParam("--path") }
            dict = try applyAddSource(to: dict, target: targetName, path: path)

        case .addDependency:
            if let sdk = sdkName {
                dict = try applyAddSDKDependency(to: dict, target: targetName, sdk: sdk)
            } else if let pkg = packageName {
                dict = try applyAddPackageDependency(to: dict, target: targetName, package: pkg)
            } else {
                throw PatchError.missingParam("--sdk or --package")
            }

        case .setSetting:
            guard let key = settingKey else { throw PatchError.missingParam("--key") }
            guard let value = settingValue else { throw PatchError.missingParam("--value") }
            dict = try applySetSetting(to: dict, target: targetName, key: key, value: value, config: configName)
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
        success("Created project at \(projectPath)")
    }

    // MARK: - Patch helpers

    private func applyAddSource(to dict: [String: Any], target: String, path: String) throws -> [String: Any] {
        var dict = dict
        guard var targets = dict["targets"] as? [String: Any],
              var targetDict = targets[target] as? [String: Any] else {
            throw PatchError.cannotMutate(target)
        }

        var sources = targetDict["sources"] as? [Any] ?? []
        // Avoid duplicates
        let existing = sources.compactMap { ($0 as? String) ?? ($0 as? [String: Any])?["path"] as? String }
        guard !existing.contains(path) else { return dict }

        sources.append(path)
        targetDict["sources"] = sources
        targets[target] = targetDict
        dict["targets"] = targets
        return dict
    }

    private func applyAddSDKDependency(to dict: [String: Any], target: String, sdk: String) throws -> [String: Any] {
        var dict = dict
        guard var targets = dict["targets"] as? [String: Any],
              var targetDict = targets[target] as? [String: Any] else {
            throw PatchError.cannotMutate(target)
        }

        var deps = targetDict["dependencies"] as? [[String: Any]] ?? []
        let existing = deps.compactMap { $0["sdk"] as? String }
        guard !existing.contains(sdk) else { return dict }

        deps.append(["sdk": sdk])
        targetDict["dependencies"] = deps
        targets[target] = targetDict
        dict["targets"] = targets
        return dict
    }

    private func applyAddPackageDependency(to dict: [String: Any], target: String, package: String) throws -> [String: Any] {
        var dict = dict
        guard var targets = dict["targets"] as? [String: Any],
              var targetDict = targets[target] as? [String: Any] else {
            throw PatchError.cannotMutate(target)
        }

        var deps = targetDict["dependencies"] as? [[String: Any]] ?? []
        let existing = deps.compactMap { $0["package"] as? String }
        guard !existing.contains(package) else { return dict }

        deps.append(["package": package])
        targetDict["dependencies"] = deps
        targets[target] = targetDict
        dict["targets"] = targets
        return dict
    }

    private func applySetSetting(to dict: [String: Any], target: String, key: String, value: String, config: String?) throws -> [String: Any] {
        var dict = dict
        guard var targets = dict["targets"] as? [String: Any],
              var targetDict = targets[target] as? [String: Any] else {
            throw PatchError.cannotMutate(target)
        }

        var settings = targetDict["settings"] as? [String: Any] ?? [:]

        if let config = config {
            var configs = settings["configs"] as? [String: Any] ?? [:]
            var configSettings = configs[config] as? [String: Any] ?? [:]
            configSettings[key] = value
            configs[config] = configSettings
            settings["configs"] = configs
        } else {
            var base = settings["base"] as? [String: Any] ?? [:]
            base[key] = value
            settings["base"] = base
        }

        targetDict["settings"] = settings
        targets[target] = targetDict
        dict["targets"] = targets
        return dict
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
    case cannotMutate(String)

    var description: String {
        switch self {
        case .missingOperation:        return #"{"error":"--operation is required: add-source, add-dependency, set-setting"}"#
        case .missingTarget:           return #"{"error":"--target is required"}"#
        case .missingDictionary:       return #"{"error":"could not load project dictionary"}"#
        case let .targetNotFound(n):   return #"{"error":"target '\#(n)' not found"}"#
        case let .missingParam(p):     return #"{"error":"missing required parameter: \#(p)"}"#
        case let .cannotMutate(t):     return #"{"error":"cannot locate target '\#(t)' in YAML structure"}"#
        }
    }

    var message: String? { description }
    var exitStatus: Int32 { 1 }
}
