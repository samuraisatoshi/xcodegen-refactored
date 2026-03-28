import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension PBXProjGenerator {

    func makePlatformFilter(for filter: Dependency.PlatformFilter) -> String? {
        switch filter {
        case .all:
            return nil
        case .macOS:
            return "maccatalyst"
        case .iOS:
            return "ios"
        }
    }

    func makeDestinationFilters(for filters: [SupportedDestination]?) -> [String]? {
        guard let filters = filters, !filters.isEmpty else { return nil }
        return filters.map { $0.string }
    }

    /// Make `Build Tools Plug-ins` as a dependency to the target
    /// - Parameter target: ProjectTarget
    /// - Returns: Elements for referencing other targets through content proxies.
    func makePackagePluginDependency(for target: ProjectTarget) -> [PBXTargetDependency] {
        target.buildToolPlugins.compactMap { buildToolPlugin in
            let packageReference = packageReferences[buildToolPlugin.package]
            if packageReference == nil, localPackageReferences[buildToolPlugin.package] == nil {
                return nil
            }

            let packageDependency = addObject(
                XCSwiftPackageProductDependency(productName: buildToolPlugin.plugin, package: packageReference, isPlugin: true)
            )
            let targetDependency = addObject(
                PBXTargetDependency(product: packageDependency)
            )

            return targetDependency
        }
    }

    func getInfoPlists(for target: Target) -> [Config: String] {
        var searchForDefaultInfoPlist: Bool = true
        var defaultInfoPlist: String?

        let values: [(Config, String)] = project.configs.compactMap { config in
            // First, if the plist path was defined by `INFOPLIST_FILE`, use that
            let buildSettings = project.getTargetBuildSettings(target: target, config: config)
            if let value = buildSettings["INFOPLIST_FILE"]?.stringValue {
                return (config, value)
            }

            // Otherwise check if the path was defined as part of the `info` spec
            if let value = target.info?.path {
                return (config, value)
            }

            // If we haven't yet looked for the default info plist, try doing so
            if searchForDefaultInfoPlist {
                searchForDefaultInfoPlist = false

                if let plistPath = getInfoPlist(target.sources) {
                    let basePath = projectDirectory ?? project.basePath.absolute()
                    let relative = (try? plistPath.relativePath(from: basePath)) ?? plistPath
                    defaultInfoPlist = relative.string
                }
            }

            // Return the default plist if there was one
            if let value = defaultInfoPlist {
                return (config, value)
            }
            return nil
        }

        return Dictionary(uniqueKeysWithValues: values)
    }

    func getInfoPlist(_ sources: [TargetSource]) -> Path? {
        sources
            .lazy
            .map { self.project.basePath + $0.path }
            .compactMap { (path) -> Path? in
                if path.isFile {
                    return path.lastComponent == "Info.plist" ? path : nil
                } else {
                    return path.first(where: { $0.lastComponent == "Info.plist" })?.absolute()
                }
            }
            .first
    }

    func getAllDependenciesPlusTransitiveNeedingEmbedding(target topLevelTarget: Target) -> [Dependency] {
        // this is used to resolve cyclical target dependencies
        var visitedTargets: Set<String> = []
        var dependencies: [String: Dependency] = [:]
        var queue: [Target] = [topLevelTarget]
        while !queue.isEmpty {
            let target = queue.removeFirst()
            if visitedTargets.contains(target.name) {
                continue
            }

            let isTopLevel = target == topLevelTarget

            for dependency in target.dependencies {
                // don't overwrite dependencies, to allow top level ones to rule
                if dependencies[dependency.uniqueID] != nil {
                    continue
                }

                // don't want a dependency if it's going to be embedded or statically linked in a non-top level target
                // in .target check we filter out targets that will embed all of their dependencies
                // For some more context about the `dependency.embed != true` lines, refer to https://github.com/yonaskolb/XcodeGen/pull/820
                switch dependency.type {
                case .sdk:
                    dependencies[dependency.uniqueID] = dependency
                case .framework, .carthage, .package:
                    if isTopLevel || dependency.embed != true {
                        dependencies[dependency.uniqueID] = dependency
                    }
                case .target:
                    let dependencyTargetReference = try! TargetReference(dependency.reference)

                    switch dependencyTargetReference.location {
                    case .local:
                        if isTopLevel || dependency.embed != true {
                            if let dependencyTarget = project.getTarget(dependency.reference) {
                                dependencies[dependency.uniqueID] = dependency
                                if !dependencyTarget.shouldEmbedDependencies {
                                    // traverse target's dependencies if it doesn't embed them itself
                                    queue.append(dependencyTarget)
                                }
                            } else if project.getAggregateTarget(dependency.reference) != nil {
                                // Aggregate targets should be included
                                dependencies[dependency.uniqueID] = dependency
                            }
                        }
                    case .project:
                        if isTopLevel || dependency.embed != true {
                            dependencies[dependency.uniqueID] = dependency
                        }
                    }
                case .bundle:
                    if isTopLevel {
                        dependencies[dependency.uniqueID] = dependency
                    }
                }
            }

            visitedTargets.update(with: target.name)
        }

        return dependencies.sorted(by: { $0.key < $1.key }).map { $0.value }
    }
}
