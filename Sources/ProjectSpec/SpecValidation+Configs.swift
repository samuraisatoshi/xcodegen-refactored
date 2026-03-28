import Foundation
import PathKit

extension Project {

    func validateConfigs() -> [SpecValidationError.ValidationError] {
        var errors: [SpecValidationError.ValidationError] = []

        for (config, configFile) in configFiles {
            if !options.disabledValidations.contains(.missingConfigFiles) && !(basePath + configFile).exists {
                errors.append(.invalidConfigFile(configFile: configFile, config: config))
            }
            if !options.disabledValidations.contains(.missingConfigs) && getConfig(config) == nil {
                errors.append(.invalidConfigFileConfig(config))
            }
        }

        if let configName = options.defaultConfig {
            if !configs.contains(where: { $0.name == configName }) {
                errors.append(.missingDefaultConfig(configName: configName))
            }
        }

        for settings in settingGroups.values {
            errors += validateSettings(settings)
        }

        return errors
    }
}
