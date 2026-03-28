import Foundation

enum PatchGuide {
    static func content(locale: GuideLocale) -> CommandGuide {
        switch locale {
        case .en:   return en
        case .ptBR: return ptBR
        case .es:   return es
        }
    }

    // MARK: - English

    static let en = CommandGuide(
        command: "patch",
        purpose: "Semantically edit the project spec and regenerate the .xcodeproj atomically.",
        agentSummary: "Use this command instead of directly editing project.yml YAML. Provides safe, intent-based operations (add-source, add-dependency, set-setting) that mutate the spec correctly and invoke generate automatically. YAML is reformatted on write — comments and key order are not preserved (documented trade-off acceptable for agent use).",
        whenToUse: [
            "When an agent needs to add a source file to a target without risking YAML corruption.",
            "When adding an SDK framework or SPM package dependency to a target.",
            "When setting a build setting for a target, optionally scoped to a specific config.",
            "Use --dry-run first to preview the modified YAML before applying.",
        ],
        workflow: [
            "Load the spec and resolve the project.",
            "Verify the target exists.",
            "Apply the semantic patch to the raw YAML dictionary.",
            "If --dry-run: print modified YAML and exit.",
            "Write modified YAML to spec file.",
            "Reload spec and run generate pipeline.",
        ],
        parameters: [
            .init(name: "--operation", required: true, kind: "key",
                  description: "Patch operation. One of: add-source, add-dependency, set-setting.",
                  defaultValue: "none",
                  example: "--operation add-source"),
            .init(name: "--target", required: true, kind: "key",
                  description: "Target name to patch.",
                  defaultValue: "none",
                  example: "--target MyApp"),
            .init(name: "--path", required: false, kind: "key",
                  description: "Source file path (for add-source).",
                  defaultValue: "none",
                  example: "--path Sources/NewFile.swift"),
            .init(name: "--sdk", required: false, kind: "key",
                  description: "SDK framework name (for add-dependency).",
                  defaultValue: "none",
                  example: "--sdk CoreML.framework"),
            .init(name: "--package", required: false, kind: "key",
                  description: "SPM package product name (for add-dependency).",
                  defaultValue: "none",
                  example: "--package Alamofire"),
            .init(name: "--key", required: false, kind: "key",
                  description: "Build setting key (for set-setting).",
                  defaultValue: "none",
                  example: "--key SWIFT_VERSION"),
            .init(name: "--value", required: false, kind: "key",
                  description: "Build setting value (for set-setting).",
                  defaultValue: "none",
                  example: "--value 6.0"),
            .init(name: "--config", required: false, kind: "key",
                  description: "Config name for set-setting (omit for base settings).",
                  defaultValue: "base settings",
                  example: "--config Debug"),
            .init(name: "--dry-run", required: false, kind: "flag",
                  description: "Print modified YAML to stdout without writing or generating.",
                  defaultValue: "false",
                  example: "--dry-run"),
        ],
        examples: [
            .init(description: "Add a source file to a target",
                  command: "xcodegen patch --operation add-source --target MyApp --path Sources/NewFeature.swift",
                  expectedOutput: "Patched project.yml\nCreated project at MyApp.xcodeproj"),
            .init(description: "Add an SDK dependency",
                  command: "xcodegen patch --operation add-dependency --target MyApp --sdk CoreML.framework",
                  expectedOutput: "Patched project.yml\nCreated project at MyApp.xcodeproj"),
            .init(description: "Set a build setting for Debug config",
                  command: "xcodegen patch --operation set-setting --target MyApp --key SWIFT_VERSION --value 6.0 --config Debug",
                  expectedOutput: "Patched project.yml\nCreated project at MyApp.xcodeproj"),
            .init(description: "Preview YAML changes without applying",
                  command: "xcodegen patch --operation add-source --target MyApp --path Sources/NewFeature.swift --dry-run",
                  expectedOutput: "name: MyApp\n..."),
        ],
        commonErrors: [
            .init(error: #"{"error":"target 'X' not found"}"#,
                  cause: "The --target name does not match any target in the spec.",
                  fix: "Run `xcodegen query --type targets` to list available targets."),
            .init(error: #"{"error":"missing required parameter: --path"}"#,
                  cause: "A required parameter for the chosen operation was not provided.",
                  fix: "Check the parameter list for your --operation and supply the missing value."),
        ],
        relatedCommands: ["generate", "validate", "query"]
    )

    // MARK: - Portuguese (Brazil)

    static let ptBR = CommandGuide(
        command: "patch",
        purpose: "Editar semanticamente o spec do projeto e regenerar o .xcodeproj atomicamente.",
        agentSummary: "Use este comando em vez de editar o YAML do project.yml diretamente. Fornece operações seguras baseadas em intenção (add-source, add-dependency, set-setting) que mutam o spec corretamente e invocam o generate automaticamente. O YAML é reformatado na escrita — comentários e ordem de chaves não são preservados (trade-off documentado, aceitável para uso por agentes).",
        whenToUse: [
            "Quando um agente precisa adicionar um source file a um target sem arriscar corromper o YAML.",
            "Quando adicionar uma dependência SDK ou SPM a um target.",
            "Quando definir um build setting para um target, opcionalmente limitado a uma config específica.",
            "Use --dry-run primeiro para visualizar o YAML modificado antes de aplicar.",
        ],
        workflow: [
            "Carregar o spec e resolver o projeto.",
            "Verificar que o target existe.",
            "Aplicar o patch semântico ao dicionário YAML bruto.",
            "Se --dry-run: imprimir YAML modificado e encerrar.",
            "Escrever YAML modificado no arquivo de spec.",
            "Recarregar spec e executar pipeline de generate.",
        ],
        parameters: [
            .init(name: "--operation", required: true, kind: "key",
                  description: "Operação de patch. Um de: add-source, add-dependency, set-setting.",
                  defaultValue: "nenhum",
                  example: "--operation add-source"),
            .init(name: "--target", required: true, kind: "key",
                  description: "Nome do target a ser patchado.",
                  defaultValue: "nenhum",
                  example: "--target MyApp"),
            .init(name: "--path", required: false, kind: "key",
                  description: "Caminho do source file (para add-source).",
                  defaultValue: "nenhum",
                  example: "--path Sources/NovoArquivo.swift"),
            .init(name: "--sdk", required: false, kind: "key",
                  description: "Nome do framework SDK (para add-dependency).",
                  defaultValue: "nenhum",
                  example: "--sdk CoreML.framework"),
            .init(name: "--key", required: false, kind: "key",
                  description: "Chave do build setting (para set-setting).",
                  defaultValue: "nenhum",
                  example: "--key SWIFT_VERSION"),
            .init(name: "--value", required: false, kind: "key",
                  description: "Valor do build setting (para set-setting).",
                  defaultValue: "nenhum",
                  example: "--value 6.0"),
            .init(name: "--config", required: false, kind: "key",
                  description: "Nome da config para set-setting (omita para settings base).",
                  defaultValue: "settings base",
                  example: "--config Debug"),
            .init(name: "--dry-run", required: false, kind: "flag",
                  description: "Imprime o YAML modificado sem escrever nem gerar.",
                  defaultValue: "false",
                  example: "--dry-run"),
        ],
        examples: [
            .init(description: "Adicionar source file a um target",
                  command: "xcodegen patch --operation add-source --target MyApp --path Sources/NovoArquivo.swift",
                  expectedOutput: "Patched project.yml\nCreated project at MyApp.xcodeproj"),
            .init(description: "Visualizar YAML sem aplicar",
                  command: "xcodegen patch --operation add-source --target MyApp --path Sources/X.swift --dry-run",
                  expectedOutput: "name: MyApp\n..."),
        ],
        commonErrors: [
            .init(error: #"{"error":"target 'X' not found"}"#,
                  cause: "O --target não corresponde a nenhum target no spec.",
                  fix: "Execute `xcodegen query --type targets` para listar os targets disponíveis."),
        ],
        relatedCommands: ["generate", "validate", "query"]
    )

    // MARK: - Spanish

    static let es = CommandGuide(
        command: "patch",
        purpose: "Editar semánticamente el spec del proyecto y regenerar el .xcodeproj atómicamente.",
        agentSummary: "Use este comando en lugar de editar el YAML de project.yml directamente. Proporciona operaciones seguras basadas en intención (add-source, add-dependency, set-setting) que mutan el spec correctamente e invocan generate automáticamente. El YAML se reformatea al escribir — los comentarios y el orden de claves no se preservan (trade-off documentado, aceptable para uso por agentes).",
        whenToUse: [
            "Cuando un agente necesita agregar un archivo fuente a un target sin arriesgar corromper el YAML.",
            "Cuando agregar una dependencia SDK o SPM a un target.",
            "Cuando establecer un build setting para un target, opcionalmente limitado a una config específica.",
            "Use --dry-run primero para previsualizar el YAML modificado antes de aplicar.",
        ],
        workflow: [
            "Cargar el spec y resolver el proyecto.",
            "Verificar que el target existe.",
            "Aplicar el patch semántico al diccionario YAML crudo.",
            "Si --dry-run: imprimir YAML modificado y salir.",
            "Escribir YAML modificado en el archivo de spec.",
            "Recargar spec y ejecutar pipeline de generate.",
        ],
        parameters: [
            .init(name: "--operation", required: true, kind: "key",
                  description: "Operación de patch. Uno de: add-source, add-dependency, set-setting.",
                  defaultValue: "ninguno",
                  example: "--operation add-source"),
            .init(name: "--target", required: true, kind: "key",
                  description: "Nombre del target a parchear.",
                  defaultValue: "ninguno",
                  example: "--target MyApp"),
            .init(name: "--key", required: false, kind: "key",
                  description: "Clave del build setting (para set-setting).",
                  defaultValue: "ninguno",
                  example: "--key SWIFT_VERSION"),
            .init(name: "--value", required: false, kind: "key",
                  description: "Valor del build setting (para set-setting).",
                  defaultValue: "ninguno",
                  example: "--value 6.0"),
            .init(name: "--dry-run", required: false, kind: "flag",
                  description: "Imprime el YAML modificado sin escribir ni generar.",
                  defaultValue: "false",
                  example: "--dry-run"),
        ],
        examples: [
            .init(description: "Agregar archivo fuente a un target",
                  command: "xcodegen patch --operation add-source --target MyApp --path Sources/NuevoArchivo.swift",
                  expectedOutput: "Patched project.yml\nCreated project at MyApp.xcodeproj"),
        ],
        commonErrors: [
            .init(error: #"{"error":"target 'X' not found"}"#,
                  cause: "El --target no coincide con ningún target en el spec.",
                  fix: "Ejecute `xcodegen query --type targets` para listar los targets disponibles."),
        ],
        relatedCommands: ["generate", "validate", "query"]
    )
}
