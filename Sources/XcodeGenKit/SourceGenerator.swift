import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import XcodeGenCore

struct SourceFile {
    let path: Path
    let fileReference: PBXFileElement
    let buildFile: PBXBuildFile
    let buildPhase: BuildPhaseSpec?
}

class SourceGenerator {

    var rootGroups: Set<PBXFileElement> = []
    let project: Project
    let pbxProj: PBXProj
    var fileReferencesByPath: [String: PBXFileElement] = [:]
    var groupsByPath: [Path: PBXGroup] = [:]
    var variantGroupsByPath: [Path: PBXVariantGroup] = [:]
    var syncedGroupsByPath: [String: PBXFileSystemSynchronizedRootGroup] = [:]
    var defaultExcludedFiles = [".DS_Store"]
    let defaultExcludedExtensions = ["orig"]
    var knownRegions: Set<String> = []

    /// Compiled regex cache for destination path inference — built once per process lifetime.
    /// Key: SupportedDestination; Value: (directory pattern, filename suffix pattern).
    private static let destinationRegexCache: [SupportedDestination: (NSRegularExpression?, NSRegularExpression?)] =
        Dictionary(uniqueKeysWithValues: SupportedDestination.allCases.map { destination in
            let regex1 = try? NSRegularExpression(pattern: "\\/\(destination)\\/", options: .caseInsensitive)
            let regex2 = try? NSRegularExpression(pattern: "\\_\(destination)\\.swift$", options: .caseInsensitive)
            return (destination, (regex1, regex2))
        })

    /// The effective base path for resolving group and file paths in the generated project.
    /// Uses `projectDirectory` when the xcodeproj is generated in a different location than the spec.
    var basePath: Path {
        projectDirectory ?? project.basePath
    }

    private let projectDirectory: Path?

    init(project: Project, pbxProj: PBXProj, projectDirectory: Path?) {
        self.project = project
        self.pbxProj = pbxProj
        self.projectDirectory = projectDirectory
    }

    @discardableResult
    func addObject<T: PBXObject>(_ object: T, context: String? = nil) -> T {
        pbxProj.add(object: object)
        object.context = context
        return object
    }

    /// Collects an array complete of all `SourceFile` objects that make up the target based on the provided `TargetSource` definitions.
    ///
    /// - Parameters:
    ///   - targetType: The type of target that the source files should belong to.
    ///   - sources: The array of sources defined as part of the targets spec.
    ///   - buildPhases: A dictionary containing any build phases that should be applied to source files at specific paths in the event that the associated `TargetSource` didn't already define a `buildPhase`. Values from this dictionary are used in cases where the project generator knows more about a file than the spec/filesystem does (i.e if the file should be treated as the targets Info.plist and so on).
    func getAllSourceFiles(targetType: PBXProductType, sources: [TargetSource], buildPhases: [Path: BuildPhaseSpec]) throws -> [SourceFile] {
        try sources.flatMap { try getSourceFiles(targetType: targetType, targetSource: $0, buildPhases: buildPhases) }
    }

    // get groups without build files. Use for Project.fileGroups
    func getFileGroups(path: String) throws {
        _ = try getSourceFiles(targetType: .none, targetSource: TargetSource(path: path), buildPhases: [:])
    }

    func getFileType(path: Path) -> FileType? {
        if let fileExtension = path.extension {
            return project.options.fileTypes[fileExtension] ?? FileType.defaultFileTypes[fileExtension]
        } else {
            return nil
        }
    }

    func generateSourceFile(targetType: PBXProductType, targetSource: TargetSource, path: Path, fileReference: PBXFileElement? = nil, buildPhases: [Path: BuildPhaseSpec]) -> SourceFile {
        let fileReference = fileReference ?? fileReferencesByPath[path.string.lowercased()]!
        var settings: [String: BuildFileSetting] = [:]
        let fileType = getFileType(path: path)
        var attributes: [String] = targetSource.attributes + (fileType?.attributes ?? [])
        var chosenBuildPhase: BuildPhaseSpec?
        var compilerFlags: String = ""
        let assetTags: [String] = targetSource.resourceTags + (fileType?.resourceTags ?? [])

        let headerVisibility = targetSource.headerVisibility ?? .public

        if let buildPhase = targetSource.buildPhase {
            chosenBuildPhase = buildPhase
        } else if resolvedTargetSourceType(for: targetSource, at: path) == .folder {
            chosenBuildPhase = .resources
        } else if let buildPhase = buildPhases[path] {
            chosenBuildPhase = buildPhase
        } else {
            chosenBuildPhase = getDefaultBuildPhase(for: path, targetType: targetType)
        }

        if chosenBuildPhase == .headers && targetType == .staticLibrary {
            // Static libraries don't support the header build phase
            // For public headers they need to be copied
            if headerVisibility == .public {
                chosenBuildPhase = .copyFiles(BuildPhaseSpec.CopyFilesSettings(
                    destination: .productsDirectory,
                    subpath: "include/$(PRODUCT_NAME)",
                    phaseOrder: .preCompile
                ))
            } else {
                chosenBuildPhase = nil
            }
        }

        if chosenBuildPhase == .headers {
            if headerVisibility != .project {
                // Xcode doesn't write the default of project
                attributes.append(headerVisibility.settingName)
            }
        }

        if let flags = fileType?.compilerFlags {
            compilerFlags += flags.joined(separator: " ")
        }

        if !targetSource.compilerFlags.isEmpty {
            if !compilerFlags.isEmpty {
                compilerFlags += " "
            }
            compilerFlags += targetSource.compilerFlags.joined(separator: " ")
        }

        if chosenBuildPhase == .sources && !compilerFlags.isEmpty {
            settings["COMPILER_FLAGS"] = .string(compilerFlags)
        }

        if !attributes.isEmpty {
            settings["ATTRIBUTES"] = .array(attributes)
        }

        if chosenBuildPhase == .resources && !assetTags.isEmpty {
            settings["ASSET_TAGS"] = .array(assetTags)
        }

        let platforms = makeDestinationFilters(for: path, with: targetSource.destinationFilters, or: targetSource.inferDestinationFiltersByPath)

        let buildFile = PBXBuildFile(file: fileReference, settings: settings.isEmpty ? nil : settings, platformFilters: platforms)
        return SourceFile(
            path: path,
            fileReference: fileReference,
            buildFile: buildFile,
            buildPhase: chosenBuildPhase
        )
    }

    /// Returns the resolved `SourceType` for a given `TargetSource`.
    ///
    /// While `TargetSource` declares `type`, its optional and in the event that the value is not defined then we must resolve a sensible default based on the path of the source.
    func resolvedTargetSourceType(for targetSource: TargetSource, at path: Path) -> SourceType {
        if let chosenType = targetSource.type {
            return chosenType
        } else {
            if path.isFile || path.extension != nil {
                return .file
            } else if let sourceType = project.options.defaultSourceDirectoryType {
                return sourceType
            } else {
                return .group
            }
        }
    }

    private func makeDestinationFilters(for path: Path, with filters: [SupportedDestination]?, or inferDestinationFiltersByPath: Bool?) -> [String]? {
        if let filters = filters, !filters.isEmpty {
            return filters.map { $0.string }
        } else if inferDestinationFiltersByPath == true {
            for destination in SupportedDestination.allCases {
                guard let (regex1, regex2) = SourceGenerator.destinationRegexCache[destination] else { continue }
                if regex1?.isMatch(to: path.string) == true || regex2?.isMatch(to: path.string) == true {
                    return [destination.string]
                }
            }
        }
        return nil
    }
}
