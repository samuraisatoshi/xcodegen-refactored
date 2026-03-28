import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension PBXProjGenerator {

    // MARK: - Embed / Link settings

    func getEmbedSettings(dependency: Dependency, codeSign: Bool) -> [String: BuildFileSetting] {
        var embedAttributes: [String] = []
        if codeSign {
            embedAttributes.append("CodeSignOnCopy")
        }
        if dependency.removeHeaders {
            embedAttributes.append("RemoveHeadersOnCopy")
        }
        return ["ATTRIBUTES": .array(embedAttributes)]
    }

    func getDependencyFrameworkSettings(dependency: Dependency) -> [String: BuildFileSetting]? {
        var linkingAttributes: [String] = []
        if dependency.weakLink {
            linkingAttributes.append("Weak")
        }
        return !linkingAttributes.isEmpty ? ["ATTRIBUTES": .array(linkingAttributes)] : nil
    }

    // MARK: - Source file build file helpers

    func getBuildFilesForSourceFiles(_ sourceFiles: [SourceFile]) -> [PBXBuildFile] {
        sourceFiles
            .reduce(into: [SourceFile]()) { output, sourceFile in
                if !output.contains(where: { $0.fileReference === sourceFile.fileReference }) {
                    output.append(sourceFile)
                }
            }
            .map { addObject($0.buildFile) }
    }

    func getBuildFilesForPhase(_ buildPhase: BuildPhase, in sourceFiles: [SourceFile]) -> [PBXBuildFile] {
        let filteredSourceFiles = sourceFiles.filter { $0.buildPhase?.buildPhase == buildPhase }
        return getBuildFilesForSourceFiles(filteredSourceFiles)
    }

    func getBuildFilesForCopyFilesPhases(in sourceFiles: [SourceFile]) -> [BuildPhaseSpec.CopyFilesSettings: [PBXBuildFile]] {
        var sourceFilesByCopyFiles: [BuildPhaseSpec.CopyFilesSettings: [SourceFile]] = [:]
        for sourceFile in sourceFiles {
            guard case let .copyFiles(copyFilesSettings)? = sourceFile.buildPhase else { continue }
            sourceFilesByCopyFiles[copyFilesSettings, default: []].append(sourceFile)
        }
        return sourceFilesByCopyFiles.mapValues { getBuildFilesForSourceFiles($0) }
    }

    // MARK: - Copy files phase factory

    func getPBXCopyFilesBuildPhase(
        dstSubfolderSpec: PBXCopyFilesBuildPhase.SubFolder,
        dstPath: String = "",
        name: String,
        files: [PBXBuildFile],
        target: Target
    ) -> PBXCopyFilesBuildPhase {
        PBXCopyFilesBuildPhase(
            dstPath: dstPath,
            dstSubfolderSpec: dstSubfolderSpec,
            name: name,
            buildActionMask: target.onlyCopyFilesOnInstall ? PBXProjGenerator.copyFilesActionMask : PBXBuildPhase.defaultBuildActionMask,
            files: files,
            runOnlyForDeploymentPostprocessing: target.onlyCopyFilesOnInstall ? true : false
        )
    }

    // MARK: - Custom copy phase splitting

    func splitCopyDepsByDestination(
        _ references: [PBXBuildFile],
        ctx: TargetGenerationContext
    ) -> [BuildPhaseSpec.CopyFilesSettings: [PBXBuildFile]] {
        var result = [BuildPhaseSpec.CopyFilesSettings: [PBXBuildFile]]()
        for reference in references {
            guard let key = ctx.buildFileCopyPhases[reference] else { continue }
            result[key, default: []].append(reference)
        }
        return result
    }

    // MARK: - Resources build phase

    func addResourcesBuildPhase(
        target: Target,
        sourceFiles: [SourceFile],
        ctx: TargetGenerationContext,
        buildPhases: inout [PBXBuildPhase]
    ) {
        let resourcesBuildPhaseFiles = getBuildFilesForPhase(.resources, in: sourceFiles) + ctx.copyResourcesReferences
        let hasSynchronizedRootGroups = sourceFiles.contains { $0.fileReference is PBXFileSystemSynchronizedRootGroup }
        if !resourcesBuildPhaseFiles.isEmpty || hasSynchronizedRootGroups {
            let resourcesBuildPhase = addObject(PBXResourcesBuildPhase(files: resourcesBuildPhaseFiles))
            buildPhases.append(resourcesBuildPhase)
        }
    }
}
