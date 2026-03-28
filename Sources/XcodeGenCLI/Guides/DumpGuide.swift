import Foundation

enum DumpGuide {
    static func content(locale: GuideLocale) -> CommandGuide {
        switch locale {
        case .en:   return en
        case .ptBR: return ptBR
        case .es:   return es
        }
    }

    // MARK: - English

    static let en = CommandGuide(
        command: "dump",
        purpose: "Print the resolved project spec to stdout or a file without generating the .xcodeproj.",
        agentSummary: "Use this command to inspect the fully resolved spec (after includes, templates, and env-var expansion) before generating the project. Ideal for agents that need to read the current target list, build settings, or scheme configuration without writing any files.",
        whenToUse: [
            "To verify that spec merging, templates, or env-var expansion resolved correctly.",
            "When an agent needs the current project structure in JSON for programmatic processing.",
            "To compare spec state before and after an edit.",
            "As a lightweight alternative to generate when the goal is introspection only.",
        ],
        workflow: [
            "Load and parse the spec file(s) (same as generate).",
            "Optionally re-encode via Swift model (parsed-json / parsed-yaml types).",
            "Print to stdout or write to --file.",
        ],
        parameters: [
            .init(name: "--type", required: false, kind: "key",
                  description: "Output format. Options: yaml (default), json, parsed-yaml, parsed-json, swift-dump, summary.",
                  defaultValue: "yaml",
                  example: "--type json"),
            .init(name: "--file", required: false, kind: "key",
                  description: "Write output to this file path instead of stdout.",
                  defaultValue: nil,
                  example: "--file /tmp/spec-dump.json"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Path to the spec file.",
                  defaultValue: "project.yml",
                  example: "--spec path/to/project.yml"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suppress informational output (the dump itself is still printed).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Language for --guide output. One of: en, pt-br, es.",
                  defaultValue: "Detected from LANG environment variable",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Print spec as JSON for agent consumption",
                  command: "xcodegen dump --type json",
                  expectedOutput: "{ \"name\": \"MyApp\", \"targets\": { ... } }"),
            .init(description: "Get a quick human-readable summary",
                  command: "xcodegen dump --type summary",
                  expectedOutput: "Name: MyApp\nTargets:\n  MyApp: iOS application"),
            .init(description: "Save fully-parsed spec to file",
                  command: "xcodegen dump --type parsed-json --file /tmp/resolved.json",
                  expectedOutput: nil),
        ],
        commonErrors: [
            .init(error: "No project spec found at /path/project.yml",
                  cause: "Spec file missing.",
                  fix: "Pass --spec with the correct path or run from the directory containing project.yml."),
        ],
        relatedCommands: ["generate", "cache"]
    )

    // MARK: - Portuguese (Brazil)

    static let ptBR = CommandGuide(
        command: "dump",
        purpose: "Imprimir o spec do projeto resolvido no stdout ou em um arquivo sem gerar o .xcodeproj.",
        agentSummary: "Use este comando para inspecionar o spec completamente resolvido (após includes, templates e expansão de variáveis de ambiente) antes de gerar o projeto. Ideal para agentes que precisam ler a lista atual de targets, build settings ou configuração de scheme sem escrever nenhum arquivo.",
        whenToUse: [
            "Para verificar que a mesclagem de specs, templates ou expansão de variáveis de ambiente resolveu corretamente.",
            "Quando um agente precisa da estrutura atual do projeto em JSON para processamento programático.",
            "Para comparar o estado do spec antes e depois de uma edição.",
            "Como alternativa leve ao generate quando o objetivo é apenas introspecção.",
        ],
        workflow: [
            "Carregar e parsear o(s) arquivo(s) de spec (igual ao generate).",
            "Opcionalmente re-encodar via modelo Swift (tipos parsed-json / parsed-yaml).",
            "Imprimir no stdout ou escrever em --file.",
        ],
        parameters: [
            .init(name: "--type", required: false, kind: "key",
                  description: "Formato de saída. Opções: yaml (padrão), json, parsed-yaml, parsed-json, swift-dump, summary.",
                  defaultValue: "yaml",
                  example: "--type json"),
            .init(name: "--file", required: false, kind: "key",
                  description: "Escreve a saída neste caminho de arquivo em vez do stdout.",
                  defaultValue: nil,
                  example: "--file /tmp/spec-dump.json"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Caminho para o arquivo de spec.",
                  defaultValue: "project.yml",
                  example: "--spec caminho/para/project.yml"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suprime saída informacional (o dump em si ainda é impresso).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para a saída do --guide. Um de: en, pt-br, es.",
                  defaultValue: "Detectado da variável de ambiente LANG",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Imprimir spec como JSON para consumo por agente",
                  command: "xcodegen dump --type json",
                  expectedOutput: "{ \"name\": \"MeuApp\", \"targets\": { ... } }"),
            .init(description: "Obter resumo rápido legível por humanos",
                  command: "xcodegen dump --type summary",
                  expectedOutput: "Name: MeuApp\nTargets:\n  MeuApp: iOS application"),
        ],
        commonErrors: [
            .init(error: "No project spec found at /caminho/project.yml",
                  cause: "Arquivo de spec ausente.",
                  fix: "Passe --spec com o caminho correto ou execute a partir do diretório que contém o project.yml."),
        ],
        relatedCommands: ["generate", "cache"]
    )

    // MARK: - Spanish

    static let es = CommandGuide(
        command: "dump",
        purpose: "Imprimir el spec del proyecto resuelto en stdout o en un archivo sin generar el .xcodeproj.",
        agentSummary: "Use este comando para inspeccionar el spec completamente resuelto (después de includes, templates y expansión de variables de entorno) antes de generar el proyecto. Ideal para agentes que necesitan leer la lista actual de targets, build settings o configuración de schemes sin escribir ningún archivo.",
        whenToUse: [
            "Para verificar que la combinación de specs, templates o expansión de variables de entorno se resolvió correctamente.",
            "Cuando un agente necesita la estructura actual del proyecto en JSON para procesamiento programático.",
            "Para comparar el estado del spec antes y después de una edición.",
            "Como alternativa ligera a generate cuando el objetivo es solo introspección.",
        ],
        workflow: [
            "Cargar y parsear el/los archivo(s) de spec (igual que generate).",
            "Opcionalmente re-encodar via modelo Swift (tipos parsed-json / parsed-yaml).",
            "Imprimir en stdout o escribir en --file.",
        ],
        parameters: [
            .init(name: "--type", required: false, kind: "key",
                  description: "Formato de salida. Opciones: yaml (predeterminado), json, parsed-yaml, parsed-json, swift-dump, summary.",
                  defaultValue: "yaml",
                  example: "--type json"),
            .init(name: "--file", required: false, kind: "key",
                  description: "Escribe la salida en esta ruta de archivo en lugar de stdout.",
                  defaultValue: nil,
                  example: "--file /tmp/spec-dump.json"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Ruta al archivo de spec.",
                  defaultValue: "project.yml",
                  example: "--spec ruta/al/project.yml"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suprime la salida informacional (el dump en sí sigue imprimiéndose).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para la salida de --guide. Uno de: en, pt-br, es.",
                  defaultValue: "Detectado de la variable de entorno LANG",
                  example: "--lang es"),
        ],
        examples: [
            .init(description: "Imprimir spec como JSON para consumo por agente",
                  command: "xcodegen dump --type json",
                  expectedOutput: "{ \"name\": \"MiApp\", \"targets\": { ... } }"),
            .init(description: "Obtener un resumen rápido legible por humanos",
                  command: "xcodegen dump --type summary",
                  expectedOutput: "Name: MiApp\nTargets:\n  MiApp: iOS application"),
        ],
        commonErrors: [
            .init(error: "No project spec found at /ruta/project.yml",
                  cause: "Archivo de spec ausente.",
                  fix: "Pase --spec con la ruta correcta o ejecute desde el directorio que contiene project.yml."),
        ],
        relatedCommands: ["generate", "cache"]
    )
}
