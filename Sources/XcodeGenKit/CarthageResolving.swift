import Foundation
import ProjectSpec

/// Dependency-inversion protocol for Carthage resolution.
/// Allows PBXProjGenerator to depend on an abstraction rather than the concrete resolver.
public protocol CarthageResolving {
    var buildPath: String { get }
    var executable: String { get }
    func buildPath(for platform: Platform, linkType: Dependency.CarthageLinkType) -> String
    func dependencies(for topLevelTarget: Target) -> [ResolvedCarthageDependency]
    func relatedDependencies(for dependency: Dependency, in platform: Platform) -> [Dependency]
}
