import Spectre
import XcodeGenKit
import XCTest

class XcodeSpecPatcherTests: XCTestCase {

    private let patcher = XcodeSpecPatcher()

    // MARK: - Fixtures

    private func makeDict(targetName: String = "MyApp", extra: [String: Any] = [:]) -> [String: Any] {
        var targetDict: [String: Any] = ["type": "application", "platform": "iOS"]
        for (k, v) in extra { targetDict[k] = v }
        return ["name": "TestProject", "targets": [targetName: targetDict]]
    }

    // MARK: - addSource

    func testAddSource() throws {
        describe {
            $0.it("appends a new source path to the target") {
                let dict = self.makeDict()
                let result = try self.patcher.addSource(to: dict, target: "MyApp", path: "Sources/NewFile.swift")
                let sources = self.sources(in: result, target: "MyApp")
                try expect(sources.contains("Sources/NewFile.swift")) == true
            }

            $0.it("does not duplicate an existing source path") {
                var dict = self.makeDict()
                (dict["targets"] as? [String: Any]).flatMap { $0["MyApp"] as? [String: Any] }.map {
                    var t = $0; t["sources"] = ["Sources/Existing.swift"]
                    dict["targets"] = ["MyApp": t]
                }
                let result = try self.patcher.addSource(to: dict, target: "MyApp", path: "Sources/Existing.swift")
                let sources = self.sources(in: result, target: "MyApp")
                try expect(sources.filter { $0 == "Sources/Existing.swift" }.count) == 1
            }

            $0.it("appends to existing sources without removing them") {
                let dict = self.makeDict(extra: ["sources": ["Sources/A.swift"]])
                let result = try self.patcher.addSource(to: dict, target: "MyApp", path: "Sources/B.swift")
                let sources = self.sources(in: result, target: "MyApp")
                try expect(sources.contains("Sources/A.swift")) == true
                try expect(sources.contains("Sources/B.swift")) == true
            }

            $0.it("throws cannotMutate for unknown target") {
                let dict = self.makeDict()
                var threw = false
                do {
                    _ = try self.patcher.addSource(to: dict, target: "Unknown", path: "x.swift")
                } catch { threw = true }
                try expect(threw) == true
            }
        }
    }

    // MARK: - addSDKDependency

    func testAddSDKDependency() throws {
        describe {
            $0.it("appends an SDK dependency") {
                let dict = self.makeDict()
                let result = try self.patcher.addSDKDependency(to: dict, target: "MyApp", sdk: "CoreML.framework")
                let deps = self.deps(in: result, target: "MyApp")
                try expect(deps.contains(where: { $0["sdk"] as? String == "CoreML.framework" })) == true
            }

            $0.it("does not duplicate an existing SDK dependency") {
                let dict = self.makeDict(extra: ["dependencies": [["sdk": "CoreML.framework"]]])
                let result = try self.patcher.addSDKDependency(to: dict, target: "MyApp", sdk: "CoreML.framework")
                let deps = self.deps(in: result, target: "MyApp")
                try expect(deps.filter { $0["sdk"] as? String == "CoreML.framework" }.count) == 1
            }

            $0.it("preserves existing dependencies when adding a new SDK") {
                let dict = self.makeDict(extra: ["dependencies": [["sdk": "UIKit.framework"]]])
                let result = try self.patcher.addSDKDependency(to: dict, target: "MyApp", sdk: "CoreML.framework")
                let deps = self.deps(in: result, target: "MyApp")
                try expect(deps.contains(where: { $0["sdk"] as? String == "UIKit.framework" })) == true
                try expect(deps.contains(where: { $0["sdk"] as? String == "CoreML.framework" })) == true
            }

            $0.it("throws cannotMutate for unknown target") {
                let dict = self.makeDict()
                var threw = false
                do { _ = try self.patcher.addSDKDependency(to: dict, target: "X", sdk: "Foo.framework") }
                catch { threw = true }
                try expect(threw) == true
            }
        }
    }

    // MARK: - addPackageDependency

    func testAddPackageDependency() throws {
        describe {
            $0.it("appends a package dependency") {
                let dict = self.makeDict()
                let result = try self.patcher.addPackageDependency(to: dict, target: "MyApp", package: "Alamofire")
                let deps = self.deps(in: result, target: "MyApp")
                try expect(deps.contains(where: { $0["package"] as? String == "Alamofire" })) == true
            }

            $0.it("does not duplicate an existing package dependency") {
                let dict = self.makeDict(extra: ["dependencies": [["package": "Alamofire"]]])
                let result = try self.patcher.addPackageDependency(to: dict, target: "MyApp", package: "Alamofire")
                let deps = self.deps(in: result, target: "MyApp")
                try expect(deps.filter { $0["package"] as? String == "Alamofire" }.count) == 1
            }
        }
    }

    // MARK: - setSetting

    func testSetSetting() throws {
        describe {
            $0.it("writes to base settings when config is nil") {
                let dict = self.makeDict()
                let result = try self.patcher.setSetting(in: dict, target: "MyApp",
                                                         key: "SWIFT_VERSION", value: "5.9", config: nil)
                let base = self.baseSettings(in: result, target: "MyApp")
                try expect(base["SWIFT_VERSION"] as? String) == "5.9"
            }

            $0.it("writes to config-scoped settings when config is provided") {
                let dict = self.makeDict()
                let result = try self.patcher.setSetting(in: dict, target: "MyApp",
                                                         key: "GCC_OPTIMIZATION_LEVEL", value: "0", config: "Debug")
                let configSetting = self.configSetting(in: result, target: "MyApp", config: "Debug")
                try expect(configSetting["GCC_OPTIMIZATION_LEVEL"] as? String) == "0"
            }

            $0.it("overwrites an existing base setting") {
                let dict = self.makeDict(extra: ["settings": ["base": ["SWIFT_VERSION": "5.0"]]])
                let result = try self.patcher.setSetting(in: dict, target: "MyApp",
                                                         key: "SWIFT_VERSION", value: "6.0", config: nil)
                let base = self.baseSettings(in: result, target: "MyApp")
                try expect(base["SWIFT_VERSION"] as? String) == "6.0"
            }

            $0.it("does not affect base settings when writing to a config") {
                let dict = self.makeDict(extra: ["settings": ["base": ["SWIFT_VERSION": "5.9"]]])
                let result = try self.patcher.setSetting(in: dict, target: "MyApp",
                                                         key: "DEBUG_FLAG", value: "YES", config: "Debug")
                let base = self.baseSettings(in: result, target: "MyApp")
                try expect(base["SWIFT_VERSION"] as? String) == "5.9"
            }

            $0.it("throws cannotMutate for unknown target") {
                let dict = self.makeDict()
                var threw = false
                do { _ = try self.patcher.setSetting(in: dict, target: "X", key: "K", value: "V", config: nil) }
                catch { threw = true }
                try expect(threw) == true
            }
        }
    }

    // MARK: - Helpers

    private func sources(in dict: [String: Any], target: String) -> [String] {
        guard let targets = dict["targets"] as? [String: Any],
              let t = targets[target] as? [String: Any],
              let sources = t["sources"] as? [Any] else { return [] }
        return sources.compactMap { ($0 as? String) ?? ($0 as? [String: Any])?["path"] as? String }
    }

    private func deps(in dict: [String: Any], target: String) -> [[String: Any]] {
        guard let targets = dict["targets"] as? [String: Any],
              let t = targets[target] as? [String: Any],
              let deps = t["dependencies"] as? [[String: Any]] else { return [] }
        return deps
    }

    private func baseSettings(in dict: [String: Any], target: String) -> [String: Any] {
        guard let targets = dict["targets"] as? [String: Any],
              let t = targets[target] as? [String: Any],
              let settings = t["settings"] as? [String: Any],
              let base = settings["base"] as? [String: Any] else { return [:] }
        return base
    }

    private func configSetting(in dict: [String: Any], target: String, config: String) -> [String: Any] {
        guard let targets = dict["targets"] as? [String: Any],
              let t = targets[target] as? [String: Any],
              let settings = t["settings"] as? [String: Any],
              let configs = settings["configs"] as? [String: Any],
              let configDict = configs[config] as? [String: Any] else { return [:] }
        return configDict
    }
}
