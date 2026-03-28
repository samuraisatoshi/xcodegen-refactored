import Foundation
import ProjectSpec
import XcodeProj

/// Accumulator state for a single `generateTarget` invocation.
/// Holds all mutable collections that were previously captured as local `var`
/// bindings by nested functions inside `generateTarget`. Extracting them here
/// allows the nested functions to be promoted to private methods that receive
/// `inout TargetGenerationContext` — eliminating the god-function pattern.
struct TargetGenerationContext {
    var anyDependencyRequiresObjCLinking: Bool = false
    var dependencies: [PBXTargetDependency] = []
    var targetFrameworkBuildFiles: [PBXBuildFile] = []
    var frameworkBuildPaths: Set<String> = []
    var customCopyDependenciesReferences: [PBXBuildFile] = []
    var copyFilesBuildPhasesFiles: [BuildPhaseSpec.CopyFilesSettings: [PBXBuildFile]] = [:]
    var copyFrameworksReferences: [PBXBuildFile] = []
    var copyResourcesReferences: [PBXBuildFile] = []
    var copyBundlesReferences: [PBXBuildFile] = []
    var copyWatchReferences: [PBXBuildFile] = []
    var packageDependencies: [XCSwiftPackageProductDependency] = []
    var extensions: [PBXBuildFile] = []
    var extensionKitExtensions: [PBXBuildFile] = []
    var systemExtensions: [PBXBuildFile] = []
    var appClips: [PBXBuildFile] = []
    var carthageFrameworksToEmbed: [String] = []
    var buildFileCopyPhases: [PBXBuildFile: BuildPhaseSpec.CopyFilesSettings] = [:]
}
