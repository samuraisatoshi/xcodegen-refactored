import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension PBXProjGenerator {

    // MARK: - Build phases assembly

    func assembleBuildPhases(
        for target: Target,
        sourceFiles: [SourceFile],
        ctx: inout TargetGenerationContext
    ) throws -> [PBXBuildPhase] {
        ctx.copyFilesBuildPhasesFiles.merge(getBuildFilesForCopyFilesPhases(in: sourceFiles)) { $0 + $1 }

        var buildPhases: [PBXBuildPhase] = []

        buildPhases += try target.preBuildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        buildPhases += ctx.copyFilesBuildPhasesFiles
            .filter { $0.key.phaseOrder == .preCompile }
            .map { generateCopyFiles(targetName: target.name, copyFiles: $0, buildPhaseFiles: $1) }

        let headersBuildPhaseFiles = getBuildFilesForPhase(.headers, in: sourceFiles)
        if !headersBuildPhaseFiles.isEmpty {
            if target.type.isFramework || target.type == .dynamicLibrary {
                buildPhases.append(addObject(PBXHeadersBuildPhase(files: headersBuildPhaseFiles)))
            } else {
                headersBuildPhaseFiles.forEach { pbxProj.delete(object: $0) }
            }
        }

        if target.putResourcesBeforeSourcesBuildPhase {
            addResourcesBuildPhase(target: target, sourceFiles: sourceFiles, ctx: ctx, buildPhases: &buildPhases)
        }

        let sourcesBuildPhaseFiles = getBuildFilesForPhase(.sources, in: sourceFiles)
        let shouldSkipSourcesBuildPhase = sourcesBuildPhaseFiles.isEmpty && target.type.canSkipCompileSourcesBuildPhase
        if !shouldSkipSourcesBuildPhase {
            buildPhases.append(addObject(PBXSourcesBuildPhase(files: sourcesBuildPhaseFiles)))
        }

        buildPhases += try target.postCompileScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        if !target.putResourcesBeforeSourcesBuildPhase {
            addResourcesBuildPhase(target: target, sourceFiles: sourceFiles, ctx: ctx, buildPhases: &buildPhases)
        }

        let swiftObjCInterfaceHeader = project.getCombinedBuildSetting(
            "SWIFT_OBJC_INTERFACE_HEADER_NAME", target: target, config: project.configs[0])?.stringValue
        let swiftInstallObjCHeader = project.getBoolBuildSetting(
            "SWIFT_INSTALL_OBJC_HEADER", target: target, config: project.configs[0]) ?? true

        if target.type == .staticLibrary
            && swiftObjCInterfaceHeader != ""
            && swiftInstallObjCHeader
            && sourceFiles.contains(where: { $0.buildPhase == .sources && $0.path.extension == "swift" }) {
            let script = addObject(PBXShellScriptBuildPhase(
                name: "Copy Swift Objective-C Interface Header",
                inputPaths: ["$(DERIVED_SOURCES_DIR)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"],
                outputPaths: ["$(BUILT_PRODUCTS_DIR)/include/$(PRODUCT_MODULE_NAME)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"],
                shellPath: "/bin/sh",
                shellScript: "ditto \"${SCRIPT_INPUT_FILE_0}\" \"${SCRIPT_OUTPUT_FILE_0}\"\n"
            ))
            buildPhases.append(script)
        }

        buildPhases += ctx.copyFilesBuildPhasesFiles
            .filter { $0.key.phaseOrder == .postCompile }
            .map { generateCopyFiles(targetName: target.name, copyFiles: $0, buildPhaseFiles: $1) }

        if !ctx.carthageFrameworksToEmbed.isEmpty {
            let inputPaths = ctx.carthageFrameworksToEmbed.map {
                "$(SRCROOT)/\(carthageResolver.buildPath(for: target.platform, linkType: .dynamic))/\($0)\($0.contains(".") ? "" : ".framework")"
            }
            let outputPaths = ctx.carthageFrameworksToEmbed.map {
                "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/\($0)\($0.contains(".") ? "" : ".framework")"
            }
            buildPhases.append(addObject(PBXShellScriptBuildPhase(
                name: "Carthage",
                inputPaths: inputPaths,
                outputPaths: outputPaths,
                shellPath: "/bin/sh -l",
                shellScript: "\(carthageResolver.executable) copy-frameworks\n"
            )))
        }

        if !ctx.targetFrameworkBuildFiles.isEmpty {
            buildPhases.append(addObject(PBXFrameworksBuildPhase(files: ctx.targetFrameworkBuildFiles)))
        }

        if !ctx.copyBundlesReferences.isEmpty {
            buildPhases.append(addObject(PBXCopyFilesBuildPhase(
                dstSubfolderSpec: .resources,
                name: "Copy Bundle Resources",
                files: ctx.copyBundlesReferences
            )))
        }

        if !ctx.extensions.isEmpty {
            buildPhases.append(addObject(getPBXCopyFilesBuildPhase(
                dstSubfolderSpec: .plugins, name: "Embed Foundation Extensions",
                files: ctx.extensions, target: target
            )))
        }

        if !ctx.extensionKitExtensions.isEmpty {
            buildPhases.append(addObject(getPBXCopyFilesBuildPhase(
                dstSubfolderSpec: .productsDirectory, dstPath: "$(EXTENSIONS_FOLDER_PATH)",
                name: "Embed ExtensionKit Extensions", files: ctx.extensionKitExtensions, target: target
            )))
        }

        if !ctx.systemExtensions.isEmpty {
            buildPhases.append(addObject(getPBXCopyFilesBuildPhase(
                dstSubfolderSpec: .productsDirectory, dstPath: "$(SYSTEM_EXTENSIONS_FOLDER_PATH)",
                name: "Embed System Extensions", files: ctx.systemExtensions, target: target
            )))
        }

        if !ctx.appClips.isEmpty {
            buildPhases.append(addObject(PBXCopyFilesBuildPhase(
                dstPath: "$(CONTENTS_FOLDER_PATH)/AppClips",
                dstSubfolderSpec: .productsDirectory,
                name: "Embed App Clips",
                files: ctx.appClips
            )))
        }

        ctx.copyFrameworksReferences += getBuildFilesForPhase(.frameworks, in: sourceFiles)
        if !ctx.copyFrameworksReferences.isEmpty {
            buildPhases.append(addObject(getPBXCopyFilesBuildPhase(
                dstSubfolderSpec: .frameworks, name: "Embed Frameworks",
                files: ctx.copyFrameworksReferences, target: target
            )))
        }

        if !ctx.customCopyDependenciesReferences.isEmpty {
            for (phase, references) in splitCopyDepsByDestination(ctx.customCopyDependenciesReferences, ctx: ctx) {
                guard let destination = phase.destination.destination else { continue }
                buildPhases.append(addObject(getPBXCopyFilesBuildPhase(
                    dstSubfolderSpec: destination, dstPath: phase.subpath,
                    name: "Embed Dependencies", files: references, target: target
                )))
            }
        }

        if !ctx.copyWatchReferences.isEmpty {
            buildPhases.append(addObject(PBXCopyFilesBuildPhase(
                dstPath: "$(CONTENTS_FOLDER_PATH)/Watch",
                dstSubfolderSpec: .productsDirectory,
                name: "Embed Watch Content",
                files: ctx.copyWatchReferences
            )))
        }

        buildPhases += try target.postBuildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        return buildPhases
    }

    // MARK: - Build configurations

    func buildTargetConfigs(
        for target: Target,
        sourceFiles: [SourceFile],
        infoPlistFiles: [Config: String],
        carthageDependencies: [ResolvedCarthageDependency],
        ctx: TargetGenerationContext
    ) -> [XCBuildConfiguration] {
        project.configs.map { config in
            var buildSettings = project.getTargetBuildSettings(target: target, config: config)

            if let entitlements = target.entitlements {
                buildSettings["CODE_SIGN_ENTITLEMENTS"] = .string(entitlements.path)
            }

            if let infoPlistFile = infoPlistFiles[config] {
                buildSettings["INFOPLIST_FILE"] = .string(infoPlistFile)
            }

            if let bundleIdPrefix = project.options.bundleIdPrefix,
               !project.targetHasBuildSetting("PRODUCT_BUNDLE_IDENTIFIER", target: target, config: config) {
                let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-.")).inverted
                let escapedTargetName = target.name
                    .replacingOccurrences(of: "_", with: "-")
                    .components(separatedBy: characterSet)
                    .joined(separator: "")
                buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = .string(bundleIdPrefix + "." + escapedTargetName)
            }

            if target.type == .uiTestBundle,
               !project.targetHasBuildSetting("TEST_TARGET_NAME", target: target, config: config) {
                for dependency in target.dependencies {
                    if dependency.type == .target,
                       let dependencyTarget = project.getTarget(dependency.reference),
                       dependencyTarget.type.isApp {
                        buildSettings["TEST_TARGET_NAME"] = .string(dependencyTarget.name)
                        break
                    }
                }
            }

            if target.type == .unitTestBundle,
               !project.targetHasBuildSetting("TEST_HOST", target: target, config: config) {
                for dependency in target.dependencies {
                    if dependency.type == .target,
                       let dependencyTarget = project.getTarget(dependency.reference),
                       dependencyTarget.type.isApp {
                        if dependencyTarget.platform == .macOS {
                            buildSettings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/\(dependencyTarget.productName).app/Contents/MacOS/\(dependencyTarget.productName)"
                        } else {
                            buildSettings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/\(dependencyTarget.productName).app/\(dependencyTarget.productName)"
                        }
                        break
                    }
                }
            }

            if ctx.anyDependencyRequiresObjCLinking {
                let otherLinkingFlags = "OTHER_LDFLAGS"
                let objCLinking = "-ObjC"
                if var array = buildSettings[otherLinkingFlags]?.arrayValue {
                    array.append(objCLinking)
                    buildSettings[otherLinkingFlags] = .array(array)
                } else if let string = buildSettings[otherLinkingFlags]?.stringValue {
                    buildSettings[otherLinkingFlags] = .array([string, objCLinking])
                } else {
                    buildSettings[otherLinkingFlags] = .array(["$(inherited)", objCLinking])
                }
            }

            let configFrameworkBuildPaths: [String]
            if !carthageDependencies.isEmpty {
                var carthagePlatformBuildPaths: Set<String> = []
                if carthageDependencies.contains(where: { $0.dependency.carthageLinkType == .static }) {
                    carthagePlatformBuildPaths.insert("$(PROJECT_DIR)/" + carthageResolver.buildPath(for: target.platform, linkType: .static))
                }
                if carthageDependencies.contains(where: { $0.dependency.carthageLinkType == .dynamic }) {
                    carthagePlatformBuildPaths.insert("$(PROJECT_DIR)/" + carthageResolver.buildPath(for: target.platform, linkType: .dynamic))
                }
                configFrameworkBuildPaths = carthagePlatformBuildPaths.sorted() + ctx.frameworkBuildPaths.sorted()
            } else {
                configFrameworkBuildPaths = ctx.frameworkBuildPaths.sorted()
            }

            if !configFrameworkBuildPaths.isEmpty {
                let frameworkSearchPaths = "FRAMEWORK_SEARCH_PATHS"
                if var array = buildSettings[frameworkSearchPaths]?.arrayValue {
                    array.append(contentsOf: configFrameworkBuildPaths)
                    buildSettings[frameworkSearchPaths] = .array(array)
                } else if let string = buildSettings[frameworkSearchPaths]?.stringValue {
                    buildSettings[frameworkSearchPaths] = .array([string] + configFrameworkBuildPaths)
                } else {
                    buildSettings[frameworkSearchPaths] = .array(["$(inherited)"] + configFrameworkBuildPaths)
                }
            }

            var baseConfiguration: PBXFileReference?
            if let configPath = target.configFiles[config.name],
               let fileReference = sourceGenerator.getContainedFileReference(path: project.basePath + configPath) as? PBXFileReference {
                baseConfiguration = fileReference
            }
            let buildConfig = XCBuildConfiguration(name: config.name, buildSettings: buildSettings)
            buildConfig.baseConfiguration = baseConfiguration
            return addObject(buildConfig)
        }
    }
}
