import Foundation
import JSONUtilities
import PathKit
import Version

extension Project {

    public func validate() throws {
        var errors: [SpecValidationError.ValidationError] = []

        errors += validateSettings(settings)

        for fileGroup in fileGroups {
            if !(basePath + fileGroup).exists {
                errors.append(.invalidFileGroup(fileGroup))
            }
        }

        errors += validatePackages()
        errors += validateConfigs()
        errors += try validateTargets()
        errors += validateSchemes()

        if !errors.isEmpty {
            throw SpecValidationError(errors: errors)
        }
    }

    public func validateMinimumXcodeGenVersion(_ xcodeGenVersion: Version) throws {
        if let minimumXcodeGenVersion = options.minimumXcodeGenVersion, xcodeGenVersion < minimumXcodeGenVersion {
            throw SpecValidationError(errors: [SpecValidationError.ValidationError.invalidXcodeGenVersion(minimumVersion: minimumXcodeGenVersion, version: xcodeGenVersion)])
        }
    }

    // MARK: - Shared helpers

    func validateSettings(_ settings: Settings) -> [SpecValidationError.ValidationError] {
        var errors: [SpecValidationError.ValidationError] = []
        for group in settings.groups {
            if let settings = settingGroups[group] {
                errors += validateSettings(settings)
            } else {
                errors.append(.invalidSettingsGroup(group))
            }
        }

        for config in settings.configSettings.keys {
            if !configs.contains(where: { $0.name.lowercased().contains(config.lowercased()) }),
               !options.disabledValidations.contains(.missingConfigs) {
                errors.append(.invalidBuildSettingConfig(config))
            }
        }

        if settings.buildSettings.count == configs.count {
            var allConfigs = true
            outerLoop: for buildSetting in settings.buildSettings.keys {
                var isConfig = false
                for config in configs {
                    if config.name.lowercased().contains(buildSetting.lowercased()) {
                        isConfig = true
                        break
                    }
                }
                if !isConfig {
                    allConfigs = false
                    break outerLoop
                }
            }

            if allConfigs {
                errors.append(.invalidPerConfigSettings)
            }
        }
        return errors
    }

    // Returns error if the given dependency from target is invalid.
    func validate(_ dependency: Dependency, in target: Target) throws -> [SpecValidationError.ValidationError] {
        var errors: [SpecValidationError.ValidationError] = []

        switch dependency.type {
            case .target:
                let dependencyTargetReference = try TargetReference(dependency.reference)

                switch dependencyTargetReference.location {
                case .local:
                    if getProjectTarget(dependency.reference) == nil {
                        errors.append(.invalidTargetDependency(target: target.name, dependency: dependency.reference))
                    }
                case .project(let dependencyProjectName):
                    if getProjectReference(dependencyProjectName) == nil {
                        errors.append(.invalidTargetDependency(target: target.name, dependency: dependency.reference))
                    }
                }
            case .sdk:
                let path = Path(dependency.reference)
                if !dependency.reference.contains("/") {
                    switch path.extension {
                    case "framework"?,
                            "tbd"?,
                            "dylib"?:
                        break
                    default:
                        errors.append(.invalidSDKDependency(target: target.name, dependency: dependency.reference))
                    }
                }
            case .package:
                if packages[dependency.reference] == nil {
                    errors.append(.invalidSwiftPackage(name: dependency.reference, target: target.name))
                }
            default: break
        }

        return errors
    }

    /// Returns a descriptive error if the given target reference was invalid otherwise `nil`.
    func validationError(for targetReference: TargetReference, in scheme: Scheme, action: String) -> SpecValidationError.ValidationError? {
        switch targetReference.location {
        case .local where getProjectTarget(targetReference.name) == nil:
            return .invalidSchemeTarget(scheme: scheme.name, target: targetReference.name, action: action)
        case .project(let project) where getProjectReference(project) == nil:
            return .invalidProjectReference(scheme: scheme.name, reference: project)
        case .local, .project:
            return nil
        }
    }

    /// Returns a descriptive error if the given target reference was invalid otherwise `nil`.
    func validationError(for testableTargetReference: TestableTargetReference, in scheme: Scheme, action: String) -> SpecValidationError.ValidationError? {
        switch testableTargetReference.location {
        case .local where getProjectTarget(testableTargetReference.name) == nil:
            return .invalidSchemeTarget(scheme: scheme.name, target: testableTargetReference.name, action: action)
        case .project(let project) where getProjectReference(project) == nil:
            return .invalidProjectReference(scheme: scheme.name, reference: project)
        case .package(let package) where getPackage(package) == nil:
            return .invalidLocalPackage(package)
        case .local, .project, .package:
            return nil
        }
    }
}
