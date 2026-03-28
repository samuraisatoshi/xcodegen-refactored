import Foundation
import PathKit

extension Project {

    func validateSchemes() -> [SpecValidationError.ValidationError] {
        var errors: [SpecValidationError.ValidationError] = []

        for scheme in schemes {
            errors.append(
                contentsOf: scheme.build.targets.compactMap { validationError(for: $0.target, in: scheme, action: "build") }
            )
            if let action = scheme.run, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }

            if !options.disabledValidations.contains(.missingTestPlans) {
                let invalidTestPlans: [TestPlan] = scheme.test?.testPlans.filter { !(basePath + $0.path).exists } ?? []
                errors.append(contentsOf: invalidTestPlans.map { .invalidTestPlan($0) })
            }

            let defaultPlanCount = scheme.test?.testPlans.filter { $0.defaultPlan }.count ?? 0
            if defaultPlanCount > 1 {
                errors.append(.multipleDefaultTestPlans)
            }

            if let action = scheme.test, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            errors.append(
                contentsOf: scheme.test?.targets.compactMap { validationError(for: $0.targetReference, in: scheme, action: "test") } ?? []
            )
            errors.append(
                contentsOf: scheme.test?.coverageTargets.compactMap { validationError(for: $0, in: scheme, action: "test") } ?? []
            )
            if let action = scheme.profile, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            if let action = scheme.analyze, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            if let action = scheme.archive, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
        }

        return errors
    }
}
