import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension PBXProjGenerator {

    func generateTargetAttributes() -> [PBXTarget: [String: ProjectAttribute]] {

        var targetAttributes: [PBXTarget: [String: ProjectAttribute]] = [:]

        let testTargets = pbxProj.nativeTargets.filter { $0.productType == .uiTestBundle || $0.productType == .unitTestBundle }
        for testTarget in testTargets {

            // look up TEST_TARGET_NAME build setting
            func testTargetName(_ target: PBXTarget) -> String? {
                guard let buildConfigurations = target.buildConfigurationList?.buildConfigurations else { return nil }

                return buildConfigurations
                    .compactMap { $0.buildSettings["TEST_TARGET_NAME"]?.stringValue }
                    .first
            }

            guard let name = testTargetName(testTarget) else { continue }
            guard let target = self.pbxProj.targets(named: name).first else { continue }

            targetAttributes[testTarget, default: [:]].merge(["TestTargetID": .targetReference(target)])
        }

        func generateTargetAttributes(_ target: ProjectTarget, pbxTarget: PBXTarget) {
            if !target.attributes.isEmpty {
                targetAttributes[pbxTarget, default: [:]].merge(target.attributes.mapValues { ProjectAttribute(any: $0) })
            }

            func getSingleBuildSetting(_ setting: String) -> String? {
                let settings = project.configs.compactMap {
                    project.getCombinedBuildSetting(setting, target: target, config: $0)?.stringValue
                }
                guard settings.count == project.configs.count,
                    let firstSetting = settings.first,
                    settings.filter({ $0 == firstSetting }).count == settings.count else {
                    return nil
                }
                return firstSetting
            }

            func setTargetAttribute(attribute: String, buildSetting: String) {
                if let setting = getSingleBuildSetting(buildSetting) {
                    targetAttributes[pbxTarget, default: [:]].merge([attribute: .string(setting)])
                }
            }

            setTargetAttribute(attribute: "ProvisioningStyle", buildSetting: "CODE_SIGN_STYLE")
            setTargetAttribute(attribute: "DevelopmentTeam", buildSetting: "DEVELOPMENT_TEAM")
        }

        for target in project.aggregateTargets {
            guard let pbxTarget = targetAggregateObjects[target.name] else {
                continue
            }
            generateTargetAttributes(target, pbxTarget: pbxTarget)
        }

        for target in project.targets {
            guard let pbxTarget = targetObjects[target.name] else {
                continue
            }
            generateTargetAttributes(target, pbxTarget: pbxTarget)
        }

        return targetAttributes
    }

    func sortGroups(group: PBXGroup) {
        // sort children
        let children = group.children
            .sorted { child1, child2 in
                let sortOrder1 = child1.getSortOrder(groupSortPosition: project.options.groupSortPosition)
                let sortOrder2 = child2.getSortOrder(groupSortPosition: project.options.groupSortPosition)

                if sortOrder1 != sortOrder2 {
                    return sortOrder1 < sortOrder2
                } else {
                    if (child1.name, child1.path) != (child2.name, child2.path) {
                        return PBXFileElement.sortByNamePath(child1, child2)
                    } else {
                        return child1.context ?? "" < child2.context ?? ""
                    }
                }
            }
        group.children = children.filter { $0 != group }

        // sort sub groups
        let childGroups = group.children.compactMap { $0 as? PBXGroup }
        childGroups.forEach(sortGroups)
    }

    public func setupGroupOrdering(group: PBXGroup) {
        let groupOrdering = project.options.groupOrdering.first { groupOrdering in
            let groupName = group.nameOrPath

            if groupName == groupOrdering.pattern {
                return true
            }

            if let regex = groupOrdering.regex {
                return regex.isMatch(to: groupName)
            }

            return false
        }

        if let order = groupOrdering?.order {
            let files = group.children.filter { !$0.isGroupOrFolder }
            var groups = group.children.filter {  $0.isGroupOrFolder }

            var filteredGroups = [PBXFileElement]()

            for groupName in order {
                guard let group = groups.first(where: { $0.nameOrPath == groupName }) else {
                    continue
                }

                filteredGroups.append(group)
                groups.removeAll { $0 == group }
            }

            filteredGroups += groups

            switch project.options.groupSortPosition {
            case .top:
                group.children = filteredGroups + files
            case .bottom:
                group.children = files + filteredGroups
            default:
                break
            }
        }

        // sort sub groups
        let childGroups = group.children.compactMap { $0 as? PBXGroup }
        childGroups.forEach(setupGroupOrdering)
    }
}

extension Target {

    var shouldEmbedDependencies: Bool {
        type.isApp || type.isTest
    }

    var shouldEmbedCarthageDependencies: Bool {
        (type.isApp && platform != .watchOS)
            || type == .watch2Extension
            || type.isTest
    }
}

extension Platform {
    /// - returns: `true` for platforms that the app store requires simulator slices to be stripped.
    public var requiresSimulatorStripping: Bool {
        switch self {
        case .auto, .iOS, .tvOS, .watchOS, .visionOS:
            return true
        case .macOS:
            return false
        }
    }
}

extension PBXFileElement {
    /// - returns: `true` if the element is a group, a folder reference (likely an SPM package), or a synced folder.
    var isGroupOrFolder: Bool {
        self is PBXGroup || self is PBXFileSystemSynchronizedRootGroup || (self as? PBXFileReference)?.lastKnownFileType == "folder"
    }

    public func getSortOrder(groupSortPosition: SpecOptions.GroupSortPosition) -> Int {
        if self is PBXGroup || self is PBXFileSystemSynchronizedRootGroup {
            switch groupSortPosition {
            case .top: return -1
            case .bottom: return 1
            case .none: return 0
            }
        } else {
            return 0
        }
    }
}

extension Dependency {
    var carthageLinkType: Dependency.CarthageLinkType? {
        switch type {
        case .carthage(_, let linkType):
            return linkType
        default:
            return nil
        }
    }
}
