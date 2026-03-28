import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension PBXProjGenerator {

    // MARK: - Dependency loop

    func processDependencies(
        for target: Target,
        targetDependencies: [Dependency],
        carthageDependencies: [ResolvedCarthageDependency],
        directlyEmbedCarthage: Bool,
        ctx: inout TargetGenerationContext
    ) throws {
        for dependency in targetDependencies {
            let embed = dependency.embed ?? target.shouldEmbedDependencies
            let platform = makePlatformFilter(for: dependency.platformFilter)
            let platforms = makeDestinationFilters(for: dependency.destinationFilters)

            switch dependency.type {
            case .target:
                let dependencyTargetReference = try TargetReference(dependency.reference)
                switch dependencyTargetReference.location {
                case .local:
                    let dependencyTargetName = dependency.reference
                    let targetDependency = generateTargetDependency(
                        from: target.name, to: dependencyTargetName,
                        platform: platform, platforms: platforms
                    )
                    ctx.dependencies.append(targetDependency)
                    guard let dependencyTarget = project.getTarget(dependencyTargetName) else { continue }
                    processTargetDependency(
                        dependency,
                        dependencyTarget: dependencyTarget,
                        embedFileReference: targetFileReferences[dependencyTarget.name],
                        platform: platform, platforms: platforms,
                        target: target, ctx: &ctx
                    )
                case .project(let dependencyProjectName):
                    let dependencyTargetName = dependencyTargetReference.name
                    let (targetDependency, dependencyTarget, dependencyProductProxy) = try generateExternalTargetDependency(
                        from: target.name, to: dependencyTargetName,
                        in: dependencyProjectName, platform: target.platform
                    )
                    ctx.dependencies.append(targetDependency)
                    processTargetDependency(
                        dependency,
                        dependencyTarget: dependencyTarget,
                        embedFileReference: dependencyProductProxy,
                        platform: platform, platforms: platforms,
                        target: target, ctx: &ctx
                    )
                }

            case .framework:
                if !dependency.implicit {
                    let buildPath = Path(dependency.reference).parent().string.quoted
                    ctx.frameworkBuildPaths.insert(buildPath)
                }

                let fileReference: PBXFileElement
                if dependency.implicit {
                    fileReference = sourceGenerator.getFileReference(
                        path: Path(dependency.reference),
                        inPath: project.basePath,
                        sourceTree: .buildProductsDir
                    )
                } else {
                    fileReference = sourceGenerator.getFileReference(
                        path: Path(dependency.reference),
                        inPath: project.basePath
                    )
                }

                if dependency.link ?? (target.type != .staticLibrary) {
                    let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                    pbxBuildFile.platformFilter = platform
                    pbxBuildFile.platformFilters = platforms
                    ctx.targetFrameworkBuildFiles.append(addObject(pbxBuildFile))
                }

                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    pbxBuildFile.platformFilter = platform
                    pbxBuildFile.platformFilters = platforms
                    let embedFile = addObject(pbxBuildFile)
                    if let copyPhase = dependency.copyPhase {
                        ctx.buildFileCopyPhases[embedFile] = copyPhase
                        ctx.customCopyDependenciesReferences.append(embedFile)
                    } else {
                        ctx.copyFrameworksReferences.append(embedFile)
                    }
                }

            case .sdk(let root):
                var dependencyPath = Path(dependency.reference)
                if !dependency.reference.contains("/") {
                    switch dependencyPath.extension ?? "" {
                    case "framework": dependencyPath = Path("System/Library/Frameworks") + dependencyPath
                    case "tbd":       dependencyPath = Path("usr/lib") + dependencyPath
                    case "dylib":     dependencyPath = Path("usr/lib") + dependencyPath
                    default: break
                    }
                }

                let fileReference: PBXFileReference
                if let existingRef = sdkFileReferences[dependency.reference] {
                    fileReference = existingRef
                } else {
                    let sourceTree: PBXSourceTree = root.map { .custom($0) } ?? .sdkRoot
                    fileReference = addObject(PBXFileReference(
                        sourceTree: sourceTree,
                        name: dependencyPath.lastComponent,
                        lastKnownFileType: Xcode.fileType(path: dependencyPath),
                        path: dependencyPath.string
                    ))
                    sdkFileReferences[dependency.reference] = fileReference
                    frameworkFiles.append(fileReference)
                }

                let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                pbxBuildFile.platformFilter = platform
                pbxBuildFile.platformFilters = platforms
                ctx.targetFrameworkBuildFiles.append(addObject(pbxBuildFile))

                if dependency.embed == true {
                    let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    pbxBuildFile.platformFilter = platform
                    pbxBuildFile.platformFilters = platforms
                    let embedFile = addObject(pbxBuildFile)
                    if let copyPhase = dependency.copyPhase {
                        ctx.buildFileCopyPhases[embedFile] = copyPhase
                        ctx.customCopyDependenciesReferences.append(embedFile)
                    } else {
                        ctx.copyFrameworksReferences.append(embedFile)
                    }
                }

            case .carthage(let findFrameworks, let linkType):
                let allDependencies = (findFrameworks ?? project.options.findCarthageFrameworks)
                    ? carthageResolver.relatedDependencies(for: dependency, in: target.platform)
                    : [dependency]
                allDependencies.forEach { dep in
                    let platformPath = Path(carthageResolver.buildPath(for: target.platform, linkType: linkType))
                    var frameworkPath = platformPath + dep.reference
                    if frameworkPath.extension == nil {
                        frameworkPath = Path(frameworkPath.string + ".framework")
                    }
                    let fileReference = self.sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)
                    self.carthageFrameworksByPlatform[target.platform.carthageName, default: []].insert(fileReference)

                    let isStaticLibrary = target.type == .staticLibrary
                    let isCarthageStaticLink = dep.carthageLinkType == .static
                    if dep.link ?? (!isStaticLibrary && !isCarthageStaticLink) {
                        let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dep))
                        pbxBuildFile.platformFilter = platform
                        pbxBuildFile.platformFilters = platforms
                        ctx.targetFrameworkBuildFiles.append(addObject(pbxBuildFile))
                    }
                }

            case .package(let products):
                let packageReference = packageReferences[dependency.reference]
                if packageReference == nil, localPackageReferences[dependency.reference] == nil { continue }

                if !products.isEmpty {
                    for product in products {
                        addPackageProductDependency(named: product, dependency: dependency, packageReference: packageReference, platform: platform, platforms: platforms, target: target, ctx: &ctx)
                    }
                } else {
                    addPackageProductDependency(named: dependency.reference, dependency: dependency, packageReference: packageReference, platform: platform, platforms: platforms, target: target, ctx: &ctx)
                }

            case .bundle:
                guard target.type != .staticLibrary && target.type != .dynamicLibrary else { break }
                let fileReference = sourceGenerator.getFileReference(
                    path: Path(dependency.reference),
                    inPath: project.basePath,
                    sourceTree: .buildProductsDir
                )
                let pbxBuildFile = PBXBuildFile(
                    file: fileReference,
                    settings: embed ? getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true) : nil
                )
                pbxBuildFile.platformFilter = platform
                pbxBuildFile.platformFilters = platforms
                ctx.copyBundlesReferences.append(addObject(pbxBuildFile))
                if !bundleFiles.contains(fileReference) {
                    bundleFiles.append(fileReference)
                }
            }
        }

        // Carthage embed pass
        for carthageDependency in carthageDependencies {
            let dependency = carthageDependency.dependency
            let embed = dependency.embed ?? target.shouldEmbedCarthageDependencies

            let platformPath = Path(carthageResolver.buildPath(for: target.platform, linkType: dependency.carthageLinkType ?? .default))
            var frameworkPath = platformPath + dependency.reference
            if frameworkPath.extension == nil {
                frameworkPath = Path(frameworkPath.string + ".framework")
            }
            let fileReference = sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

            if dependency.carthageLinkType == .static {
                guard carthageDependency.isFromTopLevelTarget else { continue }
                ctx.targetFrameworkBuildFiles.append(addObject(
                    PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                ))
            } else if embed {
                if directlyEmbedCarthage {
                    let embedFile = addObject(
                        PBXBuildFile(file: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    )
                    if let copyPhase = dependency.copyPhase {
                        ctx.buildFileCopyPhases[embedFile] = copyPhase
                        ctx.customCopyDependenciesReferences.append(embedFile)
                    } else {
                        ctx.copyFrameworksReferences.append(embedFile)
                    }
                } else {
                    ctx.carthageFrameworksToEmbed.append(dependency.reference)
                }
            }
        }

        ctx.carthageFrameworksToEmbed = ctx.carthageFrameworksToEmbed.uniqued()
    }

    // MARK: - Single target dependency

    func processTargetDependency(
        _ dependency: Dependency,
        dependencyTarget: Target,
        embedFileReference: PBXFileElement?,
        platform: String?,
        platforms: [String]?,
        target: Target,
        ctx: inout TargetGenerationContext
    ) {
        let dependencyLinkage = dependencyTarget.defaultLinkage
        let link = dependency.link ??
            ((dependencyLinkage == .dynamic && target.type != .staticLibrary) ||
             (dependencyLinkage == .static && target.type.isExecutable))

        if link, let dependencyFile = embedFileReference {
            let pbxBuildFile = PBXBuildFile(file: dependencyFile, settings: getDependencyFrameworkSettings(dependency: dependency))
            pbxBuildFile.platformFilter = platform
            pbxBuildFile.platformFilters = platforms
            ctx.targetFrameworkBuildFiles.append(addObject(pbxBuildFile))

            if !ctx.anyDependencyRequiresObjCLinking
                && dependencyTarget.requiresObjCLinking ?? (dependencyTarget.type == .staticLibrary) {
                ctx.anyDependencyRequiresObjCLinking = true
            }
        }

        let embed = dependency.embed ?? target.type.shouldEmbed(dependencyTarget)
        if embed {
            let pbxBuildFile = PBXBuildFile(
                file: embedFileReference,
                settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? !dependencyTarget.type.isExecutable)
            )
            pbxBuildFile.platformFilter = platform
            pbxBuildFile.platformFilters = platforms
            let embedFile = addObject(pbxBuildFile)

            if let copyPhase = dependency.copyPhase {
                ctx.buildFileCopyPhases[embedFile] = copyPhase
                ctx.customCopyDependenciesReferences.append(embedFile)
            } else if dependencyTarget.type.isExtension {
                if dependencyTarget.type == .extensionKitExtension {
                    ctx.extensionKitExtensions.append(embedFile)
                } else {
                    ctx.extensions.append(embedFile)
                }
            } else if dependencyTarget.type.isSystemExtension {
                ctx.systemExtensions.append(embedFile)
            } else if dependencyTarget.type == .onDemandInstallCapableApplication {
                ctx.appClips.append(embedFile)
            } else if dependencyTarget.type.isFramework {
                ctx.copyFrameworksReferences.append(embedFile)
            } else if dependencyTarget.type.isApp && dependencyTarget.platform == .watchOS {
                ctx.copyWatchReferences.append(embedFile)
            } else if dependencyTarget.type == .xpcService {
                ctx.copyFilesBuildPhasesFiles[.xpcServices, default: []].append(embedFile)
            } else {
                ctx.copyResourcesReferences.append(embedFile)
            }
        }
    }

    // MARK: - Package product dependency

    func addPackageProductDependency(
        named productName: String,
        dependency: Dependency,
        packageReference: XCRemoteSwiftPackageReference?,
        platform: String?,
        platforms: [String]?,
        target: Target,
        ctx: inout TargetGenerationContext
    ) {
        let packageDependency = addObject(
            XCSwiftPackageProductDependency(productName: productName, package: packageReference)
        )

        if dependency.link ?? true {
            ctx.packageDependencies.append(packageDependency)
        }

        let link = dependency.link ?? (target.type != .staticLibrary)
        if link {
            let file = PBXBuildFile(product: packageDependency, settings: getDependencyFrameworkSettings(dependency: dependency))
            file.platformFilter = platform
            file.platformFilters = platforms
            ctx.targetFrameworkBuildFiles.append(addObject(file))
        } else {
            ctx.dependencies.append(addObject(
                PBXTargetDependency(platformFilter: platform, platformFilters: platforms, product: packageDependency)
            ))
        }

        if dependency.embed == true {
            let pbxBuildFile = PBXBuildFile(
                product: packageDependency,
                settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true)
            )
            pbxBuildFile.platformFilter = platform
            pbxBuildFile.platformFilters = platforms
            let embedFile = addObject(pbxBuildFile)
            if let copyPhase = dependency.copyPhase {
                ctx.buildFileCopyPhases[embedFile] = copyPhase
                ctx.customCopyDependenciesReferences.append(embedFile)
            } else {
                ctx.copyFrameworksReferences.append(embedFile)
            }
        }
    }
}
