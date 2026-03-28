import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension PBXProjGenerator {

    func generateBuildScript(targetName: String, buildScript: BuildScript) throws -> PBXShellScriptBuildPhase {

        let shellScript: String
        switch buildScript.script {
        case let .path(path):
            shellScript = try (project.basePath + path).read()
        case let .script(script):
            shellScript = script
        }

        let shellScriptPhase = PBXShellScriptBuildPhase(
            name: buildScript.name ?? "Run Script",
            inputPaths: buildScript.inputFiles,
            outputPaths: buildScript.outputFiles,
            inputFileListPaths: buildScript.inputFileLists,
            outputFileListPaths: buildScript.outputFileLists,
            shellPath: buildScript.shell ?? "/bin/sh",
            shellScript: shellScript,
            runOnlyForDeploymentPostprocessing: buildScript.runOnlyWhenInstalling,
            showEnvVarsInLog: buildScript.showEnvVars,
            alwaysOutOfDate: !buildScript.basedOnDependencyAnalysis,
            dependencyFile: buildScript.discoveredDependencyFile
        )
        return addObject(shellScriptPhase)
    }

    func generateCopyFiles(targetName: String, copyFiles: BuildPhaseSpec.CopyFilesSettings, buildPhaseFiles: [PBXBuildFile]) -> PBXCopyFilesBuildPhase {
        let copyFilesBuildPhase = PBXCopyFilesBuildPhase(
            dstPath: copyFiles.subpath,
            dstSubfolderSpec: copyFiles.destination.destination,
            files: buildPhaseFiles
        )
        return addObject(copyFilesBuildPhase)
    }

    func configureMembershipExceptions(
        for syncedGroup: PBXFileSystemSynchronizedRootGroup,
        path syncedPath: Path,
        target: Target,
        targetObject: PBXTarget,
        infoPlistFiles: [Config: String]
    ) {
        guard let targetSource = target.sources.first(where: {
            (project.basePath + $0.path).normalize() == syncedPath
        }) else { return }

        var exceptions: Set<String> = Set(
            sourceGenerator.syncedFolderExceptions(for: targetSource, at: syncedPath)
                .compactMap { try? $0.relativePath(from: syncedPath).string }
        )

        for infoPlistPath in Set(infoPlistFiles.values) {
            let relative = try? (project.basePath + infoPlistPath).normalize()
                .relativePath(from: syncedPath)
            if let rel = relative?.string, !rel.hasPrefix("..") {
                exceptions.insert(rel)
            }
        }

        guard !exceptions.isEmpty else { return }

        let exceptionSet = PBXFileSystemSynchronizedBuildFileExceptionSet(
            target: targetObject,
            membershipExceptions: exceptions.sorted(),
            publicHeaders: nil,
            privateHeaders: nil,
            additionalCompilerFlagsByRelativePath: nil,
            attributesByRelativePath: nil
        )
        addObject(exceptionSet)
        syncedGroup.exceptions = (syncedGroup.exceptions ?? []) + [exceptionSet]
    }
}
