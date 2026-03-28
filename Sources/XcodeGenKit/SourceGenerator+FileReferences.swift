import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import XcodeGenCore

extension SourceGenerator {

    func getContainedFileReference(path: Path) -> PBXFileElement {
        let createIntermediateGroups = project.options.createIntermediateGroups

        let parentPath = path.parent()
        let fileReference = getFileReference(path: path, inPath: parentPath)
        let parentGroup = getGroup(
            path: parentPath,
            mergingChildren: [fileReference],
            createIntermediateGroups: createIntermediateGroups,
            hasCustomParent: false,
            isBaseGroup: true
        )

        if createIntermediateGroups {
            createIntermediaGroups(for: parentGroup, at: parentPath)
        }
        return fileReference
    }

    func getFileReference(path: Path, inPath: Path, name: String? = nil, sourceTree: PBXSourceTree = .group, lastKnownFileType: String? = nil) -> PBXFileElement {
        let fileReferenceKey = path.string.lowercased()
        if let fileReference = fileReferencesByPath[fileReferenceKey] {
            return fileReference
        } else {
            let fileReferencePath = (try? path.relativePath(from: inPath)) ?? path
            var fileReferenceName: String? = name ?? fileReferencePath.lastComponent
            if fileReferencePath.string == fileReferenceName {
                fileReferenceName = nil
            }
            let lastKnownFileType = lastKnownFileType ?? Xcode.fileType(path: path)

            if path.extension == "xcdatamodeld" {
                let versionedModels = (try? path.children()) ?? []

                // Sort the versions alphabetically
                let sortedPaths = versionedModels
                    .filter { $0.extension == "xcdatamodel" }
                    .sorted { $0.string.localizedStandardCompare($1.string) == .orderedAscending }

                let modelFileReferences =
                    sortedPaths.map { path in
                        addObject(
                            PBXFileReference(
                                sourceTree: .group,
                                lastKnownFileType: "wrapper.xcdatamodel",
                                path: path.lastComponent
                            )
                        )
                    }
                // If no current version path is found we fall back to alphabetical
                // order by taking the last item in the sortedPaths array
                let currentVersionPath = findCurrentCoreDataModelVersionPath(using: versionedModels) ?? sortedPaths.last
                let currentVersion: PBXFileReference? = {
                    guard let indexOf = sortedPaths.firstIndex(where: { $0 == currentVersionPath }) else { return nil }
                    return modelFileReferences[indexOf]
                }()
                let versionGroup = addObject(XCVersionGroup(
                    currentVersion: currentVersion,
                    path: fileReferencePath.string,
                    sourceTree: sourceTree,
                    versionGroupType: "wrapper.xcdatamodel",
                    children: modelFileReferences
                ))
                fileReferencesByPath[fileReferenceKey] = versionGroup
                return versionGroup
            } else {
                // For all extensions other than `xcdatamodeld`
                let fileReference = addObject(
                    PBXFileReference(
                        sourceTree: sourceTree,
                        name: fileReferenceName,
                        lastKnownFileType: lastKnownFileType,
                        path: fileReferencePath.string
                    )
                )
                fileReferencesByPath[fileReferenceKey] = fileReference
                return fileReference
            }
        }
    }

    /// returns a default build phase for a given path. This is based off the filename
    func getDefaultBuildPhase(for path: Path, targetType: PBXProductType) -> BuildPhaseSpec? {
        if let buildPhase = getFileType(path: path)?.buildPhase {
            return buildPhase
        }
        if let fileExtension = path.extension {
            switch fileExtension {
            case "modulemap":
                guard targetType == .staticLibrary else { return nil }
                return .copyFiles(BuildPhaseSpec.CopyFilesSettings(
                    destination: .productsDirectory,
                    subpath: "include/$(PRODUCT_NAME)",
                    phaseOrder: .preCompile
                ))
            case "swiftcrossimport":
                guard targetType == .framework else { return nil }
                return .copyFiles(BuildPhaseSpec.CopyFilesSettings(
                    destination: .productsDirectory,
                    subpath: "$(PRODUCT_NAME).framework/Modules",
                    phaseOrder: .preCompile
                ))
            default:
                return .resources
            }
        }
        return nil
    }

    private func findCurrentCoreDataModelVersionPath(using versionedModels: [Path]) -> Path? {
        // Find and parse the current version model stored in the .xccurrentversion file
        guard
            let versionPath = versionedModels.first(where: { $0.lastComponent == ".xccurrentversion" }),
            let data = try? versionPath.read(),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let versionString = plist["_XCCurrentVersionName"] as? String else {
            return nil
        }
        return versionedModels.first(where: { $0.lastComponent == versionString })
    }
}
