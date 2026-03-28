import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import XcodeProj
import Version

/// Runs generate in a loop, re-triggering on spec file changes.
/// Uses DispatchSource for zero-dependency FSEvents-like watching.
/// Debounces rapid saves (300ms) to avoid multiple triggers per save.
class WatchCommand: ProjectCommand {

    init(version: Version) {
        super.init(version: version,
                   name: "watch",
                   shortDescription: "Regenerate the project automatically when the spec changes")
    }

    override func guideContent(locale: GuideLocale) -> CommandGuide {
        WatchGuide.content(locale: locale)
    }

    override func execute() throws {
        if guide {
            let locale = GuideLocale.resolve(lang)
            stdout.print(try guideContent(locale: locale).jsonString())
            return
        }

        var specPaths: [Path] = []
        if let spec = spec {
            specPaths = spec.components(separatedBy: ",").map { Path($0).absolute() }
        } else {
            specPaths = [Path("project.yml").absolute()]
        }

        for specPath in specPaths {
            guard specPath.exists else {
                throw GenerationError.missingProjectSpec(specPath)
            }
        }

        // Run initial generation
        info("👁  Watching \(specPaths.map(\.lastComponent).joined(separator: ", ")) — Ctrl+C to stop")
        regenerate(specPaths: specPaths)

        // Set up one watcher per spec file
        var sources: [DispatchSourceFileSystemObject] = []
        var debounceItem: DispatchWorkItem?

        for specPath in specPaths {
            let fd = open(specPath.string, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                debounceItem?.cancel()
                let item = DispatchWorkItem {
                    self?.regenerate(specPaths: specPaths)
                }
                debounceItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }

        // Handle Ctrl+C for clean shutdown
        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        sigint.setEventHandler {
            sources.forEach { $0.cancel() }
            exit(0)
        }
        sigint.resume()

        dispatchMain()
    }

    private func regenerate(specPaths: [Path]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        info("[\(timestamp)] Regenerating...")

        var specPathsList: [Path] = []
        if let spec = spec {
            specPathsList = spec.components(separatedBy: ",").map { Path($0).absolute() }
        } else {
            specPathsList = specPaths
        }

        for specPath in specPathsList {
            let specLoader = SpecLoader(version: version)
            let variables: [String: String] = disableEnvExpansion ? [:] : ProcessInfo.processInfo.environment

            let project: Project
            do {
                project = try specLoader.loadProject(path: specPath, projectRoot: projectRoot, variables: variables)
            } catch {
                warning("Error loading spec: \(error.localizedDescription)")
                return
            }

            let projectDirectory = specPath.parent()
            let projectPath = projectDirectory + "\(project.name).xcodeproj"

            do {
                try project.validateMinimumXcodeGenVersion(version)
                try project.validate()
            } catch {
                warning("Validation error: \(error)")
                return
            }

            let fileWriter = FileWriter(project: project)
            do { try fileWriter.writePlists() } catch {
                warning("Error writing plists: \(error.localizedDescription)")
                return
            }

            let projectGenerator = ProjectGenerator(project: project)
            guard let userName = ProcessInfo.processInfo.environment["USER"] else {
                warning("Missing USER environment variable")
                return
            }

            let xcodeProject: XcodeProj
            do {
                xcodeProject = try projectGenerator.generateXcodeProject(in: projectDirectory, userName: userName)
            } catch {
                warning("Generation error: \(error.localizedDescription)")
                return
            }

            do {
                try fileWriter.writeXcodeProject(xcodeProject, to: projectPath)
                success("✓ \(project.name).xcodeproj")
            } catch {
                warning("Write error: \(error.localizedDescription)")
            }
        }
    }

    // Not used — execute() is fully overridden
    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {}
}
