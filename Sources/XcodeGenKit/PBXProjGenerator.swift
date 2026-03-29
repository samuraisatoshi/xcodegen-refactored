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

    var projects: [ProjectReference: PBXProj] = [:]

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
        guard !generated else { fatalError("Cannot use PBXProjGenerator to generate more than once") }
        generated = true

        for group in project.fileGroups {
            try sourceGenerator.getFileGroups(path: group)
        }

        let buildConfigs = makeProjectBuildConfigs()
        let configList = addObject(XCConfigurationList(
            buildConfigurations: buildConfigs,
            defaultConfigurationName: project.options.defaultConfig ?? buildConfigs.first?.name ?? ""
        ))
        let mainGroup = addObject(PBXGroup(
            children: [],
            sourceTree: .group,
            usesTabs: project.options.usesTabs,
            indentWidth: project.options.indentWidth,
            tabWidth: project.options.tabWidth
        ))
        let pbxProject = addObject(PBXProject(
            name: project.name,
            buildConfigurationList: configList,
            compatibilityVersion: project.compatibilityVersion,
            preferredProjectObjectVersion: project.preferredProjectObjectVersion.map { Int($0) },
            minimizedProjectReferenceProxies: project.minimizedProjectReferenceProxies,
            mainGroup: mainGroup,
            developmentRegion: project.options.developmentLanguage ?? "en"
        ))
        pbxProj.rootObject = pbxProject

        createTargetStubs()
        createAggregateTargetStubs()
        try setupPackageReferences()

        var derivedGroups = setupProductAndSubprojectGroups(pbxProject: pbxProject)

        try project.targets.forEach(generateTarget)
        try project.aggregateTargets.forEach(generateAggregateTarget)

        derivedGroups += makeDerivedFrameworkGroups()
        finalizeProject(pbxProject, mainGroup: mainGroup, derivedGroups: derivedGroups)

        return pbxProj
    }
}
