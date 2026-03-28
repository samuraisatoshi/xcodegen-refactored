import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension SourceGenerator {

    func createLocalPackage(path: Path, group: Path?) throws {
        var parentGroup: String = project.options.localPackagesGroup ?? "Packages"
        if let group {
          parentGroup = group.string
        }

        let absolutePath = project.basePath + path.normalize()

        // Get the local package's relative path from the project root
        let fileReferencePath = try? absolutePath.relativePath(from: basePath).string

        let fileReference = addObject(
            PBXFileReference(
                sourceTree: .sourceRoot,
                name: absolutePath.lastComponent,
                lastKnownFileType: "folder",
                path: fileReferencePath
            )
        )

        if parentGroup == "" {
            rootGroups.insert(fileReference)
        } else {
            let parentGroups = parentGroup.components(separatedBy: "/")
            createParentGroups(parentGroups, for: fileReference)
        }
    }

    /// Create a group or return an existing one at the path.
    /// Any merged children are added to a new group or merged into an existing one.
    func getGroup(path: Path, name: String? = nil, mergingChildren children: [PBXFileElement], createIntermediateGroups: Bool, hasCustomParent: Bool, isBaseGroup: Bool) -> PBXGroup {
        let groupReference: PBXGroup

        if let cachedGroup = groupsByPath[path] {
            var cachedGroupChildren = cachedGroup.children
            for child in children {
                // only add the children that aren't already in the cachedGroup
                // Check equality by path and sourceTree because XcodeProj.PBXObject.== is very slow.
                if !cachedGroupChildren.contains(where: { $0.name == child.name && $0.path == child.path && $0.sourceTree == child.sourceTree }) {
                    cachedGroupChildren.append(child)
                    child.parent = cachedGroup
                }
            }
            cachedGroup.children = cachedGroupChildren
            groupReference = cachedGroup
        } else {

            // lives outside the project base path
            let isOutOfBasePath = !path.absolute().string.contains(project.basePath.absolute().string)

            // whether the given path is a strict parent of the project base path
            // e.g. foo/bar is a parent of foo/bar/baz, but not foo/baz
            let isParentOfBasePath = isOutOfBasePath && ((try? path.isParent(of: project.basePath)) == true)

            // has no valid parent paths
            let isRootPath = (isBaseGroup && isOutOfBasePath && isParentOfBasePath) || path.parent() == project.basePath

            // is a top level group in the project
            let isTopLevelGroup = !hasCustomParent && ((isBaseGroup && !createIntermediateGroups) || isRootPath || isParentOfBasePath)

            let groupName = name ?? path.lastComponent

            let groupPath = resolveGroupPath(path, isTopLevelGroup: hasCustomParent || isTopLevelGroup)

            let group = PBXGroup(
                children: children,
                sourceTree: .group,
                name: groupName != groupPath ? groupName : nil,
                path: groupPath
            )
            groupReference = addObject(group)
            groupsByPath[path] = groupReference

            if isTopLevelGroup {
                rootGroups.insert(groupReference)
            }
        }
        return groupReference
    }

    /// Creates a variant group or returns an existing one at the path
    func getVariantGroup(path: Path, inPath: Path) -> PBXVariantGroup {
        let variantGroup: PBXVariantGroup
        if let cachedGroup = variantGroupsByPath[path] {
            variantGroup = cachedGroup
        } else {
            let group = PBXVariantGroup(
                sourceTree: .group,
                name: path.lastComponent
            )
            variantGroup = addObject(group)
            variantGroupsByPath[path] = variantGroup
        }
        return variantGroup
    }

    func createParentGroups(_ parentGroups: [String], for fileElement: PBXFileElement) {
        guard let parentName = parentGroups.last else {
            return
        }

        let parentPath = project.basePath + Path(parentGroups.joined(separator: "/"))
        let parentPathExists = parentPath.exists
        let parentGroupAlreadyExists = groupsByPath[parentPath] != nil

        let parentGroup = getGroup(
            path: parentPath,
            mergingChildren: [fileElement],
            createIntermediateGroups: false,
            hasCustomParent: false,
            isBaseGroup: parentGroups.count == 1
        )

        // As this path is a custom group, remove the path reference
        if !parentPathExists {
            parentGroup.name = String(parentName)
            parentGroup.path = nil
        }

        if !parentGroupAlreadyExists {
            createParentGroups(parentGroups.dropLast(), for: parentGroup)
        }
    }

    // Add groups for all parents recursively
    func createIntermediaGroups(for fileElement: PBXFileElement, at path: Path) {

        let parentPath = path.parent()
        guard parentPath != project.basePath else {
            // we've reached the top
            return
        }

        let hasParentGroup = groupsByPath[parentPath] != nil
        if !hasParentGroup {
            do {
                // if the path is a parent of the project base path (or if calculating that fails)
                // do not create a parent group
                // e.g. for project path foo/bar/baz
                //  - create foo/baz
                //  - create baz/
                //  - do not create foo
                let pathIsParentOfProject = try path.isParent(of: project.basePath)
                if pathIsParentOfProject { return }
            } catch {
                return
            }
        }
        let parentGroup = getGroup(
            path: parentPath,
            mergingChildren: [fileElement],
            createIntermediateGroups: true,
            hasCustomParent: false,
            isBaseGroup: false
        )

        if !hasParentGroup {
            createIntermediaGroups(for: parentGroup, at: parentPath)
        }
    }

    private func resolveGroupPath(_ path: Path, isTopLevelGroup: Bool) -> String {
        if isTopLevelGroup, let relativePath = try? path.relativePath(from: basePath).string {
            return relativePath
        } else {
            return path.lastComponent
        }
    }
}
