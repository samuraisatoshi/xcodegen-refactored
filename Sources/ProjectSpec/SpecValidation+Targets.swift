import Foundation
import PathKit

extension Project {

    func validateTargets() throws -> [SpecValidationError.ValidationError] {
        var errors: [SpecValidationError.ValidationError] = []

        for target in projectTargets {

            for (config, configFile) in target.configFiles {
                let configPath = basePath + configFile
                if !options.disabledValidations.contains(.missingConfigFiles) && !configPath.exists {
                    errors.append(.invalidTargetConfigFile(target: target.name, configFile: configPath.string, config: config))
                }
                if !options.disabledValidations.contains(.missingConfigs) && getConfig(config) == nil {
                    errors.append(.invalidConfigFileConfig(config))
                }
            }

            if let scheme = target.scheme {

                for configVariant in scheme.configVariants {
                    if configs.first(including: configVariant, for: .debug) == nil {
                        errors.append(.invalidTargetSchemeConfigVariant(
                            target: target.name,
                            configVariant: configVariant,
                            configType: .debug
                        ))
                    }
                    if configs.first(including: configVariant, for: .release) == nil {
                        errors.append(.invalidTargetSchemeConfigVariant(
                            target: target.name,
                            configVariant: configVariant,
                            configType: .release
                        ))
                    }
                }

                if scheme.configVariants.isEmpty {
                    if !configs.contains(where: { $0.type == .debug }) {
                        errors.append(.missingConfigForTargetScheme(target: target.name, configType: .debug))
                    }
                    if !configs.contains(where: { $0.type == .release }) {
                        errors.append(.missingConfigForTargetScheme(target: target.name, configType: .release))
                    }
                }

                for testTarget in scheme.testTargets {
                    if getTarget(testTarget.name) == nil {
                        // For test case of local Swift Package
                        if case .package(let name) = testTarget.targetReference.location, getPackage(name) != nil {
                            continue
                        }
                        errors.append(.invalidTargetSchemeTest(target: target.name, testTarget: testTarget.name))
                    }
                }

                if !options.disabledValidations.contains(.missingTestPlans) {
                    let invalidTestPlans: [TestPlan] = scheme.testPlans.filter { !(basePath + $0.path).exists }
                    errors.append(contentsOf: invalidTestPlans.map { .invalidTestPlan($0) })
                }
            }

            for script in target.buildScripts {
                if case let .path(pathString) = script.script {
                    let scriptPath = basePath + pathString
                    if !scriptPath.exists {
                        errors.append(.invalidBuildScriptPath(target: target.name, name: script.name, path: scriptPath.string))
                    }
                }
            }

            errors += validateSettings(target.settings)

            for buildToolPlugin in target.buildToolPlugins {
                if packages[buildToolPlugin.package] == nil {
                    errors.append(.invalidPluginPackageReference(plugin: buildToolPlugin.plugin, package: buildToolPlugin.package))
                }
            }
        }

        for target in aggregateTargets {
            for dependency in target.targets {
                if getProjectTarget(dependency) == nil {
                    errors.append(.invalidTargetDependency(target: target.name, dependency: dependency))
                }
            }
        }

        for target in targets {
            var uniqueDependencies = Set<Dependency>()

            for dependency in target.dependencies {
                let dependencyValidationErrors = try validate(dependency, in: target)
                errors.append(contentsOf: dependencyValidationErrors)

                if uniqueDependencies.contains(dependency) {
                    errors.append(.duplicateDependencies(target: target.name, dependencyReference: dependency.reference))
                } else {
                    uniqueDependencies.insert(dependency)
                }
            }

            for source in target.sources {
                if source.path.isEmpty {
                    errors.append(.emptySourcePath(target: target.name))
                    continue
                }
                let sourcePath = basePath + source.path
                if !source.optional && !sourcePath.exists {
                    errors.append(.invalidTargetSource(target: target.name, source: sourcePath.string))
                }
            }

            if target.supportedDestinations != nil, target.platform == .watchOS {
                errors.append(.unexpectedTargetPlatformForSupportedDestinations(target: target.name, platform: target.platform))
            }

            if let supportedDestinations = target.supportedDestinations,
               target.type.isApp,
               supportedDestinations.contains(.watchOS) {
                errors.append(.containsWatchOSDestinationForMultiplatformApp(target: target.name))
            }

            if target.supportedDestinations?.contains(.macOS) == true,
               target.supportedDestinations?.contains(.macCatalyst) == true {
                errors.append(.multipleMacPlatformsInSupportedDestinations(target: target.name))
            }

            if target.supportedDestinations?.contains(.macCatalyst) == true,
               target.platform != .iOS, target.platform != .auto {
                errors.append(.invalidTargetPlatformForSupportedDestinations(target: target.name))
            }

            if target.platform != .auto, target.platform != .watchOS,
               let supportedDestination = SupportedDestination(rawValue: target.platform.rawValue),
               target.supportedDestinations?.contains(supportedDestination) == false {
                errors.append(.missingTargetPlatformInSupportedDestinations(target: target.name, platform: target.platform))
            }
        }

        for projectReference in projectReferences {
            if !(basePath + projectReference.path).exists {
                errors.append(.invalidProjectReferencePath(projectReference))
            }
        }

        return errors
    }
}
