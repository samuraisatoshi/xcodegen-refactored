import Foundation

enum QueryGuide {
    static func content(locale: GuideLocale) -> CommandGuide {
        switch locale {
        case .en:   return en
        case .ptBR: return ptBR
        case .es:   return es
        }
    }

    // MARK: - English

    static let en = CommandGuide(
        command: "query",
        purpose: "Introspect the resolved project spec and return focused JSON without generating a .xcodeproj.",
        agentSummary: "Use this command when you need specific facts about the project — target list, source files, build settings, or dependencies — without parsing the full dump output. All query types are read-only and produce no side effects.",
        whenToUse: [
            "To list all targets before deciding which one to modify.",
            "To retrieve source files for a target when preparing a patch operation.",
            "To inspect build settings for a specific config before calling generate.",
            "To list dependencies to check whether a framework is already linked.",
        ],
        workflow: [
            "Load and resolve the spec file.",
            "Route to the appropriate query handler based on --type.",
            "Emit focused JSON for the requested data and exit 0.",
        ],
        parameters: [
            .init(name: "--type", required: false, kind: "key",
                  description: "Query type. One of: targets, target, sources, settings, dependencies.",
                  defaultValue: "targets",
                  example: "--type sources"),
            .init(name: "--name", required: false, kind: "key",
                  description: "Target name. Required for: target, sources, settings, dependencies.",
                  defaultValue: "none",
                  example: "--name MyApp"),
            .init(name: "--config", required: false, kind: "key",
                  description: "Config name for settings queries.",
                  defaultValue: "base settings (no config filter)",
                  example: "--config Debug"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Path to the spec file.",
                  defaultValue: "project.yml",
                  example: "--spec path/to/project.yml"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Language for --guide output. One of: en, pt-br, es.",
                  defaultValue: "Detected from LANG environment variable",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "List all targets",
                  command: "xcodegen query --type targets",
                  expectedOutput: #"[{"name":"MyApp","platform":"iOS","type":"com.apple.product-type.application"}]"#),
            .init(description: "Get details for a specific target",
                  command: "xcodegen query --type target --name MyApp",
                  expectedOutput: #"{"dependencies":[],"deployment_target":"18.0","name":"MyApp","platform":"iOS","sources":["Sources/AppDelegate.swift"],"type":"com.apple.product-type.application"}"#),
            .init(description: "List source files for a target",
                  command: "xcodegen query --type sources --name MyApp",
                  expectedOutput: #"["Sources/AppDelegate.swift","Sources/ContentView.swift"]"#),
            .init(description: "Get Debug build settings for a target",
                  command: "xcodegen query --type settings --name MyApp --config Debug",
                  expectedOutput: #"{"SWIFT_VERSION":"5.0"}"#),
        ],
        commonErrors: [
            .init(error: #"{"error":"target 'X' not found"}"#,
                  cause: "The specified --name does not match any target in the spec.",
                  fix: "Run `xcodegen query --type targets` first to list available targets."),
            .init(error: #"{"error":"--name is required for query type 'sources'"}"#,
                  cause: "--name was not provided for a type that requires it.",
                  fix: "Add --name <target-name> to the command."),
        ],
        relatedCommands: ["validate", "dump", "generate"]
    )

    // MARK: - Portuguese (Brazil)

    static let ptBR = CommandGuide(
        command: "query",
        purpose: "Introspectar o spec do projeto resolvido e retornar JSON focado sem gerar o .xcodeproj.",
        agentSummary: "Use este comando quando precisar de fatos específicos sobre o projeto — lista de targets, arquivos fonte, build settings ou dependências — sem parsear o dump completo. Todos os tipos de query são somente leitura e não produzem side effects.",
        whenToUse: [
            "Para listar todos os targets antes de decidir qual modificar.",
            "Para recuperar os source files de um target ao preparar uma operação de patch.",
            "Para inspecionar build settings de uma config específica antes de chamar generate.",
            "Para listar dependências e verificar se um framework já está linkado.",
        ],
        workflow: [
            "Carregar e resolver o arquivo de spec.",
            "Rotear para o handler correto com base em --type.",
            "Emitir JSON focado para os dados solicitados e sair com 0.",
        ],
        parameters: [
            .init(name: "--type", required: false, kind: "key",
                  description: "Tipo de query. Um de: targets, target, sources, settings, dependencies.",
                  defaultValue: "targets",
                  example: "--type sources"),
            .init(name: "--name", required: false, kind: "key",
                  description: "Nome do target. Obrigatório para: target, sources, settings, dependencies.",
                  defaultValue: "nenhum",
                  example: "--name MyApp"),
            .init(name: "--config", required: false, kind: "key",
                  description: "Nome da config para queries de settings.",
                  defaultValue: "settings base (sem filtro de config)",
                  example: "--config Debug"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Caminho para o arquivo de spec.",
                  defaultValue: "project.yml",
                  example: "--spec caminho/para/project.yml"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para a saída do --guide. Um de: en, pt-br, es.",
                  defaultValue: "Detectado da variável de ambiente LANG",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Listar todos os targets",
                  command: "xcodegen query --type targets",
                  expectedOutput: #"[{"name":"MyApp","platform":"iOS","type":"com.apple.product-type.application"}]"#),
            .init(description: "Listar arquivos fonte de um target",
                  command: "xcodegen query --type sources --name MyApp",
                  expectedOutput: #"["Sources/AppDelegate.swift","Sources/ContentView.swift"]"#),
        ],
        commonErrors: [
            .init(error: #"{"error":"target 'X' not found"}"#,
                  cause: "O --name especificado não corresponde a nenhum target no spec.",
                  fix: "Execute `xcodegen query --type targets` para listar os targets disponíveis."),
            .init(error: #"{"error":"--name is required for query type 'sources'"}"#,
                  cause: "--name não foi fornecido para um tipo que o exige.",
                  fix: "Adicione --name <nome-do-target> ao comando."),
        ],
        relatedCommands: ["validate", "dump", "generate"]
    )

    // MARK: - Spanish

    static let es = CommandGuide(
        command: "query",
        purpose: "Introspeccionar el spec del proyecto resuelto y devolver JSON enfocado sin generar el .xcodeproj.",
        agentSummary: "Use este comando cuando necesite datos específicos del proyecto — lista de targets, archivos fuente, build settings o dependencias — sin parsear el dump completo. Todos los tipos de query son de solo lectura y no producen efectos secundarios.",
        whenToUse: [
            "Para listar todos los targets antes de decidir cuál modificar.",
            "Para recuperar los archivos fuente de un target al preparar una operación de patch.",
            "Para inspeccionar build settings de una config específica antes de llamar a generate.",
            "Para listar dependencias y verificar si un framework ya está enlazado.",
        ],
        workflow: [
            "Cargar y resolver el archivo de spec.",
            "Enrutar al handler correcto según --type.",
            "Emitir JSON enfocado para los datos solicitados y salir con 0.",
        ],
        parameters: [
            .init(name: "--type", required: false, kind: "key",
                  description: "Tipo de query. Uno de: targets, target, sources, settings, dependencies.",
                  defaultValue: "targets",
                  example: "--type sources"),
            .init(name: "--name", required: false, kind: "key",
                  description: "Nombre del target. Requerido para: target, sources, settings, dependencies.",
                  defaultValue: "ninguno",
                  example: "--name MyApp"),
            .init(name: "--config", required: false, kind: "key",
                  description: "Nombre de la config para queries de settings.",
                  defaultValue: "settings base (sin filtro de config)",
                  example: "--config Debug"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Ruta al archivo de spec.",
                  defaultValue: "project.yml",
                  example: "--spec ruta/al/project.yml"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para la salida de --guide. Uno de: en, pt-br, es.",
                  defaultValue: "Detectado de la variable de entorno LANG",
                  example: "--lang es"),
        ],
        examples: [
            .init(description: "Listar todos los targets",
                  command: "xcodegen query --type targets",
                  expectedOutput: #"[{"name":"MyApp","platform":"iOS","type":"com.apple.product-type.application"}]"#),
            .init(description: "Listar archivos fuente de un target",
                  command: "xcodegen query --type sources --name MyApp",
                  expectedOutput: #"["Sources/AppDelegate.swift","Sources/ContentView.swift"]"#),
        ],
        commonErrors: [
            .init(error: #"{"error":"target 'X' not found"}"#,
                  cause: "El --name especificado no coincide con ningún target en el spec.",
                  fix: "Ejecute `xcodegen query --type targets` para listar los targets disponibles."),
            .init(error: #"{"error":"--name is required for query type 'sources'"}"#,
                  cause: "--name no fue proporcionado para un tipo que lo requiere.",
                  fix: "Agregue --name <nombre-del-target> al comando."),
        ],
        relatedCommands: ["validate", "dump", "generate"]
    )
}
