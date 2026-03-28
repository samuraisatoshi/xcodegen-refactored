import Foundation

enum InferGuide {
    static func content(locale: GuideLocale) -> CommandGuide {
        switch locale {
        case .en:   return en
        case .ptBR: return ptBR
        case .es:   return es
        }
    }

    // MARK: - English

    static let en = CommandGuide(
        command: "infer",
        purpose: "Read an existing .xcodeproj and generate an equivalent project.yml.",
        agentSummary: "Use this command to bootstrap a project.yml from a legacy .xcodeproj — the entry point for migrating an existing project to xcodegen. Produces a correct partial spec (fidelity over completeness). Constructs with no direct equivalent emit entries in `warnings`. Round-trip parity is not guaranteed — validate with `xcodegen validate` after inferring.",
        whenToUse: [
            "When onboarding an existing Xcode project to xcodegen management.",
            "When an agent needs a starting project.yml without manual authoring.",
            "As the first step of the infer → edit → generate → validate cycle.",
            "Use --dry-run to preview the generated YAML before writing.",
        ],
        workflow: [
            "Locate the .xcodeproj (current directory or --xcodeproj path).",
            "Parse the pbxproj with XcodeProj library.",
            "For each native target: infer type, platform, deployment target, sources, dependencies, significant build settings.",
            "Emit warnings for unsupported constructs instead of failing.",
            "If --dry-run: print YAML to stdout and exit.",
            "Write project.yml (or --output path).",
        ],
        parameters: [
            .init(name: "--xcodeproj", required: false, kind: "key",
                  description: "Path to the .xcodeproj to read. Defaults to the first .xcodeproj found in the current directory.",
                  defaultValue: "auto-detected",
                  example: "--xcodeproj path/to/App.xcodeproj"),
            .init(name: "--output", required: false, kind: "key",
                  description: "Destination path for the generated project.yml.",
                  defaultValue: "project.yml in the .xcodeproj directory",
                  example: "--output path/to/project.yml"),
            .init(name: "--dry-run", required: false, kind: "flag",
                  description: "Print the inferred YAML to stdout without writing.",
                  defaultValue: "false",
                  example: "--dry-run"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Language for --guide output. One of: en, pt-br, es.",
                  defaultValue: "Detected from LANG environment variable",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Infer project.yml from the default .xcodeproj",
                  command: "xcodegen infer",
                  expectedOutput: "Inferred project.yml from App.xcodeproj\n2 warnings"),
            .init(description: "Dry-run to preview YAML",
                  command: "xcodegen infer --dry-run",
                  expectedOutput: "name: App\ntargets:\n  App:\n    type: application\n    platform: iOS\n    ..."),
            .init(description: "Custom xcodeproj path and output location",
                  command: "xcodegen infer --xcodeproj ios/App.xcodeproj --output ios/project.yml",
                  expectedOutput: "Inferred project.yml from App.xcodeproj"),
        ],
        commonErrors: [
            .init(error: #"{"error":"no .xcodeproj found in current directory"}"#,
                  cause: "No .xcodeproj exists in the current directory and --xcodeproj was not provided.",
                  fix: "Run from the project directory or pass --xcodeproj with an explicit path."),
            .init(error: #"{"error":"failed to read .xcodeproj: ..."}"#,
                  cause: "The .xcodeproj is corrupted or uses an unsupported format.",
                  fix: "Open the project in Xcode to repair it, then retry."),
        ],
        relatedCommands: ["generate", "validate", "patch", "query"]
    )

    // MARK: - Portuguese (Brazil)

    static let ptBR = CommandGuide(
        command: "infer",
        purpose: "Ler um .xcodeproj existente e gerar um project.yml equivalente.",
        agentSummary: "Use este comando para fazer bootstrap de um project.yml a partir de um .xcodeproj legado — o ponto de entrada para migrar um projeto existente para o xcodegen. Produz um spec parcial correto (fidelidade sobre cobertura total). Construções sem equivalente direto emitem entradas em `warnings`. Paridade de round-trip não é garantida — valide com `xcodegen validate` após inferir.",
        whenToUse: [
            "Ao integrar um projeto Xcode existente ao gerenciamento pelo xcodegen.",
            "Quando um agente precisa de um project.yml inicial sem autoria manual.",
            "Como primeiro passo do ciclo infer → editar → generate → validate.",
            "Use --dry-run para visualizar o YAML gerado antes de escrever.",
        ],
        workflow: [
            "Localizar o .xcodeproj (diretório atual ou path via --xcodeproj).",
            "Parsear o pbxproj com a biblioteca XcodeProj.",
            "Para cada native target: inferir tipo, plataforma, deployment target, sources, dependências, build settings significativos.",
            "Emitir warnings para construções não suportadas em vez de falhar.",
            "Se --dry-run: imprimir YAML no stdout e encerrar.",
            "Escrever project.yml (ou path via --output).",
        ],
        parameters: [
            .init(name: "--xcodeproj", required: false, kind: "key",
                  description: "Caminho para o .xcodeproj a ler. Padrão: primeiro .xcodeproj encontrado no diretório atual.",
                  defaultValue: "auto-detectado",
                  example: "--xcodeproj caminho/para/App.xcodeproj"),
            .init(name: "--output", required: false, kind: "key",
                  description: "Caminho de destino para o project.yml gerado.",
                  defaultValue: "project.yml no diretório do .xcodeproj",
                  example: "--output caminho/para/project.yml"),
            .init(name: "--dry-run", required: false, kind: "flag",
                  description: "Imprime o YAML inferido no stdout sem escrever.",
                  defaultValue: "false",
                  example: "--dry-run"),
        ],
        examples: [
            .init(description: "Inferir project.yml do .xcodeproj padrão",
                  command: "xcodegen infer",
                  expectedOutput: "Inferred project.yml from App.xcodeproj\n2 warnings"),
            .init(description: "Dry-run para visualizar YAML",
                  command: "xcodegen infer --dry-run",
                  expectedOutput: "name: App\ntargets:\n  App:\n    type: application\n    platform: iOS\n    ..."),
        ],
        commonErrors: [
            .init(error: #"{"error":"no .xcodeproj found in current directory"}"#,
                  cause: "Nenhum .xcodeproj existe no diretório atual e --xcodeproj não foi fornecido.",
                  fix: "Execute a partir do diretório do projeto ou passe --xcodeproj com um path explícito."),
        ],
        relatedCommands: ["generate", "validate", "patch", "query"]
    )

    // MARK: - Spanish

    static let es = CommandGuide(
        command: "infer",
        purpose: "Leer un .xcodeproj existente y generar un project.yml equivalente.",
        agentSummary: "Use este comando para hacer bootstrap de un project.yml desde un .xcodeproj legacy — el punto de entrada para migrar un proyecto existente a xcodegen. Produce un spec parcial correcto (fidelidad sobre cobertura total). Las construcciones sin equivalente directo emiten entradas en `warnings`. La paridad de round-trip no está garantizada — valide con `xcodegen validate` después de inferir.",
        whenToUse: [
            "Al integrar un proyecto Xcode existente a la gestión por xcodegen.",
            "Cuando un agente necesita un project.yml inicial sin autoría manual.",
            "Como primer paso del ciclo infer → editar → generate → validate.",
            "Use --dry-run para previsualizar el YAML generado antes de escribir.",
        ],
        workflow: [
            "Localizar el .xcodeproj (directorio actual o path via --xcodeproj).",
            "Parsear el pbxproj con la librería XcodeProj.",
            "Para cada native target: inferir tipo, plataforma, deployment target, fuentes, dependencias, build settings significativos.",
            "Emitir warnings para construcciones no soportadas en lugar de fallar.",
            "Si --dry-run: imprimir YAML en stdout y salir.",
            "Escribir project.yml (o path via --output).",
        ],
        parameters: [
            .init(name: "--xcodeproj", required: false, kind: "key",
                  description: "Ruta al .xcodeproj a leer. Por defecto: primer .xcodeproj encontrado en el directorio actual.",
                  defaultValue: "auto-detectado",
                  example: "--xcodeproj ruta/al/App.xcodeproj"),
            .init(name: "--output", required: false, kind: "key",
                  description: "Ruta de destino para el project.yml generado.",
                  defaultValue: "project.yml en el directorio del .xcodeproj",
                  example: "--output ruta/al/project.yml"),
            .init(name: "--dry-run", required: false, kind: "flag",
                  description: "Imprime el YAML inferido en stdout sin escribir.",
                  defaultValue: "false",
                  example: "--dry-run"),
        ],
        examples: [
            .init(description: "Inferir project.yml del .xcodeproj predeterminado",
                  command: "xcodegen infer",
                  expectedOutput: "Inferred project.yml from App.xcodeproj\n2 warnings"),
        ],
        commonErrors: [
            .init(error: #"{"error":"no .xcodeproj found in current directory"}"#,
                  cause: "No existe ningún .xcodeproj en el directorio actual y no se proporcionó --xcodeproj.",
                  fix: "Ejecute desde el directorio del proyecto o pase --xcodeproj con una ruta explícita."),
        ],
        relatedCommands: ["generate", "validate", "patch", "query"]
    )
}
