import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import XCTest
import TestSupport
import Version

/// Tests the validation logic exercised by ValidateCommand:
/// SpecLoader.loadProject + project.validate()
class ValidateCommandLogicTests: XCTestCase {

    private let version = Version(2, 0, 0)

    func testValidSpec() throws {
        describe {
            $0.it("valid project.yml loads and validates without errors") {
                let specLoader = SpecLoader(version: self.version)
                let path = fixturePath + "TestProject/AnotherProject/project.yml"
                let project = try specLoader.loadProject(path: path)
                // validate() throws on failure — if it doesn't throw, the spec is valid
                try project.validate()
            }

            $0.it("project with no targets validates without errors") {
                let project = Project(name: "Empty", targets: [])
                try project.validate()
            }

            $0.it("project with target referencing non-existent dependency fails validation") {
                let missingDep = Dependency(type: .target, reference: "NonExistentLib")
                let target = Target(
                    name: "App",
                    type: .application,
                    platform: .iOS,
                    dependencies: [missingDep]
                )
                let project = Project(name: "BadProject", targets: [target])
                var threw = false
                do {
                    try project.validate()
                } catch {
                    threw = true
                }
                try expect(threw) == true
            }
        }
    }

    func testSpecLoaderErrorOnMissingFile() throws {
        describe {
            $0.it("throws when spec file does not exist") {
                let specLoader = SpecLoader(version: self.version)
                let missing = fixturePath + "nonexistent/project.yml"
                var threw = false
                do {
                    _ = try specLoader.loadProject(path: missing)
                } catch {
                    threw = true
                }
                try expect(threw) == true
            }
        }
    }

    func testSPMSpec() throws {
        describe {
            $0.it("SPM fixture spec validates without errors") {
                let specLoader = SpecLoader(version: self.version)
                let path = fixturePath + "SPM/project.yml"
                guard path.exists else { return }
                let project = try specLoader.loadProject(path: path)
                try project.validate()
            }
        }
    }
}
