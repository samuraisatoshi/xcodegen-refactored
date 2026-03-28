import PathKit
import Spectre
import XcodeGenKit
import XCTest
import TestSupport
import Yams

class XcodeProjInferrerTests: XCTestCase {

    // AnotherProject.xcodeproj contains: BundleX (bundle), BundleY (bundle), ExternalTarget (framework)
    // IncludedLegacy is a PBXLegacyTarget — not picked up by nativeTargets
    private let anotherProjectPath = fixturePath + "TestProject/AnotherProject/AnotherProject.xcodeproj"

    func testInfersNativeTargets() throws {
        describe {
            $0.it("infers all native targets from fixture") {
                var inferrer = XcodeProjInferrer(xcodeprojPath: self.anotherProjectPath)
                let yaml = try inferrer.infer()
                let dict = try Yams.load(yaml: yaml) as? [String: Any]
                let targets = try unwrap(dict?["targets"] as? [String: Any])
                try expect(targets.keys.contains("BundleX")) == true
                try expect(targets.keys.contains("BundleY")) == true
                try expect(targets.keys.contains("ExternalTarget")) == true
            }

            $0.it("maps bundle productType to 'bundle'") {
                var inferrer = XcodeProjInferrer(xcodeprojPath: self.anotherProjectPath)
                let yaml = try inferrer.infer()
                let dict = try Yams.load(yaml: yaml) as? [String: Any]
                let targets = try unwrap(dict?["targets"] as? [String: Any])
                let bundleX = try unwrap(targets["BundleX"] as? [String: Any])
                try expect(bundleX["type"] as? String) == "bundle"
            }

            $0.it("maps framework productType to 'framework'") {
                var inferrer = XcodeProjInferrer(xcodeprojPath: self.anotherProjectPath)
                let yaml = try inferrer.infer()
                let dict = try Yams.load(yaml: yaml) as? [String: Any]
                let targets = try unwrap(dict?["targets"] as? [String: Any])
                let external = try unwrap(targets["ExternalTarget"] as? [String: Any])
                try expect(external["type"] as? String) == "framework"
            }

            $0.it("emits 'platform' for every inferred target") {
                var inferrer = XcodeProjInferrer(xcodeprojPath: self.anotherProjectPath)
                let yaml = try inferrer.infer()
                let dict = try Yams.load(yaml: yaml) as? [String: Any]
                let targets = try unwrap(dict?["targets"] as? [String: Any])
                for (name, value) in targets {
                    let targetDict = try unwrap(value as? [String: Any])
                    guard targetDict["platform"] as? String != nil else {
                        throw failure("Target '\(name)' missing 'platform' key")
                    }
                }
            }

            $0.it("produces valid parseable YAML") {
                var inferrer = XcodeProjInferrer(xcodeprojPath: self.anotherProjectPath)
                let yaml = try inferrer.infer()
                // Should not throw
                guard try Yams.load(yaml: yaml) != nil else {
                    throw failure("YAML parsed to nil")
                }
            }

            $0.it("emits project name from xcodeproj filename") {
                var inferrer = XcodeProjInferrer(xcodeprojPath: self.anotherProjectPath)
                let yaml = try inferrer.infer()
                let dict = try Yams.load(yaml: yaml) as? [String: Any]
                try expect(dict?["name"] as? String) == "AnotherProject"
            }

            $0.it("accumulates no warnings for well-formed fixture") {
                var inferrer = XcodeProjInferrer(xcodeprojPath: self.anotherProjectPath)
                _ = try inferrer.infer()
                // AnotherProject has only supported product types — expect no warnings
                try expect(inferrer.warnings.isEmpty) == true
            }
        }
    }

    func testErrorCases() throws {
        describe {
            $0.it("throws when xcodeproj does not exist") {
                let missing = fixturePath + "nonexistent/Missing.xcodeproj"
                var inferrer = XcodeProjInferrer(xcodeprojPath: missing)
                var threw = false
                do {
                    _ = try inferrer.infer()
                } catch {
                    threw = true
                }
                try expect(threw) == true
            }
        }
    }

    func testSPMFixture() throws {
        describe {
            $0.it("infers SPM fixture without crashing") {
                let spmPath = fixturePath + "SPM/SPM.xcodeproj"
                var inferrer = XcodeProjInferrer(xcodeprojPath: spmPath)
                let yaml = try inferrer.infer()
                let dict = try Yams.load(yaml: yaml) as? [String: Any]
                // SPM fixture must have at least one target
                let targets = dict?["targets"] as? [String: Any]
                try expect((targets?.count ?? 0) > 0) == true
            }
        }
    }
}

