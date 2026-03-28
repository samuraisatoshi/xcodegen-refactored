import Foundation

/// Applies semantic patch operations to a raw project spec dictionary.
/// Used by PatchCommand; extracted here for testability.
public struct XcodeSpecPatcher {

    public init() {}

    public func addSource(to dict: [String: Any], target: String, path: String) throws -> [String: Any] {
        var dict = dict
        guard var targets = dict["targets"] as? [String: Any],
              var targetDict = targets[target] as? [String: Any] else {
            throw PatcherError.cannotMutate(target)
        }

        var sources = targetDict["sources"] as? [Any] ?? []
        let existing = sources.compactMap { ($0 as? String) ?? ($0 as? [String: Any])?["path"] as? String }
        guard !existing.contains(path) else { return dict }

        sources.append(path)
        targetDict["sources"] = sources
        targets[target] = targetDict
        dict["targets"] = targets
        return dict
    }

    public func addSDKDependency(to dict: [String: Any], target: String, sdk: String) throws -> [String: Any] {
        var dict = dict
        guard var targets = dict["targets"] as? [String: Any],
              var targetDict = targets[target] as? [String: Any] else {
            throw PatcherError.cannotMutate(target)
        }

        var deps = targetDict["dependencies"] as? [[String: Any]] ?? []
        let existing = deps.compactMap { $0["sdk"] as? String }
        guard !existing.contains(sdk) else { return dict }

        deps.append(["sdk": sdk])
        targetDict["dependencies"] = deps
        targets[target] = targetDict
        dict["targets"] = targets
        return dict
    }

    public func addPackageDependency(to dict: [String: Any], target: String, package: String) throws -> [String: Any] {
        var dict = dict
        guard var targets = dict["targets"] as? [String: Any],
              var targetDict = targets[target] as? [String: Any] else {
            throw PatcherError.cannotMutate(target)
        }

        var deps = targetDict["dependencies"] as? [[String: Any]] ?? []
        let existing = deps.compactMap { $0["package"] as? String }
        guard !existing.contains(package) else { return dict }

        deps.append(["package": package])
        targetDict["dependencies"] = deps
        targets[target] = targetDict
        dict["targets"] = targets
        return dict
    }

    public func setSetting(in dict: [String: Any], target: String, key: String, value: String, config: String?) throws -> [String: Any] {
        var dict = dict
        guard var targets = dict["targets"] as? [String: Any],
              var targetDict = targets[target] as? [String: Any] else {
            throw PatcherError.cannotMutate(target)
        }

        var settings = targetDict["settings"] as? [String: Any] ?? [:]

        if let config = config {
            var configs = settings["configs"] as? [String: Any] ?? [:]
            var configSettings = configs[config] as? [String: Any] ?? [:]
            configSettings[key] = value
            configs[config] = configSettings
            settings["configs"] = configs
        } else {
            var base = settings["base"] as? [String: Any] ?? [:]
            base[key] = value
            settings["base"] = base
        }

        targetDict["settings"] = settings
        targets[target] = targetDict
        dict["targets"] = targets
        return dict
    }
}

// MARK: - Errors

public enum PatcherError: Error, CustomStringConvertible {
    case cannotMutate(String)

    public var description: String {
        switch self {
        case let .cannotMutate(t):
            return "cannot locate target '\(t)' in YAML structure"
        }
    }
}
