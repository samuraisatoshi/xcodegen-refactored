import Foundation
import XcodeProj
import PathKit
import Yams

/// Reads an existing `.xcodeproj` and produces a `project.yml` YAML string.
/// Fidelity over completeness: generates a correct partial spec rather than
/// a potentially broken full one. Constructs that have no direct equivalent
/// are captured in `warnings`.
public struct XcodeProjInferrer {

    public let xcodeprojPath: Path
    public private(set) var warnings: [String] = []

    public init(xcodeprojPath: Path) {
        self.xcodeprojPath = xcodeprojPath
    }

    /// Run inference and return the YAML string.
    public mutating func infer() throws -> String {
        let proj = try XcodeProj(path: xcodeprojPath)
        let pbxproj = proj.pbxproj

        // Determine project name from xcodeproj filename
        let projectName = xcodeprojPath.lastComponentWithoutExtension

        var dict: [String: Any] = [:]
        dict["name"] = projectName

        // Infer targets
        var targetsDict: [String: Any] = [:]
        for target in pbxproj.nativeTargets {
            if let targetDict = try inferTarget(target, pbxproj: pbxproj) {
                targetsDict[target.name] = targetDict
            }
        }

        if targetsDict.isEmpty {
            warnings.append("No native targets found in \(xcodeprojPath.lastComponent)")
        } else {
            dict["targets"] = targetsDict
        }

        return try Yams.dump(object: dict)
    }

    // MARK: - Target inference

    private mutating func inferTarget(_ target: PBXNativeTarget, pbxproj: PBXProj) throws -> [String: Any]? {
        var targetDict: [String: Any] = [:]

        // Type
        guard let productType = target.productType else {
            warnings.append("Target '\(target.name)': no productType — skipped")
            return nil
        }
        guard let typeString = xcodegenType(for: productType) else {
            warnings.append("Target '\(target.name)': unsupported productType '\(productType.rawValue)' — skipped")
            return nil
        }
        targetDict["type"] = typeString

        // Platform + deployment target
        let configs = target.buildConfigurationList?.buildConfigurations ?? []

        // Use first config (usually Debug) for platform detection
        let debugSettings = configs.first(where: { $0.name == "Debug" })?.buildSettings
            ?? configs.first?.buildSettings
            ?? [:]

        let (platform, deploymentTarget) = inferPlatform(from: debugSettings)
        targetDict["platform"] = platform
        if let dt = deploymentTarget {
            targetDict["deploymentTarget"] = dt
        }

        // Sources
        let sources = try inferSources(for: target)
        if !sources.isEmpty {
            targetDict["sources"] = sources
        }

        // Dependencies
        let deps = try inferDependencies(for: target, allTargets: pbxproj.nativeTargets)
        if !deps.isEmpty {
            targetDict["dependencies"] = deps
        }

        // Settings (per-config significant build settings)
        let settingsDict = inferSettings(from: configs, targetName: target.name, platform: platform)
        if !settingsDict.isEmpty {
            targetDict["settings"] = settingsDict
        }

        return targetDict
    }

    // MARK: - Platform

    private func inferPlatform(from settings: BuildSettings) -> (platform: String, deploymentTarget: String?) {
        let sdkroot = stringValue(settings["SDKROOT"]) ?? ""
        let platform: String
        let dtKey: String

        switch sdkroot {
        case "macosx":
            platform = "macOS"; dtKey = "MACOSX_DEPLOYMENT_TARGET"
        case "appletvos":
            platform = "tvOS"; dtKey = "TVOS_DEPLOYMENT_TARGET"
        case "watchos":
            platform = "watchOS"; dtKey = "WATCHOS_DEPLOYMENT_TARGET"
        case "xros":
            platform = "visionOS"; dtKey = "XROS_DEPLOYMENT_TARGET"
        default:
            platform = "iOS"; dtKey = "IPHONEOS_DEPLOYMENT_TARGET"
        }

        let dt = stringValue(settings[dtKey])
        return (platform, dt)
    }

    // MARK: - Sources

    private mutating func inferSources(for target: PBXNativeTarget) throws -> [Any] {
        let files = (try? target.sourceFiles()) ?? []
        var paths: [String] = []

        for file in files {
            if let path = file.path {
                paths.append(path)
            }
        }

        if paths.isEmpty { return [] }

        // Attempt to collapse to a common directory prefix
        if let commonDir = commonDirectory(for: paths), paths.count > 1 {
            return [commonDir]
        }

        return paths.sorted()
    }

    /// Returns the common directory prefix if all paths share one, nil otherwise.
    private func commonDirectory(for paths: [String]) -> String? {
        guard paths.count > 1 else { return nil }
        let components = paths.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
        guard let first = components.first else { return nil }
        let common = components.dropFirst().reduce(first) { sharedPrefix($0, $1) }
        return common.isEmpty ? nil : common
    }

    private func sharedPrefix(_ a: String, _ b: String) -> String {
        let aP = a.components(separatedBy: "/")
        let bP = b.components(separatedBy: "/")
        var result: [String] = []
        for (x, y) in zip(aP, bP) {
            guard x == y else { break }
            result.append(x)
        }
        return result.joined(separator: "/")
    }

    // MARK: - Dependencies

    private mutating func inferDependencies(for target: PBXNativeTarget, allTargets: [PBXNativeTarget]) throws -> [[String: Any]] {
        var deps: [[String: Any]] = []
        let targetNames = Set(allTargets.map { $0.name })

        // Target dependencies
        for dep in target.dependencies {
            if let name = dep.target?.name, targetNames.contains(name) {
                deps.append(["target": name])
            }
        }

        // SDK/framework dependencies from frameworks build phase
        if let frameworksPhase = try? target.frameworksBuildPhase() {
            for buildFile in frameworksPhase.files ?? [] {
                guard let fileRef = buildFile.file else { continue }
                let fileType = (fileRef as? PBXFileReference)?.lastKnownFileType ?? ""
                let path = fileRef.path ?? ""

                // System SDK frameworks: lastKnownFileType == "wrapper.framework"
                // and no slash in path (just "UIKit.framework")
                if fileType == "wrapper.framework" && !path.contains("/") {
                    deps.append(["sdk": path])
                } else if fileType == "compiled.mach-o.dylib" && path.hasPrefix("lib") {
                    // e.g. libz.tbd
                    deps.append(["sdk": path])
                } else if fileType == "sourcecode.text-based-dylib-definition" {
                    deps.append(["sdk": path])
                }
            }
        }

        return deps
    }

    // MARK: - Settings

    private let platformKeys: Set<String> = [
        "SDKROOT",
        "IPHONEOS_DEPLOYMENT_TARGET",
        "MACOSX_DEPLOYMENT_TARGET",
        "TVOS_DEPLOYMENT_TARGET",
        "WATCHOS_DEPLOYMENT_TARGET",
        "XROS_DEPLOYMENT_TARGET",
    ]

    private let ignoredBaseKeys: Set<String> = [
        "ALWAYS_SEARCH_USER_PATHS",
        "COPY_PHASE_STRIP",
        "DEBUG_INFORMATION_FORMAT",
        "ENABLE_NS_ASSERTIONS",
        "ENABLE_STRICT_OBJC_MSGSEND",
        "GCC_C_LANGUAGE_STANDARD",
        "GCC_DYNAMIC_NO_PIC",
        "GCC_NO_COMMON_BLOCKS",
        "GCC_OPTIMIZATION_LEVEL",
        "GCC_PREPROCESSOR_DEFINITIONS",
        "GCC_WARN_64_TO_32_BIT_CONVERSION",
        "GCC_WARN_ABOUT_RETURN_TYPE",
        "GCC_WARN_UNDECLARED_SELECTOR",
        "GCC_WARN_UNINITIALIZED_AUTOS",
        "GCC_WARN_UNUSED_FUNCTION",
        "GCC_WARN_UNUSED_VARIABLE",
        "MTL_ENABLE_DEBUG_INFO",
        "MTL_FAST_MATH",
        "VALIDATE_PRODUCT",
    ]

    private func inferSettings(from configs: [XCBuildConfiguration], targetName: String, platform: String) -> [String: Any] {
        guard !configs.isEmpty else { return [:] }

        // Collect significant settings per config
        var configsDict: [String: [String: Any]] = [:]

        for config in configs {
            var filtered: [String: Any] = [:]
            for (key, val) in config.buildSettings {
                guard !platformKeys.contains(key), !ignoredBaseKeys.contains(key) else { continue }
                // Skip PRODUCT_NAME if it matches target name
                if key == "PRODUCT_NAME", let v = stringValue(val), v == targetName || v == "$(TARGET_NAME)" { continue }
                // Skip PRODUCT_MODULE_NAME if it matches target name
                if key == "PRODUCT_MODULE_NAME", let v = stringValue(val), v == targetName { continue }
                filtered[key] = stringValue(val) ?? val.description
            }
            if !filtered.isEmpty {
                configsDict[config.name] = filtered
            }
        }

        if configsDict.isEmpty { return [:] }

        // Extract base settings (keys identical across all configs)
        var baseSettings: [String: Any] = [:]
        if configs.count > 1 {
            let initialKeys: Set<String> = configsDict.values.first.map { Set($0.keys) } ?? []
            let allKeys = configsDict.values.reduce(initialKeys) {
                $0.intersection($1.keys)
            }
            for key in allKeys {
                let values = configsDict.values.compactMap { $0[key] as? String }
                if values.count == configsDict.count, Set(values).count == 1, let v = values.first {
                    baseSettings[key] = v
                    for name in configsDict.keys {
                        configsDict[name]?.removeValue(forKey: key)
                    }
                }
            }
        }

        var result: [String: Any] = [:]
        if !baseSettings.isEmpty { result["base"] = baseSettings }

        let nonEmpty = configsDict.filter { !$0.value.isEmpty }
        if !nonEmpty.isEmpty { result["configs"] = nonEmpty }

        return result
    }

    // MARK: - Helpers

    private func stringValue(_ setting: BuildSetting?) -> String? {
        guard let setting = setting else { return nil }
        return setting.description == "" ? nil : setting.description
    }

    private func xcodegenType(for productType: PBXProductType) -> String? {
        switch productType {
        case .application:                       return "application"
        case .framework:                         return "framework"
        case .staticFramework:                   return "framework"
        case .dynamicLibrary:                    return "library.dynamic"
        case .staticLibrary:                     return "library.static"
        case .bundle:                            return "bundle"
        case .unitTestBundle:                    return "bundle.unit-test"
        case .uiTestBundle:                      return "bundle.ui-testing"
        case .appExtension:                      return "app-extension"
        case .commandLineTool:                   return "tool"
        case .watchApp, .watch2App:              return "watchapp2"
        case .watchExtension, .watch2Extension:  return "watchkit2-extension"
        case .tvExtension:                       return "tv-app-extension"
        case .messagesApplication:               return "application"
        case .messagesExtension:                 return "app-extension"
        case .xpcService:                        return "xpc-service"
        case .systemExtension:                   return "system-extension"
        case .driverExtension:                   return "driver-extension"
        default:                                 return nil
        }
    }
}
