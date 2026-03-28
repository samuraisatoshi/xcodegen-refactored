import Foundation
import PathKit

extension Project {

    func validatePackages() -> [SpecValidationError.ValidationError] {
        var errors: [SpecValidationError.ValidationError] = []
        for (name, package) in packages {
            if case let .local(path, _, _) = package, !(basePath + Path(path).normalize()).exists {
                errors.append(.invalidLocalPackage(name))
            }
        }
        return errors
    }
}
