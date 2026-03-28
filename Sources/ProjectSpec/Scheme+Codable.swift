import Foundation
import JSONUtilities
import PathKit
import XcodeProj

extension Scheme.ExecutionAction: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        script = try jsonDictionary.json(atKeyPath: "script")
        name = jsonDictionary.json(atKeyPath: "name") ?? "Run Script"
        settingsTarget = jsonDictionary.json(atKeyPath: "settingsTarget")
        shell = jsonDictionary.json(atKeyPath: "shell")
    }
}

extension Scheme.ExecutionAction: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "script": script,
            "name": name,
            "settingsTarget": settingsTarget,
            "shell": shell
        ]
    }
}

extension Scheme.SimulateLocation: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        allow = try jsonDictionary.json(atKeyPath: "allow")
        defaultLocation = jsonDictionary.json(atKeyPath: "defaultLocation")
    }
}

extension Scheme.SimulateLocation: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any] = [
            "allow": allow,
        ]

        if let defaultLocation = defaultLocation {
            dict["defaultLocation"] = defaultLocation
        }

        return dict
    }
}

extension Scheme.Management: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        shared = jsonDictionary.json(atKeyPath: "shared") ?? Scheme.Management.sharedDefault
        orderHint = jsonDictionary.json(atKeyPath: "orderHint")
        isShown = jsonDictionary.json(atKeyPath: "isShown")
    }
}

extension Scheme.Management: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [:]

        if shared != Scheme.Management.sharedDefault {
            dict["shared"] = shared
        }

        if let isShown = isShown {
            dict["isShown"] = isShown
        }

        if let orderHint = orderHint {
            dict["orderHint"] = orderHint
        }

        return dict
    }
}

extension Scheme.Run: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
        if let gpuFrameCaptureMode: String = jsonDictionary.json(atKeyPath: "enableGPUFrameCaptureMode") {
            enableGPUFrameCaptureMode = XCScheme.LaunchAction.GPUFrameCaptureMode.fromJSONValue(gpuFrameCaptureMode)
        } else {
            enableGPUFrameCaptureMode = XCScheme.LaunchAction.defaultGPUFrameCaptureMode
        }

        // support deprecated gpuValidationMode enum that was removed from XcodeProj
        if let gpuValidationMode: String = jsonDictionary.json(atKeyPath: "enableGPUValidationMode") {
            switch gpuValidationMode {
            case "enabled", "extended": enableGPUValidationMode = true
            case "disabled": enableGPUValidationMode = false
            default: enableGPUValidationMode = Scheme.Run.enableGPUValidationModeDefault
            }
        } else {
            enableGPUValidationMode = jsonDictionary.json(atKeyPath: "enableGPUValidationMode") ?? Scheme.Run.enableGPUValidationModeDefault
        }
        enableAddressSanitizer = jsonDictionary.json(atKeyPath: "enableAddressSanitizer") ?? Scheme.Run.enableAddressSanitizerDefault
        enableASanStackUseAfterReturn = jsonDictionary.json(atKeyPath: "enableASanStackUseAfterReturn") ?? Scheme.Run.enableASanStackUseAfterReturnDefault
        enableThreadSanitizer = jsonDictionary.json(atKeyPath: "enableThreadSanitizer") ?? Scheme.Run.enableThreadSanitizerDefault
        enableUBSanitizer = jsonDictionary.json(atKeyPath: "enableUBSanitizer") ?? Scheme.Run.enableUBSanitizerDefault
        disableMainThreadChecker = jsonDictionary.json(atKeyPath: "disableMainThreadChecker") ?? Scheme.Run.disableMainThreadCheckerDefault
        stopOnEveryMainThreadCheckerIssue = jsonDictionary.json(atKeyPath: "stopOnEveryMainThreadCheckerIssue") ?? Scheme.Run.stopOnEveryMainThreadCheckerIssueDefault
        disableThreadPerformanceChecker = jsonDictionary.json(atKeyPath: "disableThreadPerformanceChecker") ?? Scheme.Run.disableThreadPerformanceCheckerDefault
        language = jsonDictionary.json(atKeyPath: "language")
        region = jsonDictionary.json(atKeyPath: "region")
        debugEnabled = jsonDictionary.json(atKeyPath: "debugEnabled") ?? Scheme.Run.debugEnabledDefault
        simulateLocation = jsonDictionary.json(atKeyPath: "simulateLocation")
        storeKitConfiguration = jsonDictionary.json(atKeyPath: "storeKitConfiguration")
        executable = jsonDictionary.json(atKeyPath: "executable")

        // launchAutomaticallySubstyle is defined as a String in XcodeProj but its value is often
        // an integer. Parse both to be nice.
        if let int: Int = jsonDictionary.json(atKeyPath: "launchAutomaticallySubstyle") {
            launchAutomaticallySubstyle = String(int)
        } else if let string: String = jsonDictionary.json(atKeyPath: "launchAutomaticallySubstyle") {
            launchAutomaticallySubstyle = string
        }

        if let askLaunch: Bool = jsonDictionary.json(atKeyPath: "askForAppToLaunch") {
            askForAppToLaunch = askLaunch
        }
        customLLDBInit = jsonDictionary.json(atKeyPath: "customLLDBInit")
        macroExpansion = jsonDictionary.json(atKeyPath: "macroExpansion")
        customWorkingDirectory = jsonDictionary.json(atKeyPath: "customWorkingDirectory")
    }
}

extension Scheme.Run: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "commandLineArguments": commandLineArguments,
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "environmentVariables": environmentVariables.map { $0.toJSONValue() },
            "config": config,
            "language": language,
            "region": region,
            "askForAppToLaunch": askForAppToLaunch,
            "launchAutomaticallySubstyle": launchAutomaticallySubstyle,
            "executable": executable,
            "macroExpansion": macroExpansion
        ]

        if enableGPUFrameCaptureMode != XCScheme.LaunchAction.defaultGPUFrameCaptureMode {
            dict["enableGPUFrameCaptureMode"] = enableGPUFrameCaptureMode.toJSONValue()
        }

        if enableGPUValidationMode != Scheme.Run.enableGPUValidationModeDefault {
            dict["enableGPUValidationMode"] = enableGPUValidationMode
        }

        if enableAddressSanitizer != Scheme.Run.enableAddressSanitizerDefault {
            dict["enableAddressSanitizer"] = enableAddressSanitizer
        }

        if enableASanStackUseAfterReturn != Scheme.Run.enableASanStackUseAfterReturnDefault {
            dict["enableASanStackUseAfterReturn"] = enableASanStackUseAfterReturn
        }

        if enableThreadSanitizer != Scheme.Run.enableThreadSanitizerDefault {
            dict["enableThreadSanitizer"] = enableThreadSanitizer
        }

        if enableUBSanitizer != Scheme.Run.enableUBSanitizerDefault {
            dict["enableUBSanitizer"] = enableUBSanitizer
        }

        if disableMainThreadChecker != Scheme.Run.disableMainThreadCheckerDefault {
            dict["disableMainThreadChecker"] = disableMainThreadChecker
        }

        if stopOnEveryMainThreadCheckerIssue != Scheme.Run.stopOnEveryMainThreadCheckerIssueDefault {
            dict["stopOnEveryMainThreadCheckerIssue"] = stopOnEveryMainThreadCheckerIssue
        }

        if disableThreadPerformanceChecker != Scheme.Run.disableThreadPerformanceCheckerDefault {
            dict["disableThreadPerformanceChecker"] = disableThreadPerformanceChecker
        }

        if debugEnabled != Scheme.Run.debugEnabledDefault {
            dict["debugEnabled"] = debugEnabled
        }

        if let simulateLocation = simulateLocation {
            dict["simulateLocation"] = simulateLocation.toJSONValue()
        }
        if let storeKitConfiguration = storeKitConfiguration {
            dict["storeKitConfiguration"] = storeKitConfiguration
        }
        if let customLLDBInit = customLLDBInit {
            dict["customLLDBInit"] = customLLDBInit
        }
        if let customWorkingDirectory = customWorkingDirectory {
            dict["customWorkingDirectory"] = customWorkingDirectory
        }
        return dict
    }
}

extension Scheme.Test: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .object("testPlans", TestPlan.pathProperties),
        ]
    }
}

extension Scheme.Test: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? Scheme.Test.gatherCoverageDataDefault

        if let coverages = jsonDictionary["coverageTargets"] as? [Any] {
            coverageTargets = try coverages.compactMap { target in
                if let string = target as? String {
                    return try TestableTargetReference(string)
                } else if let dictionary = target as? JSONDictionary,
                          let target: TestableTargetReference = try? .init(jsonDictionary: dictionary) {
                    return target
                } else {
                    return nil
                }
            }
        } else {
            coverageTargets = []
        }

        enableAddressSanitizer = jsonDictionary.json(atKeyPath: "enableAddressSanitizer") ?? Scheme.Test.enableAddressSanitizerDefault
        enableASanStackUseAfterReturn = jsonDictionary.json(atKeyPath: "enableASanStackUseAfterReturn") ?? Scheme.Test.enableASanStackUseAfterReturnDefault
        enableThreadSanitizer = jsonDictionary.json(atKeyPath: "enableThreadSanitizer") ?? Scheme.Test.enableThreadSanitizerDefault
        enableUBSanitizer = jsonDictionary.json(atKeyPath: "enableUBSanitizer") ?? Scheme.Test.enableUBSanitizerDefault
        disableMainThreadChecker = jsonDictionary.json(atKeyPath: "disableMainThreadChecker") ?? Scheme.Test.disableMainThreadCheckerDefault
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        if let targets = jsonDictionary["targets"] as? [Any] {
            self.targets = try targets.compactMap { target in
                if let string = target as? String {
                    return try TestTarget(targetReference: TestableTargetReference(string))
                } else if let dictionary = target as? JSONDictionary {
                    return try TestTarget(jsonDictionary: dictionary)
                } else {
                    return nil
                }
            }
        } else {
            targets = []
        }
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
        testPlans = try (jsonDictionary.json(atKeyPath: "testPlans") ?? []).map { try TestPlan(jsonDictionary: $0) }
        language = jsonDictionary.json(atKeyPath: "language")
        region = jsonDictionary.json(atKeyPath: "region")
        debugEnabled = jsonDictionary.json(atKeyPath: "debugEnabled") ?? Scheme.Test.debugEnabledDefault
        customLLDBInit = jsonDictionary.json(atKeyPath: "customLLDBInit")
        captureScreenshotsAutomatically = jsonDictionary.json(atKeyPath: "captureScreenshotsAutomatically") ?? Scheme.Test.captureScreenshotsAutomaticallyDefault
        deleteScreenshotsWhenEachTestSucceeds = jsonDictionary.json(atKeyPath: "deleteScreenshotsWhenEachTestSucceeds") ?? Scheme.Test.deleteScreenshotsWhenEachTestSucceedsDefault
        macroExpansion = jsonDictionary.json(atKeyPath: "macroExpansion")
        preferredScreenCaptureFormat = jsonDictionary.json(atKeyPath: "preferredScreenCaptureFormat") ?? Scheme.Test.preferredScreenCaptureFormatDefault
    }
}

extension Scheme.Test: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "commandLineArguments": commandLineArguments,
            "targets": targets.map { $0.toJSONValue() },
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "environmentVariables": environmentVariables.map { $0.toJSONValue() },
            "testPlans": testPlans.map { $0.toJSONValue() },
            "config": config,
            "language": language,
            "region": region,
            "coverageTargets": coverageTargets.map { $0.reference },
            "macroExpansion": macroExpansion
        ]

        if gatherCoverageData != Scheme.Test.gatherCoverageDataDefault {
            dict["gatherCoverageData"] = gatherCoverageData
        }

        if enableAddressSanitizer != Scheme.Test.enableAddressSanitizerDefault {
            dict["enableAddressSanitizer"] = enableAddressSanitizer
        }

        if enableASanStackUseAfterReturn != Scheme.Test.enableASanStackUseAfterReturnDefault {
            dict["enableASanStackUseAfterReturn"] = enableASanStackUseAfterReturn
        }

        if enableThreadSanitizer != Scheme.Test.enableThreadSanitizerDefault {
            dict["enableThreadSanitizer"] = enableThreadSanitizer
        }

        if enableUBSanitizer != Scheme.Test.enableUBSanitizerDefault {
            dict["enableUBSanitizer"] = enableUBSanitizer
        }

        if disableMainThreadChecker != Scheme.Test.disableMainThreadCheckerDefault {
            dict["disableMainThreadChecker"] = disableMainThreadChecker
        }

        if debugEnabled != Scheme.Run.debugEnabledDefault {
            dict["debugEnabled"] = debugEnabled
        }

        if let customLLDBInit = customLLDBInit {
            dict["customLLDBInit"] = customLLDBInit
        }

        if captureScreenshotsAutomatically != Scheme.Test.captureScreenshotsAutomaticallyDefault {
            dict["captureScreenshotsAutomatically"] = captureScreenshotsAutomatically
        }

        if deleteScreenshotsWhenEachTestSucceeds != Scheme.Test.deleteScreenshotsWhenEachTestSucceedsDefault {
            dict["deleteScreenshotsWhenEachTestSucceeds"] = deleteScreenshotsWhenEachTestSucceeds
        }

        if preferredScreenCaptureFormat != Scheme.Test.preferredScreenCaptureFormatDefault {
            dict["preferredScreenCaptureFormat"] = preferredScreenCaptureFormat.toJSONValue()
        }

        return dict
    }
}

extension Scheme.Test.TestTarget: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let name: String = jsonDictionary.json(atKeyPath: "name")  {
            targetReference = try TestableTargetReference(name)
        } else if let local: String = jsonDictionary.json(atKeyPath: "local") {
            self.targetReference = TestableTargetReference.local(local)
        } else if let project: String = jsonDictionary.json(atKeyPath: "project") {
            self.targetReference = TestableTargetReference.project(project)
        } else if let package: String = jsonDictionary.json(atKeyPath: "package") {
            self.targetReference = TestableTargetReference.package(package)
        } else {
            self.targetReference = try jsonDictionary.json(atKeyPath: "target")
        }
        randomExecutionOrder = jsonDictionary.json(atKeyPath: "randomExecutionOrder") ?? Scheme.Test.TestTarget.randomExecutionOrderDefault
        parallelizable = jsonDictionary.json(atKeyPath: "parallelizable") ?? Scheme.Test.TestTarget.parallelizableDefault
        location = jsonDictionary.json(atKeyPath: "location") ?? nil
        skipped = jsonDictionary.json(atKeyPath: "skipped") ?? false
        skippedTests = jsonDictionary.json(atKeyPath: "skippedTests") ?? []
        selectedTests = jsonDictionary.json(atKeyPath: "selectedTests") ?? []
    }
}

extension Scheme.Test.TestTarget: JSONEncodable {
    public func toJSONValue() -> Any {
        if randomExecutionOrder == Scheme.Test.TestTarget.randomExecutionOrderDefault,
            parallelizable == Scheme.Test.TestTarget.parallelizableDefault {
            return targetReference.reference
        }

        var dict: JSONDictionary = [
            "name": targetReference.reference,
        ]

        if randomExecutionOrder != Scheme.Test.TestTarget.randomExecutionOrderDefault {
            dict["randomExecutionOrder"] = randomExecutionOrder
        }
        if parallelizable != Scheme.Test.TestTarget.parallelizableDefault {
            dict["parallelizable"] = parallelizable
        }
        if let location = location {
            dict["location"] = location
        }
        if skipped {
            dict["skipped"] = skipped
        }

        return dict
    }
}

extension Scheme.Profile: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
        if let askLaunch: Bool = jsonDictionary.json(atKeyPath: "askForAppToLaunch") {
            askForAppToLaunch = askLaunch
        }
    }
}

extension Scheme.Profile: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "commandLineArguments": commandLineArguments,
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "environmentVariables": environmentVariables.map { $0.toJSONValue() },
            "config": config,
            "askForAppToLaunch": askForAppToLaunch,
        ] as [String: Any?]
    }
}

extension Scheme.Analyze: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
    }
}

extension Scheme.Analyze: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "config": config,
        ]
    }
}

extension Scheme.Archive: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        customArchiveName = jsonDictionary.json(atKeyPath: "customArchiveName")
        revealArchiveInOrganizer = jsonDictionary.json(atKeyPath: "revealArchiveInOrganizer") ?? Scheme.Archive.revealArchiveInOrganizerDefault
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
    }
}

extension Scheme.Archive: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "config": config,
            "customArchiveName": customArchiveName,
        ]

        if revealArchiveInOrganizer != Scheme.Archive.revealArchiveInOrganizerDefault {
            dict["revealArchiveInOrganizer"] = revealArchiveInOrganizer
        }

        return dict
    }
}

extension Scheme: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        build = try jsonDictionary.json(atKeyPath: "build")
        run = jsonDictionary.json(atKeyPath: "run")
        test = jsonDictionary.json(atKeyPath: "test")
        analyze = jsonDictionary.json(atKeyPath: "analyze")
        profile = jsonDictionary.json(atKeyPath: "profile")
        archive = jsonDictionary.json(atKeyPath: "archive")
        management = jsonDictionary.json(atKeyPath: "management")
    }
}

extension Scheme: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "build": build.toJSONValue(),
            "run": run?.toJSONValue(),
            "test": test?.toJSONValue(),
            "analyze": analyze?.toJSONValue(),
            "profile": profile?.toJSONValue(),
            "archive": archive?.toJSONValue(),
            "management": management?.toJSONValue(),
        ] as [String: Any?]
    }
}

extension Scheme.Build: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let targetDictionary: JSONDictionary = try jsonDictionary.json(atKeyPath: "targets")
        var targets: [Scheme.BuildTarget] = []
        for (targetRepr, possibleBuildTypes) in targetDictionary {
            let buildTypes: [BuildType]
            if let string = possibleBuildTypes as? String {
                switch string {
                case "all": buildTypes = BuildType.all
                case "none": buildTypes = []
                case "testing": buildTypes = [.testing, .analyzing]
                case "indexing": buildTypes = [.testing, .analyzing, .archiving]
                default: buildTypes = BuildType.all
                }
            } else if let enabledDictionary = possibleBuildTypes as? [String: Bool] {
                buildTypes = enabledDictionary.filter { $0.value }.compactMap { BuildType.from(jsonValue: $0.key) }
            } else if let array = possibleBuildTypes as? [String] {
                buildTypes = array.compactMap(BuildType.from)
            } else {
                buildTypes = BuildType.all
            }
            let target = try TestableTargetReference(targetRepr)
            targets.append(Scheme.BuildTarget(target: target, buildTypes: buildTypes))
        }
        self.targets = targets.sorted { $0.target.name < $1.target.name }
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
        parallelizeBuild = jsonDictionary.json(atKeyPath: "parallelizeBuild") ?? Scheme.Build.parallelizeBuildDefault
        buildImplicitDependencies = jsonDictionary.json(atKeyPath: "buildImplicitDependencies") ?? Scheme.Build.buildImplicitDependenciesDefault
        runPostActionsOnFailure = jsonDictionary.json(atKeyPath: "runPostActionsOnFailure") ?? Scheme.Build.runPostActionsOnFailureDefault
    }
}

extension Scheme.Build: JSONEncodable {
    public func toJSONValue() -> Any {
        let targetPairs = targets.map { ($0.target.reference, $0.buildTypes.map { $0.toJSONValue() }) }

        var dict: JSONDictionary = [
            "targets": Dictionary(uniqueKeysWithValues: targetPairs),
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
        ]

        if parallelizeBuild != Scheme.Build.parallelizeBuildDefault {
            dict["parallelizeBuild"] = parallelizeBuild
        }
        if buildImplicitDependencies != Scheme.Build.buildImplicitDependenciesDefault {
            dict["buildImplicitDependencies"] = buildImplicitDependencies
        }
        if runPostActionsOnFailure != Scheme.Build.runPostActionsOnFailureDefault {
            dict["runPostActionsOnFailure"] = runPostActionsOnFailure
        }

        return dict
    }
}

extension BuildType: JSONUtilities.JSONPrimitiveConvertible {

    public typealias JSONType = String

    public static func from(jsonValue: String) -> BuildType? {
        switch jsonValue {
        case "test", "testing": return .testing
        case "profile", "profiling": return .profiling
        case "run", "running": return .running
        case "archive", "archiving": return .archiving
        case "analyze", "analyzing": return .analyzing
        default: return nil
        }
    }

    public static var all: [BuildType] {
        [.running, .testing, .profiling, .analyzing, .archiving]
    }
}

extension BuildType: JSONEncodable {
    public func toJSONValue() -> Any {
        switch self {
        case .testing: return "testing"
        case .profiling: return "profiling"
        case .running: return "running"
        case .archiving: return "archiving"
        case .analyzing: return "analyzing"
        }
    }
}

extension XCScheme.EnvironmentVariable: JSONUtilities.JSONObjectConvertible {
    public static let enabledDefault = true

    private static func parseValue(_ value: Any) -> String {
        if let bool = value as? Bool {
            return bool ? "YES" : "NO"
        } else {
            return String(describing: value)
        }
    }

    public init(jsonDictionary: JSONDictionary) throws {

        let value: String
        if let jsonValue = jsonDictionary["value"] {
            value = XCScheme.EnvironmentVariable.parseValue(jsonValue)
        } else {
            // will throw error
            value = try jsonDictionary.json(atKeyPath: "value")
        }
        let variable: String = try jsonDictionary.json(atKeyPath: "variable")
        let enabled: Bool = jsonDictionary.json(atKeyPath: "isEnabled") ?? XCScheme.EnvironmentVariable.enabledDefault
        self.init(variable: variable, value: value, enabled: enabled)
    }

    static func parseAll(jsonDictionary: JSONDictionary) throws -> [XCScheme.EnvironmentVariable] {
        if let variablesDictionary: [String: Any] = jsonDictionary.json(atKeyPath: "environmentVariables") {
            return variablesDictionary.mapValues(parseValue)
                .map { XCScheme.EnvironmentVariable(variable: $0.key, value: $0.value, enabled: true) }
                .sorted { $0.variable < $1.variable }
        } else if let variablesArray: [JSONDictionary] = jsonDictionary.json(atKeyPath: "environmentVariables") {
            return try variablesArray.map(XCScheme.EnvironmentVariable.init)
        } else {
            return []
        }
    }
}

extension XCScheme.EnvironmentVariable: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any] = [
            "variable": variable,
            "value": value,
        ]

        if enabled != XCScheme.EnvironmentVariable.enabledDefault {
            dict["isEnabled"] = enabled
        }

        return dict
    }
}

extension XCScheme.LaunchAction.GPUFrameCaptureMode: JSONEncodable {
    public func toJSONValue() -> Any {
        switch self {
        case .autoEnabled:
            return "autoEnabled"
        case .metal:
            return "metal"
        case .openGL:
            return "openGL"
        case .disabled:
            return "disabled"
        }
    }

    static func fromJSONValue(_ string: String) -> XCScheme.LaunchAction.GPUFrameCaptureMode {
        switch string {
        case "autoEnabled":
            return .autoEnabled
        case "metal":
            return .metal
        case "openGL":
            return .openGL
        case "disabled":
            return .disabled
        default:
            fatalError("Invalid enableGPUFrameCaptureMode value. Valid values are: autoEnabled, metal, openGL, disabled")
        }
    }
}

extension XCScheme.TestAction.ScreenCaptureFormat: JSONEncodable {
    public func toJSONValue() -> Any {
        rawValue
    }
}
