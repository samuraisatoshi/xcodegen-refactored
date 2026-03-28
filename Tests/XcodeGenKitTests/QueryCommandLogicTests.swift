import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import XCTest
import TestSupport
import Version

/// Tests the query logic exercised by QueryCommand:
/// project.targets, getTarget(), sources, dependencies, settings
class QueryCommandLogicTests: XCTestCase {

    private let version = Version(2, 0, 0)

    // AnotherProject is a small, self-contained fixture: BundleX, BundleY, ExternalTarget
    private var anotherProject: Project!

    override func setUpWithError() throws {
        let specLoader = SpecLoader(version: version)
        anotherProject = try specLoader.loadProject(
            path: fixturePath + "TestProject/AnotherProject/project.yml"
        )
    }

    func testQueryTargets() throws {
        describe {
            $0.it("lists all targets in the project") {
                let names = self.anotherProject.targets.map { $0.name }
                try expect(names.contains("BundleX")) == true
                try expect(names.contains("BundleY")) == true
                try expect(names.contains("ExternalTarget")) == true
            }

            $0.it("getTarget returns nil for unknown name") {
                let target = self.anotherProject.getTarget("NonExistent")
                try expect(target == nil) == true
            }

            $0.it("getTarget returns target for known name") {
                let target = self.anotherProject.getTarget("BundleX")
                try expect(target != nil) == true
            }
        }
    }

    func testQueryTargetType() throws {
        describe {
            $0.it("BundleX has bundle type") {
                let target = try unwrap(self.anotherProject.getTarget("BundleX"))
                try expect(target.type) == .bundle
            }

            $0.it("ExternalTarget has framework type") {
                let target = try unwrap(self.anotherProject.getTarget("ExternalTarget"))
                try expect(target.type) == .framework
            }
        }
    }

    func testQuerySources() throws {
        describe {
            // AnotherProject targets have no explicit sources — fixture uses implicit glob
            $0.it("BundleX sources property is accessible (may be empty for implicit globs)") {
                let target = try unwrap(self.anotherProject.getTarget("BundleX"))
                // Just accessing the property must not crash
                _ = target.sources
            }

            $0.it("in-memory target with explicit sources has correct source paths") {
                let src = TargetSource(path: "Sources/MyFile.swift")
                let target = Target(
                    name: "App",
                    type: .application,
                    platform: .iOS,
                    sources: [src]
                )
                let project = Project(name: "P", targets: [target])
                let found = try unwrap(project.getTarget("App"))
                try expect(found.sources.count) == 1
                try expect(found.sources[0].path) == "Sources/MyFile.swift"
            }
        }
    }

    func testQueryDependencies() throws {
        describe {
            $0.it("can read dependencies array without crashing") {
                for target in self.anotherProject.targets {
                    // dependencies is always present (may be empty)
                    _ = target.dependencies
                }
            }
        }
    }

    func testQuerySettings() throws {
        describe {
            $0.it("can read target build settings without crashing") {
                let target = try unwrap(self.anotherProject.getTarget("ExternalTarget"))
                _ = target.settings.buildSettings
            }

            $0.it("config-level settings are accessible") {
                let target = try unwrap(self.anotherProject.getTarget("ExternalTarget"))
                _ = target.settings.configSettings
            }
        }
    }

    func testInMemoryProject() throws {
        describe {
            $0.it("in-memory project with known targets is fully queryable") {
                let dep = Dependency(type: .sdk(root: nil), reference: "CoreML.framework")
                let app = Target(
                    name: "TestApp",
                    type: .application,
                    platform: .iOS,
                    settings: Settings(buildSettings: ["SWIFT_VERSION": "5.9"]),
                    dependencies: [dep]
                )
                let project = Project(name: "TestProj", targets: [app])

                let found = try unwrap(project.getTarget("TestApp"))
                try expect(found.type) == .application
                try expect(found.platform) == .iOS
                try expect(found.dependencies.count) == 1
                try expect(found.dependencies[0].reference) == "CoreML.framework"
                try expect(found.settings.buildSettings["SWIFT_VERSION"]?.stringValue) == "5.9"
            }
        }
    }
}
