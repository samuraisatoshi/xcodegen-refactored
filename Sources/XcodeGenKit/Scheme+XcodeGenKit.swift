import Foundation
import ProjectSpec

extension Scheme {
    public init(name: String, target: ProjectTarget, targetScheme: TargetScheme, project: Project, debugConfig: String, releaseConfig: String) {
        self.init(
            name: name,
            build: .init(
                targets: Scheme.buildTargets(for: target, project: project),
                buildImplicitDependencies: targetScheme.buildImplicitDependencies,
                preActions: targetScheme.preActions,
                postActions: targetScheme.postActions
            ),
            run: .init(
                config: debugConfig,
                commandLineArguments: targetScheme.commandLineArguments,
                environmentVariables: targetScheme.environmentVariables,
                disableMainThreadChecker: targetScheme.disableMainThreadChecker,
                stopOnEveryMainThreadCheckerIssue: targetScheme.stopOnEveryMainThreadCheckerIssue,
                disableThreadPerformanceChecker: targetScheme.disableThreadPerformanceChecker,
                language: targetScheme.language,
                region: targetScheme.region,
                storeKitConfiguration: targetScheme.storeKitConfiguration
            ),
            test: .init(
                config: debugConfig,
                gatherCoverageData: targetScheme.gatherCoverageData,
                coverageTargets: targetScheme.coverageTargets,
                disableMainThreadChecker: targetScheme.disableMainThreadChecker,
                commandLineArguments: targetScheme.commandLineArguments,
                targets: targetScheme.testTargets,
                environmentVariables: targetScheme.environmentVariables,
                testPlans: targetScheme.testPlans,
                language: targetScheme.language,
                region: targetScheme.region
            ),
            profile: .init(
                config: releaseConfig,
                commandLineArguments: targetScheme.commandLineArguments,
                environmentVariables: targetScheme.environmentVariables
            ),
            analyze: .init(
                config: debugConfig
            ),
            archive: .init(
                config: releaseConfig
            ),
            management: targetScheme.management
        )
    }

    private static func buildTargets(for target: ProjectTarget, project: Project) -> [BuildTarget] {
        let buildTarget = Scheme.BuildTarget(target: TestableTargetReference.local(target.name))
        switch target.type {
        case .watchApp, .watch2App:
            let hostTarget = project.targets
                .first { projectTarget in
                    projectTarget.dependencies.contains { $0.reference == target.name }
                }
                .map { BuildTarget(target: TestableTargetReference.local($0.name)) }
            return hostTarget.map { [buildTarget, $0] } ?? [buildTarget]
        default:
            return [buildTarget]
        }
    }
}
