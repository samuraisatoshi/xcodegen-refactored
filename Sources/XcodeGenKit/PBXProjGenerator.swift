import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import Yams
import Version

public class PBXProjGenerator {

    let project: Project

    let pbxProj: PBXProj
    let projectDirectory: Path?
    let carthageResolver: CarthageResolving

    public static let copyFilesActionMask: UInt = 8

    let sourceGenerator: SourceGenerator

    var targetObjects: [String: PBXTarget] = [:]
    var targetAggregateObjects: [String: PBXAggregateTarget] = [:]
    var targetFileReferences: [String: PBXFileReference] = [:]
    var sdkFileReferences: [String: PBXFileReference] = [:]
    var packageReferences: [String: XCRemoteSwiftPackageReference] = [:]
    var localPackageReferences: [String: XCLocalSwiftPackageReference] = [:]

    var carthageFrameworksByPlatform: [String: Set<PBXFileElement>] = [:]
    var frameworkFiles: [PBXFileElement] = []
    var bundleFiles: [PBXFileElement] = []

    var generated = false

    private var projects: [ProjectReference: PBXProj] = [:]

    public init(project: Project, projectDirectory: Path? = nil, carthageResolver: CarthageResolving? = nil) {
        self.project = project
        pbxProj = PBXProj(rootObject: nil, objectVersion: project.objectVersion)
        self.projectDirectory = projectDirectory
        self.carthageResolver = carthageResolver ?? CarthageDependencyResolver(project: project)
        sourceGenerator = SourceGenerator(project: project,
                                          pbxProj: pbxProj,
                                          projectDirectory: projectDirectory)
    }

    @discardableResult
    func addObject<T: PBXObject>(_ object: T, context: String? = nil) -> T {
        pbxProj.add(object: object)
        object.context = context
        return object
    }

    public func generate() throws -> PBXProj {
        if generated {
            fatalError("Cannot use PBXProjGenerator to generate more than once")
        }
        generated = true

        for group in project.fileGroups {
            try sourceGenerator.getFileGroups(path: group)
        }

        let buildConfigs: [XCBuildConfiguration] = project.configs.map { config in
            let buildSettings = project.getProjectBuildSettings(config: config)
            var baseConfiguration: PBXFileReference?
            if let configPath = project.configFiles[config.name],
                let fileReference = sourceGenerator.getContainedFileReference(path: project.basePath + configPath) as? PBXFileReference {
                baseConfiguration = fileReference
            }
            let buildConfig = addObject(
                XCBuildConfiguration(
                    name: config.name,
                    buildSettings: buildSettings
                )
            )
            buildConfig.baseConfiguration = baseConfiguration
            return buildConfig
        }

        let configName = project.options.defaultConfig ?? buildConfigs.first?.name ?? ""
        let buildConfigList = addObject(
            XCConfigurationList(
                buildConfigurations: buildConfigs,
                defaultConfigurationName: configName
            )
        )

        var derivedGroups: [PBXGroup] = []

        let mainGroup = addObject(
            PBXGroup(
                children: [],
                sourceTree: .group,
                usesTabs: project.options.usesTabs,
                indentWidth: project.options.indentWidth,
                tabWidth: project.options.tabWidth
            )
        )

        let developmentRegion = project.options.developmentLanguage ?? "en"
        let pbxProject = addObject(
            PBXProject(
                name: project.name,
                buildConfigurationList: buildConfigList,
                compatibilityVersion: project.compatibilityVersion,
                preferredProjectObjectVersion: project.preferredProjectObjectVersion.map { Int($0) },
                minimizedProjectReferenceProxies: project.minimizedProjectReferenceProxies,
                mainGroup: mainGroup,
                developmentRegion: developmentRegion
            )
        )

        pbxProj.rootObject = pbxProject

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

            var explicitFileType: String?
            var lastKnownFileType: String?
            let fileType = Xcode.fileType(path: Path(target.filename), productType: target.type)
            if target.platform == .macOS || target.platform == .watchOS || target.type == .framework || target.type == .extensionKitExtension {
                explicitFileType = fileType
            } else {
                lastKnownFileType = fileType
            }

            if !target.isLegacy {
                let fileReference = addObject(
                    PBXFileReference(
                        sourceTree: .buildProductsDir,
                        explicitFileType: explicitFileType,
                        lastKnownFileType: lastKnownFileType,
                        path: target.filename,
                        includeInIndex: false
                    ),
                    context: target.name
                )

                targetFileReferences[target.name] = fileReference
            }
        }

        for target in project.aggregateTargets {

            let aggregateTarget = addObject(
                PBXAggregateTarget(
                    name: target.name,
                    productName: target.name
                )
            )
            targetAggregateObjects[target.name] = aggregateTarget
        }

        for (name, package) in project.packages {
            switch package {
            case let .remote(url, versionRequirement):
                let packageReference = XCRemoteSwiftPackageReference(repositoryURL: url, versionRequirement: versionRequirement)
                packageReferences[name] = packageReference
                addObject(packageReference)
            case let .local(path, group, excludeFromProject):
                let packageReference = XCLocalSwiftPackageReference(relativePath: path)
                localPackageReferences[name] = packageReference

                if !excludeFromProject {
                    addObject(packageReference)
                    try sourceGenerator.createLocalPackage(path: Path(path), group: group.map { Path($0) })
                }
            }
        }

        let productGroup = addObject(
            PBXGroup(
                children: targetFileReferences.valueArray,
                sourceTree: .group,
                name: "Products"
            )
        )
        derivedGroups.append(productGroup)
        pbxProject.productsGroup = productGroup

        let sortedProjectReferences = project.projectReferences.sorted { $0.name < $1.name }
        let subprojectFileReferences: [PBXFileReference] = sortedProjectReferences.map { projectReference in
            let projectPath = Path(projectReference.path)

            return addObject(
                PBXFileReference(
                    sourceTree: .group,
                    name: projectReference.name,
                    lastKnownFileType: Xcode.fileType(path: projectPath),
                    path: projectPath.normalize().string
                )
            )
        }
        if subprojectFileReferences.count > 0 {
            let subprojectsGroups = addObject(
                PBXGroup(
                    children: subprojectFileReferences,
                    sourceTree: .group,
                    name: "Projects"
                )
            )
            derivedGroups.append(subprojectsGroups)

            let subprojects: [[String: PBXFileElement]] = subprojectFileReferences.map { projectReference in
                let group = addObject(
                    PBXGroup(
                        children: [],
                        sourceTree: .group,
                        name: "Products"
                    )
                )
                return [
                    "ProductGroup": group,
                    "ProjectRef": projectReference,
                ]
            }

            pbxProject.projects = subprojects
        }

        try project.targets.forEach(generateTarget)
        try project.aggregateTargets.forEach(generateAggregateTarget)

        if !carthageFrameworksByPlatform.isEmpty {
            var platforms: [PBXGroup] = []
            for (platform, files) in carthageFrameworksByPlatform {
                let platformGroup: PBXGroup = addObject(
                    PBXGroup(
                        children: Array(files),
                        sourceTree: .group,
                        path: platform
                    )
                )
                platforms.append(platformGroup)
            }
            let carthageGroup = addObject(
                PBXGroup(
                    children: platforms,
                    sourceTree: .group,
                    name: "Carthage",
                    path: carthageResolver.buildPath
                )
            )
            frameworkFiles.append(carthageGroup)
        }

        if !frameworkFiles.isEmpty {
            let group = addObject(
                PBXGroup(
                    children: frameworkFiles,
                    sourceTree: .group,
                    name: "Frameworks"
                )
            )
            derivedGroups.append(group)
        }

        if !bundleFiles.isEmpty {
            let group = addObject(
                PBXGroup(
                    children: bundleFiles,
                    sourceTree: .group,
                    name: "Bundles"
                )
            )
            derivedGroups.append(group)
        }

        mainGroup.children = Array(sourceGenerator.rootGroups)
        sortGroups(group: mainGroup)
        setupGroupOrdering(group: mainGroup)
        // add derived groups at the end
        derivedGroups.forEach(sortGroups)
        mainGroup.children += derivedGroups
            .sorted(by: PBXFileElement.sortByNamePath)
            .map { $0 }

        let assetTags = Set(project.targets
            .map { target in
                target.sources.map { $0.resourceTags }.flatMap { $0 }
            }.flatMap { $0 }
        ).sorted()

        var projectAttributes: [String: ProjectAttribute] = [
            "BuildIndependentTargetsInParallel": "YES"
        ]
        for (key, value) in project.attributes {
            projectAttributes[key] = ProjectAttribute(any: value)
        }

        // Set default LastUpgradeCheck if user did not specify a valid string value
        let lastUpgradeKey = "LastUpgradeCheck"
        if !(project.attributes[lastUpgradeKey] is String) {
            projectAttributes[lastUpgradeKey] = .string(project.xcodeVersion)
        }

        if !assetTags.isEmpty {
            projectAttributes["knownAssetTags"] = .array(assetTags)
        }

        var knownRegions = Set(sourceGenerator.knownRegions)
        knownRegions.insert(developmentRegion)
        if project.options.useBaseInternationalization {
            knownRegions.insert("Base")
        }
        pbxProject.knownRegions = knownRegions.sorted()

        pbxProject.remotePackages = packageReferences.sorted { $0.key < $1.key }.map { $1 }
        pbxProject.localPackages = localPackageReferences.sorted { $0.key < $1.key }.map { $1 }

        let allTargets: [PBXTarget] = targetObjects.valueArray + targetAggregateObjects.valueArray
        pbxProject.targets = allTargets
            .sorted { $0.name < $1.name }
        pbxProject.attributes = projectAttributes
        pbxProject.targetAttributes = generateTargetAttributes()
        return pbxProj
    }

    func generateAggregateTarget(_ target: AggregateTarget) throws {

        let aggregateTarget = targetAggregateObjects[target.name]!

        let configs: [XCBuildConfiguration] = project.configs.map { config in

            let buildSettings = project.getBuildSettings(settings: target.settings, config: config)

            var baseConfiguration: PBXFileReference?
            if let configPath = target.configFiles[config.name] {
                baseConfiguration = sourceGenerator.getContainedFileReference(path: project.basePath + configPath) as? PBXFileReference
            }
            let buildConfig = XCBuildConfiguration(
                name: config.name,
                baseConfiguration: baseConfiguration,
                buildSettings: buildSettings
            )
            return addObject(buildConfig)
        }

        var dependencies = target.targets.map { generateTargetDependency(from: target.name, to: $0, platform: nil, platforms: nil) }

        let defaultConfigurationName = project.options.defaultConfig ?? project.configs.first?.name ?? ""
        let buildConfigList = addObject(XCConfigurationList(
            buildConfigurations: configs,
            defaultConfigurationName: defaultConfigurationName
        ))

        var buildPhases: [PBXBuildPhase] = []
        buildPhases += try target.buildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        let packagePluginDependencies = makePackagePluginDependency(for: target)
        dependencies.append(contentsOf: packagePluginDependencies)

        aggregateTarget.buildPhases = buildPhases
        aggregateTarget.buildConfigurationList = buildConfigList
        aggregateTarget.dependencies = dependencies
    }

    func generateTargetDependency(from: String, to target: String, platform: String?, platforms: [String]?) -> PBXTargetDependency {
        guard let targetObject = targetObjects[target] ?? targetAggregateObjects[target] else {
            fatalError("Target dependency not found: from ( \(from) ) to ( \(target) )")
        }

        let targetProxy = addObject(
            PBXContainerItemProxy(
                containerPortal: .project(pbxProj.rootObject!),
                remoteGlobalID: .object(targetObject),
                proxyType: .nativeTarget,
                remoteInfo: target
            )
        )

        let targetDependency = addObject(
            PBXTargetDependency(
                platformFilter: platform,
                platformFilters: platforms,
                target: targetObject,
                targetProxy: targetProxy
            )
        )
        return targetDependency
    }

    func generateExternalTargetDependency(from: String, to target: String, in project: String, platform: Platform) throws -> (PBXTargetDependency, Target, PBXReferenceProxy) {
        guard let projectReference = self.project.getProjectReference(project) else {
            fatalError("project '\(project)' not found")
        }

        let pbxProj = try getPBXProj(from: projectReference)

        guard let targetObject = pbxProj.targets(named: target).first else {
            fatalError("target '\(target)' not found in project '\(project)'")
        }

        let projectFileReferenceIndex = self.pbxProj.rootObject!
            .projects
            .map { $0["ProjectRef"] as? PBXFileReference }
            .firstIndex { $0?.path == Path(projectReference.path).normalize().string }

        guard let index = projectFileReferenceIndex,
            let projectFileReference = self.pbxProj.rootObject?.projects[index]["ProjectRef"] as? PBXFileReference,
            let productsGroup = self.pbxProj.rootObject?.projects[index]["ProductGroup"] as? PBXGroup else {
            fatalError("Missing subproject file reference")
        }

        let targetProxy = addObject(
            PBXContainerItemProxy(
                containerPortal: .fileReference(projectFileReference),
                remoteGlobalID: .object(targetObject),
                proxyType: .nativeTarget,
                remoteInfo: target
            )
        )

        let productProxy = PBXContainerItemProxy(
            containerPortal: .fileReference(projectFileReference),
            remoteGlobalID: targetObject.product.flatMap(PBXContainerItemProxy.RemoteGlobalID.object),
            proxyType: .reference,
            remoteInfo: target
        )

        var path = targetObject.productNameWithExtension()

        if targetObject.productType == .staticLibrary,
            let tmpPath = path, !tmpPath.hasPrefix("lib") {
            path = "lib\(tmpPath)"
        }

        let productReferenceProxyFileType = targetObject.productNameWithExtension()
            .flatMap { Xcode.fileType(path: Path($0)) }

        let existingValue = self.pbxProj.referenceProxies.first { referenceProxy in
            referenceProxy.path == path &&
            referenceProxy.remote == productProxy &&
            referenceProxy.sourceTree == .buildProductsDir &&
            referenceProxy.fileType == productReferenceProxyFileType
        }

        let productReferenceProxy: PBXReferenceProxy
        if let existingValue = existingValue {
            productReferenceProxy = existingValue
        } else {
            addObject(productProxy)
            productReferenceProxy = addObject(
                PBXReferenceProxy(
                    fileType: productReferenceProxyFileType,
                    path: path,
                    remote: productProxy,
                    sourceTree: .buildProductsDir
                )
            )

            productsGroup.children.append(productReferenceProxy)
        }


        let targetDependency = addObject(
            PBXTargetDependency(
                name: targetObject.name,
                targetProxy: targetProxy
            )
        )

        guard let buildConfigurations = targetObject.buildConfigurationList?.buildConfigurations,
            let defaultConfigurationName = targetObject.buildConfigurationList?.defaultConfigurationName,
            let defaultConfiguration = buildConfigurations.first(where: { $0.name == defaultConfigurationName }) ?? buildConfigurations.first else {

            fatalError("Missing target info")
        }

        let productType: PBXProductType = targetObject.productType ?? .none
        let buildSettings = defaultConfiguration.buildSettings
        let settings = Settings(buildSettings: buildSettings, configSettings: [:], groups: [])
        let deploymentTargetString = buildSettings[platform.deploymentTargetSetting]?.stringValue
        let deploymentTarget = deploymentTargetString == nil ? nil : try Version.parse(deploymentTargetString!)
        let requiresObjCLinking = buildSettings["OTHER_LDFLAGS"]?.stringValue?.contains("-ObjC") ?? (productType == .staticLibrary)
        let dependencyTarget = Target(
            name: targetObject.name,
            type: productType,
            platform: platform,
            productName: targetObject.productName,
            deploymentTarget: deploymentTarget,
            settings: settings,
            requiresObjCLinking: requiresObjCLinking
        )

        return (targetDependency, dependencyTarget, productReferenceProxy)
    }

    func getPBXProj(from reference: ProjectReference) throws -> PBXProj {
        if let cachedProject = projects[reference] {
            return cachedProject
        }
        let pbxproj = try XcodeProj(pathString: (project.basePath + Path(reference.path).normalize()).string).pbxproj
        projects[reference] = pbxproj
        return pbxproj
    }

    func generateTarget(_ target: Target) throws {
        let carthageDependencies = carthageResolver.dependencies(for: target)
        let infoPlistFiles: [Config: String] = getInfoPlists(for: target)
        let sourceFileBuildPhaseOverrides = Dictionary(
            uniqueKeysWithValues: Set(infoPlistFiles.values).map { (project.basePath + $0, BuildPhaseSpec.none) }
        )
        let sourceFiles = try sourceGenerator.getAllSourceFiles(
            targetType: target.type, sources: target.sources, buildPhases: sourceFileBuildPhaseOverrides
        ).sorted { $0.path.lastComponent < $1.path.lastComponent }

        let targetDependencies = (target.transitivelyLinkDependencies ?? project.options.transitivelyLinkDependencies)
            ? getAllDependenciesPlusTransitiveNeedingEmbedding(target: target) : target.dependencies
        let targetSupportsDirectEmbed = !(target.platform.requiresSimulatorStripping &&
            (target.type.isApp || target.type == .watch2Extension))
        let directlyEmbedCarthage = target.directlyEmbedCarthageDependencies ?? targetSupportsDirectEmbed

        var ctx = TargetGenerationContext()

        try processDependencies(
            for: target,
            targetDependencies: targetDependencies,
            carthageDependencies: carthageDependencies,
            directlyEmbedCarthage: directlyEmbedCarthage,
            ctx: &ctx
        )

        ctx.dependencies.append(contentsOf: makePackagePluginDependency(for: target))

        let buildPhases = try assembleBuildPhases(for: target, sourceFiles: sourceFiles, ctx: &ctx)

        let buildRules = target.buildRules.map { buildRule in
            addObject(PBXBuildRule(
                compilerSpec: buildRule.action.compilerSpec,
                fileType: buildRule.fileType.fileType,
                isEditable: true,
                filePatterns: buildRule.fileType.pattern,
                name: buildRule.name ?? "Build Rule",
                outputFiles: buildRule.outputFiles,
                outputFilesCompilerFlags: buildRule.outputFilesCompilerFlags,
                script: buildRule.action.script,
                runOncePerArchitecture: buildRule.runOncePerArchitecture
            ))
        }

        let configs = buildTargetConfigs(
            for: target,
            sourceFiles: sourceFiles,
            infoPlistFiles: infoPlistFiles,
            carthageDependencies: carthageDependencies,
            ctx: ctx
        )

        let defaultConfigurationName = project.options.defaultConfig ?? project.configs.first?.name ?? ""
        let buildConfigList = addObject(XCConfigurationList(
            buildConfigurations: configs,
            defaultConfigurationName: defaultConfigurationName
        ))

        let targetObject = targetObjects[target.name]!
        let targetFileReference = targetFileReferences[target.name]

        targetObject.name = target.name
        targetObject.buildConfigurationList = buildConfigList
        targetObject.buildPhases = buildPhases
        targetObject.dependencies = ctx.dependencies
        targetObject.productName = target.name
        targetObject.buildRules = buildRules
        targetObject.packageProductDependencies = ctx.packageDependencies
        targetObject.product = targetFileReference
        if !target.isLegacy {
            targetObject.productType = target.type
        }

        let synchronizedRootGroups: [PBXFileSystemSynchronizedRootGroup] = sourceFiles.compactMap { sourceFile in
            guard let syncedGroup = sourceFile.fileReference as? PBXFileSystemSynchronizedRootGroup else { return nil }
            configureMembershipExceptions(
                for: syncedGroup, path: sourceFile.path, target: target,
                targetObject: targetObject, infoPlistFiles: infoPlistFiles
            )
            return syncedGroup
        }
        if !synchronizedRootGroups.isEmpty {
            targetObject.fileSystemSynchronizedGroups = synchronizedRootGroups
        }
    }


}
