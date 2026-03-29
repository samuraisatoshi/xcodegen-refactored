import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension PBXProjGenerator {

    // MARK: - Build configurations

    func makeProjectBuildConfigs() -> [XCBuildConfiguration] {
        project.configs.map { config in
            let buildSettings = project.getProjectBuildSettings(config: config)
            var baseConfiguration: PBXFileReference?
            if let configPath = project.configFiles[config.name],
               let fileReference = sourceGenerator.getContainedFileReference(path: project.basePath + configPath) as? PBXFileReference {
                baseConfiguration = fileReference
            }
            let buildConfig = addObject(XCBuildConfiguration(name: config.name, buildSettings: buildSettings))
            buildConfig.baseConfiguration = baseConfiguration
            return buildConfig
        }
    }

    // MARK: - Target stubs

    func createTargetStubs() {
        for target in project.targets {
            let targetObject: PBXTarget
            if target.isLegacy {
                targetObject = PBXLegacyTarget(
                    name: target.name,
                    buildToolPath: target.legacy?.toolPath,
                    buildArgumentsString: target.legacy?.arguments,
                    passBuildSettingsInEnvironment: target.legacy?.passSettings ?? false,
                    buildWorkingDirectory: target.legacy?.workingDirectory,
                    buildPhases: []
                )
            } else {
                targetObject = PBXNativeTarget(name: target.name, buildPhases: [])
            }
            targetObjects[target.name] = addObject(targetObject)

            guard !target.isLegacy else { continue }

            let fileType = Xcode.fileType(path: Path(target.filename), productType: target.type)
            let usesExplicitFileType = target.platform == .macOS || target.platform == .watchOS
                || target.type == .framework || target.type == .extensionKitExtension
            let fileReference = addObject(
                PBXFileReference(
                    sourceTree: .buildProductsDir,
                    explicitFileType: usesExplicitFileType ? fileType : nil,
                    lastKnownFileType: usesExplicitFileType ? nil : fileType,
                    path: target.filename,
                    includeInIndex: false
                ),
                context: target.name
            )
            targetFileReferences[target.name] = fileReference
        }
    }

    func createAggregateTargetStubs() {
        for target in project.aggregateTargets {
            let aggregateTarget = addObject(PBXAggregateTarget(name: target.name, productName: target.name))
            targetAggregateObjects[target.name] = aggregateTarget
        }
    }

    // MARK: - Package references

    func setupPackageReferences() throws {
        for (name, package) in project.packages {
            switch package {
            case let .remote(url, versionRequirement):
                let ref = XCRemoteSwiftPackageReference(repositoryURL: url, versionRequirement: versionRequirement)
                packageReferences[name] = ref
                addObject(ref)
            case let .local(path, group, excludeFromProject):
                let ref = XCLocalSwiftPackageReference(relativePath: path)
                localPackageReferences[name] = ref
                if !excludeFromProject {
                    addObject(ref)
                    try sourceGenerator.createLocalPackage(path: Path(path), group: group.map { Path($0) })
                }
            }
        }
    }

    // MARK: - Product and subproject groups

    func setupProductAndSubprojectGroups(pbxProject: PBXProject) -> [PBXGroup] {
        var derivedGroups: [PBXGroup] = []

        let productGroup = addObject(PBXGroup(
            children: targetFileReferences.valueArray,
            sourceTree: .group,
            name: "Products"
        ))
        derivedGroups.append(productGroup)
        pbxProject.productsGroup = productGroup

        let sortedProjectReferences = project.projectReferences.sorted { $0.name < $1.name }
        let subprojectFileReferences: [PBXFileReference] = sortedProjectReferences.map { ref in
            let projectPath = Path(ref.path)
            return addObject(PBXFileReference(
                sourceTree: .group,
                name: ref.name,
                lastKnownFileType: Xcode.fileType(path: projectPath),
                path: projectPath.normalize().string
            ))
        }

        guard !subprojectFileReferences.isEmpty else { return derivedGroups }

        derivedGroups.append(addObject(PBXGroup(
            children: subprojectFileReferences,
            sourceTree: .group,
            name: "Projects"
        )))

        pbxProject.projects = subprojectFileReferences.map { fileRef in
            let group = addObject(PBXGroup(children: [], sourceTree: .group, name: "Products"))
            return ["ProductGroup": group, "ProjectRef": fileRef]
        }

        return derivedGroups
    }

    // MARK: - Derived framework / bundle groups

    func makeDerivedFrameworkGroups() -> [PBXGroup] {
        var groups: [PBXGroup] = []

        if !carthageFrameworksByPlatform.isEmpty {
            let platforms: [PBXGroup] = carthageFrameworksByPlatform.map { platform, files in
                addObject(PBXGroup(children: Array(files), sourceTree: .group, path: platform))
            }
            let carthageGroup = addObject(PBXGroup(
                children: platforms,
                sourceTree: .group,
                name: "Carthage",
                path: carthageResolver.buildPath
            ))
            frameworkFiles.append(carthageGroup)
        }

        if !frameworkFiles.isEmpty {
            groups.append(addObject(PBXGroup(children: frameworkFiles, sourceTree: .group, name: "Frameworks")))
        }
        if !bundleFiles.isEmpty {
            groups.append(addObject(PBXGroup(children: bundleFiles, sourceTree: .group, name: "Bundles")))
        }
        return groups
    }

    // MARK: - Project finalisation

    func finalizeProject(_ pbxProject: PBXProject, mainGroup: PBXGroup, derivedGroups: [PBXGroup]) {
        mainGroup.children = Array(sourceGenerator.rootGroups)
        sortGroups(group: mainGroup)
        setupGroupOrdering(group: mainGroup)
        derivedGroups.forEach(sortGroups)
        mainGroup.children += derivedGroups.sorted(by: PBXFileElement.sortByNamePath)

        let assetTags = Set(
            project.targets.flatMap { $0.sources.flatMap { $0.resourceTags } }
        ).sorted()

        var projectAttributes: [String: ProjectAttribute] = ["BuildIndependentTargetsInParallel": "YES"]
        for (key, value) in project.attributes {
            projectAttributes[key] = ProjectAttribute(any: value)
        }
        let lastUpgradeKey = "LastUpgradeCheck"
        if !(project.attributes[lastUpgradeKey] is String) {
            projectAttributes[lastUpgradeKey] = .string(project.xcodeVersion)
        }
        if !assetTags.isEmpty {
            projectAttributes["knownAssetTags"] = .array(assetTags)
        }

        var knownRegions = Set(sourceGenerator.knownRegions)
        knownRegions.insert(pbxProject.developmentRegion ?? "en")
        if project.options.useBaseInternationalization { knownRegions.insert("Base") }
        pbxProject.knownRegions = knownRegions.sorted()

        pbxProject.remotePackages = packageReferences.sorted { $0.key < $1.key }.map { $1 }
        pbxProject.localPackages = localPackageReferences.sorted { $0.key < $1.key }.map { $1 }

        let allTargets: [PBXTarget] = targetObjects.valueArray + targetAggregateObjects.valueArray
        pbxProject.targets = allTargets.sorted { $0.name < $1.name }
        pbxProject.attributes = projectAttributes
        pbxProject.targetAttributes = generateTargetAttributes()
    }
}
