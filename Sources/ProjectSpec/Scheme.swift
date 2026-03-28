import Foundation
import JSONUtilities
import PathKit
import XcodeProj

public typealias BuildType = XCScheme.BuildAction.Entry.BuildFor

public struct Scheme: Equatable {

    public var name: String
    public var build: Build
    public var run: Run?
    public var archive: Archive?
    public var analyze: Analyze?
    public var test: Test?
    public var profile: Profile?
    public var management: Management?

    public init(
        name: String,
        build: Build,
        run: Run? = nil,
        test: Test? = nil,
        profile: Profile? = nil,
        analyze: Analyze? = nil,
        archive: Archive? = nil,
        management: Management? = nil
    ) {
        self.name = name
        self.build = build
        self.run = run
        self.test = test
        self.profile = profile
        self.analyze = analyze
        self.archive = archive
        self.management = management
    }

    public struct Management: Equatable {
        public static let sharedDefault = true

        public var shared: Bool
        public var orderHint: Int?
        public var isShown: Bool?

        public init?(
            shared: Bool = Scheme.Management.sharedDefault,
            orderHint: Int? = nil,
            isShown: Bool? = nil
        ) {
            if shared == Scheme.Management.sharedDefault, orderHint == nil, isShown == nil {
                return nil
            }

            self.shared = shared
            self.orderHint = orderHint
            self.isShown = isShown
        }
    }

    public struct SimulateLocation: Equatable {
        public enum ReferenceType: String {
            case predefined = "1"
            case gpx = "0"
        }

        public var allow: Bool
        public var defaultLocation: String?

        public var referenceType: ReferenceType? {
            guard let defaultLocation = self.defaultLocation else {
                return nil
            }

            if defaultLocation.contains(".gpx") {
                return .gpx
            }
            return .predefined
        }

        public init(allow: Bool, defaultLocation: String) {
            self.allow = allow
            self.defaultLocation = defaultLocation
        }
    }

    public struct ExecutionAction: Equatable {
        public var script: String
        public var name: String
        public var settingsTarget: String?
        public var shell: String?
        public init(name: String, script: String, shell: String? = nil, settingsTarget: String? = nil) {
            self.script = script
            self.name = name
            self.settingsTarget = settingsTarget
            self.shell = shell
        }
    }

    public struct Build: Equatable {
        public static let parallelizeBuildDefault = true
        public static let buildImplicitDependenciesDefault = true
        public static let runPostActionsOnFailureDefault = false

        public var targets: [BuildTarget]
        public var parallelizeBuild: Bool
        public var buildImplicitDependencies: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var runPostActionsOnFailure: Bool

        public init(
            targets: [BuildTarget],
            parallelizeBuild: Bool = parallelizeBuildDefault,
            buildImplicitDependencies: Bool = buildImplicitDependenciesDefault,
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            runPostActionsOnFailure: Bool = false
        ) {
            self.targets = targets
            self.parallelizeBuild = parallelizeBuild
            self.buildImplicitDependencies = buildImplicitDependencies
            self.preActions = preActions
            self.postActions = postActions
            self.runPostActionsOnFailure = runPostActionsOnFailure
        }
    }

    public struct Run: BuildAction {
        public static let enableAddressSanitizerDefault = false
        public static let enableASanStackUseAfterReturnDefault = false
        public static let enableThreadSanitizerDefault = false
        public static let enableUBSanitizerDefault = false
        public static let disableMainThreadCheckerDefault = false
        public static let stopOnEveryMainThreadCheckerIssueDefault = false
        public static let disableThreadPerformanceCheckerDefault = false
        public static let debugEnabledDefault = true
        public static let enableGPUValidationModeDefault = true

        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public var enableGPUFrameCaptureMode: XCScheme.LaunchAction.GPUFrameCaptureMode
        public var enableGPUValidationMode: Bool
        public var enableAddressSanitizer: Bool
        public var enableASanStackUseAfterReturn: Bool
        public var enableThreadSanitizer: Bool
        public var enableUBSanitizer: Bool
        public var disableMainThreadChecker: Bool
        public var stopOnEveryMainThreadCheckerIssue: Bool
        public var disableThreadPerformanceChecker: Bool
        public var language: String?
        public var region: String?
        public var askForAppToLaunch: Bool?
        public var launchAutomaticallySubstyle: String?
        public var debugEnabled: Bool
        public var simulateLocation: SimulateLocation?
        public var executable: String?
        public var storeKitConfiguration: String?
        public var customLLDBInit: String?
        public var macroExpansion: String?
        public var customWorkingDirectory: String?

        public init(
            config: String? = nil,
            executable: String? = nil,
            commandLineArguments: [String: Bool] = [:],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = [],
            enableGPUFrameCaptureMode: XCScheme.LaunchAction.GPUFrameCaptureMode = XCScheme.LaunchAction.defaultGPUFrameCaptureMode,
            enableGPUValidationMode: Bool = enableGPUValidationModeDefault,
            enableAddressSanitizer: Bool = enableAddressSanitizerDefault,
            enableASanStackUseAfterReturn: Bool = enableASanStackUseAfterReturnDefault,
            enableThreadSanitizer: Bool = enableThreadSanitizerDefault,
            enableUBSanitizer: Bool = enableUBSanitizerDefault,
            disableMainThreadChecker: Bool = disableMainThreadCheckerDefault,
            stopOnEveryMainThreadCheckerIssue: Bool = stopOnEveryMainThreadCheckerIssueDefault,
            disableThreadPerformanceChecker: Bool = disableThreadPerformanceCheckerDefault,
            language: String? = nil,
            region: String? = nil,
            askForAppToLaunch: Bool? = nil,
            launchAutomaticallySubstyle: String? = nil,
            debugEnabled: Bool = debugEnabledDefault,
            simulateLocation: SimulateLocation? = nil,
            storeKitConfiguration: String? = nil,
            customLLDBInit: String? = nil,
            macroExpansion: String? = nil,
            customWorkingDirectory: String? = nil
        ) {
            self.config = config
            self.commandLineArguments = commandLineArguments
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
            self.enableAddressSanitizer = enableAddressSanitizer
            self.enableASanStackUseAfterReturn = enableASanStackUseAfterReturn
            self.enableThreadSanitizer = enableThreadSanitizer
            self.enableUBSanitizer = enableUBSanitizer
            self.disableMainThreadChecker = disableMainThreadChecker
            self.enableGPUFrameCaptureMode = enableGPUFrameCaptureMode
            self.enableGPUValidationMode = enableGPUValidationMode
            self.stopOnEveryMainThreadCheckerIssue = stopOnEveryMainThreadCheckerIssue
            self.disableThreadPerformanceChecker = disableThreadPerformanceChecker
            self.language = language
            self.region = region
            self.askForAppToLaunch = askForAppToLaunch
            self.launchAutomaticallySubstyle = launchAutomaticallySubstyle
            self.debugEnabled = debugEnabled
            self.simulateLocation = simulateLocation
            self.storeKitConfiguration = storeKitConfiguration
            self.customLLDBInit = customLLDBInit
            self.macroExpansion = macroExpansion
            self.customWorkingDirectory = customWorkingDirectory
        }
    }

    public struct Test: BuildAction {
        public static let gatherCoverageDataDefault = false
        public static let enableAddressSanitizerDefault = false
        public static let enableASanStackUseAfterReturnDefault = false
        public static let enableThreadSanitizerDefault = false
        public static let enableUBSanitizerDefault = false
        public static let disableMainThreadCheckerDefault = false
        public static let debugEnabledDefault = true
        public static let captureScreenshotsAutomaticallyDefault = true
        public static let deleteScreenshotsWhenEachTestSucceedsDefault = true
        public static let preferredScreenCaptureFormatDefault = XCScheme.TestAction.ScreenCaptureFormat.screenRecording

        public var config: String?
        public var gatherCoverageData: Bool
        public var coverageTargets: [TestableTargetReference]
        public var enableAddressSanitizer: Bool
        public var enableASanStackUseAfterReturn: Bool
        public var enableThreadSanitizer: Bool
        public var enableUBSanitizer: Bool
        public var disableMainThreadChecker: Bool
        public var commandLineArguments: [String: Bool]
        public var targets: [TestTarget]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public var language: String?
        public var region: String?
        public var debugEnabled: Bool
        public var customLLDBInit: String?
        public var captureScreenshotsAutomatically: Bool
        public var deleteScreenshotsWhenEachTestSucceeds: Bool
        public var testPlans: [TestPlan]
        public var macroExpansion: String?
        public var preferredScreenCaptureFormat: XCScheme.TestAction.ScreenCaptureFormat

        public struct TestTarget: Equatable, ExpressibleByStringLiteral {
            
            public static let randomExecutionOrderDefault = false
            public static let parallelizableDefault = false

            public var name: String { targetReference.name }
            public let targetReference: TestableTargetReference
            public var randomExecutionOrder: Bool
            public var parallelizable: Bool
            public var location: String?
            public var skipped: Bool
            public var skippedTests: [String]
            public var selectedTests: [String]

            public init(
                targetReference: TestableTargetReference,
                randomExecutionOrder: Bool = randomExecutionOrderDefault,
                parallelizable: Bool = parallelizableDefault,
                location: String? = nil,
                skipped: Bool = false,
                skippedTests: [String] = [],
                selectedTests: [String] = []
            ) {
                self.targetReference = targetReference
                self.randomExecutionOrder = randomExecutionOrder
                self.parallelizable = parallelizable
                self.location = location
                self.skipped = skipped
                self.skippedTests = skippedTests
                self.selectedTests = selectedTests
            }

            public init(stringLiteral value: String) {
                do {
                    targetReference = try TestableTargetReference(value)
                    randomExecutionOrder = false
                    parallelizable = false
                    location = nil
                    skipped = false
                    skippedTests = []
                    selectedTests = []
                } catch {
                    fatalError(SpecParsingError.invalidTargetReference(value).description)
                }
            }
        }

        public init(
            config: String? = nil,
            gatherCoverageData: Bool = gatherCoverageDataDefault,
            coverageTargets: [TestableTargetReference] = [],
            enableAddressSanitizer: Bool = enableAddressSanitizerDefault,
            enableASanStackUseAfterReturn: Bool = enableASanStackUseAfterReturnDefault,
            enableThreadSanitizer: Bool = enableThreadSanitizerDefault,
            enableUBSanitizer: Bool = enableUBSanitizerDefault,
            disableMainThreadChecker: Bool = disableMainThreadCheckerDefault,
            randomExecutionOrder: Bool = false,
            parallelizable: Bool = false,
            commandLineArguments: [String: Bool] = [:],
            targets: [TestTarget] = [],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = [],
            testPlans: [TestPlan] = [],
            language: String? = nil,
            region: String? = nil,
            debugEnabled: Bool = debugEnabledDefault,
            customLLDBInit: String? = nil,
            captureScreenshotsAutomatically: Bool = captureScreenshotsAutomaticallyDefault,
            deleteScreenshotsWhenEachTestSucceeds: Bool = deleteScreenshotsWhenEachTestSucceedsDefault,
            macroExpansion: String? = nil,
            preferredScreenCaptureFormat: XCScheme.TestAction.ScreenCaptureFormat = preferredScreenCaptureFormatDefault
        ) {
            self.config = config
            self.gatherCoverageData = gatherCoverageData
            self.coverageTargets = coverageTargets
            self.enableAddressSanitizer = enableAddressSanitizer
            self.enableASanStackUseAfterReturn = enableASanStackUseAfterReturn
            self.enableThreadSanitizer = enableThreadSanitizer
            self.enableUBSanitizer = enableUBSanitizer
            self.disableMainThreadChecker = disableMainThreadChecker
            self.commandLineArguments = commandLineArguments
            self.targets = targets
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
            self.testPlans = testPlans
            self.language = language
            self.region = region
            self.debugEnabled = debugEnabled
            self.customLLDBInit = customLLDBInit
            self.captureScreenshotsAutomatically = captureScreenshotsAutomatically
            self.deleteScreenshotsWhenEachTestSucceeds = deleteScreenshotsWhenEachTestSucceeds
            self.macroExpansion = macroExpansion
            self.preferredScreenCaptureFormat = preferredScreenCaptureFormat
        }

        public var shouldUseLaunchSchemeArgsEnv: Bool {
            commandLineArguments.isEmpty && environmentVariables.isEmpty
        }
    }

    public struct Analyze: BuildAction {
        public var config: String?
        public init(config: String) {
            self.config = config
        }
    }

    public struct Profile: BuildAction {
        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public var askForAppToLaunch: Bool?

        public init(
            config: String? = nil,
            commandLineArguments: [String: Bool] = [:],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = [],
            askForAppToLaunch: Bool? = nil
        ) {
            self.config = config
            self.commandLineArguments = commandLineArguments
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
            self.askForAppToLaunch = askForAppToLaunch
        }

        public var shouldUseLaunchSchemeArgsEnv: Bool {
            commandLineArguments.isEmpty && environmentVariables.isEmpty
        }
    }

    public struct Archive: BuildAction {
        public static let revealArchiveInOrganizerDefault = true

        public var config: String?
        public var customArchiveName: String?
        public var revealArchiveInOrganizer: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public init(
            config: String? = nil,
            customArchiveName: String? = nil,
            revealArchiveInOrganizer: Bool = revealArchiveInOrganizerDefault,
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = []
        ) {
            self.config = config
            self.customArchiveName = customArchiveName
            self.revealArchiveInOrganizer = revealArchiveInOrganizer
            self.preActions = preActions
            self.postActions = postActions
        }
    }

    public struct BuildTarget: Equatable, Hashable {
        public var target: TestableTargetReference
        public var buildTypes: [BuildType]

        public init(target: TestableTargetReference, buildTypes: [BuildType] = BuildType.all) {
            self.target = target
            self.buildTypes = buildTypes
        }
    }
}

extension Scheme: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .dictionary([
                .object("test", Test.pathProperties),
            ]),
        ]
    }
}

protocol BuildAction: Equatable {
    var config: String? { get }
}

