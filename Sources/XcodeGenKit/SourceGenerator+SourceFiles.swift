import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import XcodeGenCore

extension SourceGenerator {

    /// Returns the expanded set of excluded paths for a target source by resolving its exclude glob patterns.
    func expandedExcludes(for targetSource: TargetSource) -> Set<Path> {
        getSourceMatches(targetSource: targetSource, patterns: targetSource.excludes)
    }

    /// Returns the expanded set of exception paths for a synced folder, including excludes and non-included files.
    func syncedFolderExceptions(for targetSource: TargetSource, at syncedPath: Path) -> Set<Path> {
        let excludePaths = expandedExcludes(for: targetSource)
        if targetSource.includes.isEmpty {
            return excludePaths
        }

        let includePaths = SortedArray(getSourceMatches(targetSource: targetSource, patterns: targetSource.includes))
        var exceptions: Set<Path> = []

        func findExceptions(in path: Path) {
            guard let children = try? path.children() else { return }

            for child in children {
                if isIncludedPath(child, excludePaths: excludePaths, includePaths: includePaths) {
                    if child.isDirectory && !Xcode.isDirectoryFileWrapper(path: child) {
                        findExceptions(in: child)
                    }
                } else {
                    exceptions.insert(child)
                }
            }
        }

        findExceptions(in: syncedPath)
        return exceptions
    }

    /// Checks whether the path is not in any default or TargetSource excludes
    func isIncludedPath(_ path: Path, excludePaths: Set<Path>, includePaths: SortedArray<Path>?) -> Bool {
        return !defaultExcludedFiles.contains(where: { path.lastComponent == $0 })
            && !(path.extension.map(defaultExcludedExtensions.contains) ?? false)
            && !excludePaths.contains(path)
            // If includes is empty, it's included. If it's not empty, the path either needs to match exactly, or it needs to be a direct parent of an included path.
            && (includePaths.flatMap { _isIncludedPathSorted(path, sortedPaths: $0) } ?? true)
    }

    /// creates source files
    func getSourceFiles(targetType: PBXProductType, targetSource: TargetSource, buildPhases: [Path: BuildPhaseSpec]) throws -> [SourceFile] {

        // generate excluded paths
        let path = project.basePath + targetSource.path
        let excludePaths = getSourceMatches(targetSource: targetSource, patterns: targetSource.excludes)
        // generate included paths. Excluded paths will override this.
        let includePaths = targetSource.includes.isEmpty ? nil : getSourceMatches(targetSource: targetSource, patterns: targetSource.includes)

        let type = resolvedTargetSourceType(for: targetSource, at: path)

        let customParentGroups = (targetSource.group ?? "").split(separator: "/").map { String($0) }
        let hasCustomParent = !customParentGroups.isEmpty

        let createIntermediateGroups = targetSource.createIntermediateGroups ?? project.options.createIntermediateGroups

        var sourceFiles: [SourceFile] = []
        let sourceReference: PBXFileElement
        var sourcePath = path
        switch type {
        case .folder:
            let fileReference = getFileReference(
                path: path,
                inPath: project.basePath,
                name: targetSource.name ?? path.lastComponent,
                sourceTree: .sourceRoot,
                lastKnownFileType: "folder"
            )

            if !(createIntermediateGroups || hasCustomParent) || path.parent() == project.basePath {
                rootGroups.insert(fileReference)
            }

            let sourceFile = generateSourceFile(targetType: targetType, targetSource: targetSource, path: path, buildPhases: buildPhases)

            sourceFiles.append(sourceFile)
            sourceReference = fileReference
        case .file:
            let parentPath = path.parent()
            let fileReference = getFileReference(path: path, inPath: parentPath, name: targetSource.name)

            let sourceFile = generateSourceFile(targetType: targetType, targetSource: targetSource, path: path, buildPhases: buildPhases)

            if hasCustomParent {
                sourcePath = path
                sourceReference = fileReference
            } else if parentPath == project.basePath {
                sourcePath = path
                sourceReference = fileReference
                rootGroups.insert(fileReference)
            } else {
                let parentGroup = getGroup(
                    path: parentPath,
                    mergingChildren: [fileReference],
                    createIntermediateGroups: createIntermediateGroups,
                    hasCustomParent: hasCustomParent,
                    isBaseGroup: true
                )
                sourcePath = parentPath
                sourceReference = parentGroup
            }
            sourceFiles.append(sourceFile)

        case .group:
            if targetSource.optional && !path.exists {
                // This group is missing, so if's optional just return an empty array
                return []
            }

            let (groupSourceFiles, groups) = try getGroupSources(
                targetType: targetType,
                targetSource: targetSource,
                path: path,
                isBaseGroup: true,
                hasCustomParent: hasCustomParent,
                excludePaths: excludePaths,
                includePaths: includePaths.flatMap(SortedArray.init(_:)),
                buildPhases: buildPhases
            )

            let group = groups.first!
            if let name = targetSource.name {
                group.name = name
            }

            sourceFiles += groupSourceFiles
            sourceReference = group
        case .syncedFolder:

            let relativePath = (try? path.relativePath(from: project.basePath)) ?? path
            let resolvedExplicitFolders = resolveExplicitFolders(targetSource: targetSource)

            let syncedRootGroup: PBXFileSystemSynchronizedRootGroup
            if let existingGroup = syncedGroupsByPath[relativePath.string] {
                syncedRootGroup = existingGroup
                let newExplicitFolders = Set(syncedRootGroup.explicitFolders ?? [])
                    .union(resolvedExplicitFolders)
                    .sorted()
                syncedRootGroup.explicitFolders = newExplicitFolders
            } else {
                syncedRootGroup = PBXFileSystemSynchronizedRootGroup(
                    sourceTree: .group,
                    path: relativePath.string,
                    name: targetSource.name,
                    explicitFileTypes: [:],
                    exceptions: [],
                    explicitFolders: resolvedExplicitFolders
                )
                addObject(syncedRootGroup)
                syncedGroupsByPath[relativePath.string] = syncedRootGroup
            }
            sourceReference = syncedRootGroup

            if !(createIntermediateGroups || hasCustomParent) || path.parent() == project.basePath {
                rootGroups.insert(syncedRootGroup)
            }

            let sourceFile = generateSourceFile(
                targetType: targetType,
                targetSource: targetSource,
                path: path,
                fileReference: syncedRootGroup,
                buildPhases: buildPhases
            )
            sourceFiles.append(sourceFile)
        }

        if hasCustomParent {
            createParentGroups(customParentGroups, for: sourceReference)
            try makePathRelative(for: sourceReference, at: path)
        } else if createIntermediateGroups {
            createIntermediaGroups(for: sourceReference, at: sourcePath)
            if type != .folder {
                try makePathRelative(for: sourceReference, at: sourcePath)
            }
        }

        return sourceFiles
    }

    // MARK: - Private

    /// Collects all the excluded paths within the targetSource
    private func getSourceMatches(targetSource: TargetSource, patterns: [String]) -> Set<Path> {
        let rootSourcePath = project.basePath + targetSource.path

        return Set(
            patterns.parallelMap { pattern in
                guard !pattern.isEmpty else { return [] }
                return Glob(pattern: "\(rootSourcePath)/\(pattern)")
                    .map { Path($0) }
                    .map {
                        guard $0.isDirectory else {
                            return [$0]
                        }

                        return (try? $0.recursiveChildren()) ?? []
                    }
                    .reduce([], +)
            }
            .reduce([], +)
        )
    }

    /// Expands glob patterns in `explicitFolders` relative to the synced root path.
    private func resolveExplicitFolders(targetSource: TargetSource) -> [String] {
        let rootSourcePath = project.basePath + targetSource.path

        return targetSource.explicitFolders.flatMap { pattern in
            let matches = Glob(pattern: "\(rootSourcePath)/\(pattern)")
                .map { Path($0) }
                .filter { $0.isDirectory }
                .compactMap { try? $0.relativePath(from: rootSourcePath).string }
                .sorted()
            return matches.isEmpty ? [pattern] : matches
        }
    }

    private func _isIncludedPathSorted(_ path: Path, sortedPaths: SortedArray<Path>) -> Bool {
        guard let idx = sortedPaths.firstIndex(where: { $0 >= path }) else { return false }
        let foundPath = sortedPaths.value[idx]
        return foundPath.description.hasPrefix(path.description)
    }

    /// Gets all the children paths that aren't excluded
    private func getSourceChildren(targetSource: TargetSource, dirPath: Path, excludePaths: Set<Path>, includePaths: SortedArray<Path>?) throws -> [Path] {
        try dirPath.children()
            .filter {
                if $0.isDirectory {
                    let children = try $0.children()

                    if children.isEmpty {
                        return project.options.generateEmptyDirectories
                    }

                    return !children
                        .filter { self.isIncludedPath($0, excludePaths: excludePaths, includePaths: includePaths) }
                        .isEmpty
                } else if $0.isFile {
                    return self.isIncludedPath($0, excludePaths: excludePaths, includePaths: includePaths)
                } else {
                    return false
                }
            }
    }

    /// creates all the source files and groups they belong to for a given targetSource
    private func getGroupSources(
        targetType: PBXProductType,
        targetSource: TargetSource,
        path: Path,
        isBaseGroup: Bool,
        hasCustomParent: Bool,
        excludePaths: Set<Path>,
        includePaths: SortedArray<Path>?,
        buildPhases: [Path: BuildPhaseSpec]
    ) throws -> (sourceFiles: [SourceFile], groups: [PBXGroup]) {

        let children = try getSourceChildren(targetSource: targetSource, dirPath: path, excludePaths: excludePaths, includePaths: includePaths)

        let createIntermediateGroups = targetSource.createIntermediateGroups ?? project.options.createIntermediateGroups
        let nonLocalizedChildren = children.filter { $0.extension != "lproj" }
        let stringCatalogChildren = children.filter { $0.extension == "xcstrings" }

        let directories = nonLocalizedChildren
            .filter {
                if let fileType = getFileType(path: $0) {
                    return !fileType.file
                } else {
                    return $0.isDirectory && !Xcode.isDirectoryFileWrapper(path: $0)
                }
            }

        let filePaths = nonLocalizedChildren
            .filter {
                if let fileType = getFileType(path: $0) {
                    return fileType.file
                } else {
                    return $0.isFile || $0.isDirectory && Xcode.isDirectoryFileWrapper(path: $0)
                }
            }

        let localisedDirectories = children
            .filter { $0.extension == "lproj" }

        var groupChildren: [PBXFileElement] = filePaths.map { getFileReference(path: $0, inPath: path) }
        var allSourceFiles: [SourceFile] = filePaths.map {
            generateSourceFile(targetType: targetType, targetSource: targetSource, path: $0, buildPhases: buildPhases)
        }
        var groups: [PBXGroup] = []

        for path in directories {

            let subGroups = try getGroupSources(
                targetType: targetType,
                targetSource: targetSource,
                path: path,
                isBaseGroup: false,
                hasCustomParent: false,
                excludePaths: excludePaths,
                includePaths: includePaths,
                buildPhases: buildPhases
            )

            guard !subGroups.sourceFiles.isEmpty || project.options.generateEmptyDirectories else {
                continue
            }

            allSourceFiles += subGroups.sourceFiles

            if let firstGroup = subGroups.groups.first {
                groupChildren.append(firstGroup)
                groups += subGroups.groups
            } else if project.options.generateEmptyDirectories {
                groups += subGroups.groups
            }
        }

        // find the base localised directory
        let baseLocalisedDirectory: Path? = {
            func findLocalisedDirectory(by languageId: String) -> Path? {
                localisedDirectories.first { $0.lastComponent == "\(languageId).lproj" }
            }
            return findLocalisedDirectory(by: "Base") ??
                findLocalisedDirectory(by: NSLocale.canonicalLanguageIdentifier(from: project.options.developmentLanguage ?? "en"))
        }()

        knownRegions.formUnion(localisedDirectories.map { $0.lastComponentWithoutExtension })

        // XCode 15 - Detect known regions from locales present in string catalogs

        let stringCatalogsLocales = stringCatalogChildren
            .compactMap { StringCatalog(from: $0) }
            .reduce(Set<String>(), { partialResult, stringCatalog in
                partialResult.union(stringCatalog.includedLocales)
            })
        knownRegions.formUnion(stringCatalogsLocales)

        // create variant groups of the base localisation first
        var baseLocalisationVariantGroups: [PBXVariantGroup] = []

        if let baseLocalisedDirectory = baseLocalisedDirectory {
            let filePaths = try baseLocalisedDirectory.children()
                .filter { self.isIncludedPath($0, excludePaths: excludePaths, includePaths: includePaths) }
                .sorted()
            for filePath in filePaths {
                let variantGroup = getVariantGroup(path: filePath, inPath: path)
                groupChildren.append(variantGroup)
                baseLocalisationVariantGroups.append(variantGroup)

                let sourceFile = generateSourceFile(targetType: targetType,
                                                    targetSource: targetSource,
                                                    path: filePath,
                                                    fileReference: variantGroup,
                                                    buildPhases: buildPhases)
                allSourceFiles.append(sourceFile)
            }
        }

        // add references to localised resources into base localisation variant groups
        for localisedDirectory in localisedDirectories {
            let localisationName = localisedDirectory.lastComponentWithoutExtension
            let filePaths = try localisedDirectory.children()
                .filter { self.isIncludedPath($0, excludePaths: excludePaths, includePaths: includePaths) }
                .sorted { $0.lastComponent < $1.lastComponent }
            for filePath in filePaths {
                // find base localisation variant group
                // ex: Foo.strings will be added to Foo.strings or Foo.storyboard variant group
                let variantGroup = baseLocalisationVariantGroups
                    .first {
                        Path($0.name!).lastComponent == filePath.lastComponent

                    } ?? baseLocalisationVariantGroups.first {
                        Path($0.name!).lastComponentWithoutExtension == filePath.lastComponentWithoutExtension
                    }

                let fileReference = getFileReference(
                    path: filePath,
                    inPath: path,
                    name: variantGroup != nil ? localisationName : filePath.lastComponent
                )

                if let variantGroup = variantGroup {
                    if !variantGroup.children.contains(fileReference) {
                        variantGroup.children.append(fileReference)
                    }
                } else {
                    // add SourceFile to group if there is no Base.lproj directory
                    let sourceFile = generateSourceFile(targetType: targetType,
                                                        targetSource: targetSource,
                                                        path: filePath,
                                                        fileReference: fileReference,
                                                        buildPhases: buildPhases)
                    allSourceFiles.append(sourceFile)
                    groupChildren.append(fileReference)
                }
            }
        }

        let group = getGroup(
            path: path,
            mergingChildren: groupChildren,
            createIntermediateGroups: createIntermediateGroups,
            hasCustomParent: hasCustomParent,
            isBaseGroup: isBaseGroup
        )
        if createIntermediateGroups {
            createIntermediaGroups(for: group, at: path)
        }

        groups.insert(group, at: 0)
        return (allSourceFiles, groups)
    }

    // Make the fileElement path and name relative to its parents aggregated paths
    private func makePathRelative(for fileElement: PBXFileElement, at path: Path) throws {
        // This makes the fileElement path relative to its parent and not to the project. Xcode then rebuilds the actual
        // path for the file based on the hierarchy this fileElement lives in.
        var paths: [String] = []
        var element: PBXFileElement = fileElement
        while true {
            guard let parent = element.parent else { break }

            if let path = parent.path {
                paths.insert(path, at: 0)
            }

            element = parent
        }

        let completePath = (basePath) + Path(paths.joined(separator: "/"))
        let relativePath = try path.relativePath(from: completePath)
        let relativePathString = relativePath.string

        if relativePathString != fileElement.path {
            fileElement.path = relativePathString
            fileElement.name = relativePath.lastComponent
        }
    }
}
