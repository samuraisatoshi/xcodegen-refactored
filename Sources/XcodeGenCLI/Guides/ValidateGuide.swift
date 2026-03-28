import Foundation

enum ValidateGuide {
    static func content(locale: GuideLocale) -> CommandGuide {
        switch locale {
        case .en:   return en
        case .ptBR: return ptBR
        case .es:   return es
        }
    }

    // MARK: - English

    static let en = CommandGuide(
        command: "validate",
        purpose: "Validate the project spec without generating a .xcodeproj.",
        agentSummary: "Use this command to verify that project.yml is correct before running generate. Returns structured JSON with separate error and warning arrays and a boolean valid flag. Safe to call in a tight loop — reads only, never writes to disk.",
        whenToUse: [
            "After editing project.yml to confirm the spec is valid before invoking generate.",
            "In CI as a fast pre-check before the full generation step.",
            "When an agent makes iterative edits to the spec and needs per-edit feedback without side effects.",
        ],
        workflow: [
            "Load and parse the spec file(s).",
            "Collect warnings from validateProjectDictionaryWarnings().",
            "Run full spec validation (targets, schemes, configs, packages).",
            "Emit JSON result and exit 0 (valid) or 1 (errors present).",
        ],
        parameters: [
            .init(name: "--spec", required: false, kind: "key",
                  description: "Path to the spec file. Comma-separate multiple paths.",
                  defaultValue: "project.yml",
                  example: "--spec path/to/project.yml"),
            .init(name: "--project-root", required: false, kind: "key",
                  description: "Override the project root directory.",
                  defaultValue: "Directory containing the spec file",
                  example: "--project-root /path/to/root"),
            .init(name: "--no-env", required: false, kind: "flag",
                  description: "Disable environment variable expansion in the spec.",
                  defaultValue: "false",
                  example: "--no-env"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suppress all output (JSON is still emitted).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Language for --guide output. One of: en, pt-br, es.",
                  defaultValue: "Detected from LANG environment variable",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Validate the default spec",
                  command: "xcodegen validate",
                  expectedOutput: #"{"errors":[],"valid":true,"warnings":[]}"#),
            .init(description: "Validate and check for an invalid target dependency",
                  command: "xcodegen validate --spec project.yml",
                  expectedOutput: #"{"errors":[{"message":"Target 'Tests' has invalid dependency 'App'","stage":"validation"}],"valid":false,"warnings":[]}"#),
        ],
        commonErrors: [
            .init(error: #"{"errors":[{"message":"No project spec found at ...","stage":"parsing"}],"valid":false,"warnings":[]}"#,
                  cause: "Spec file does not exist at the given path.",
                  fix: "Pass --spec with the correct path."),
            .init(error: #"{"errors":[{"message":"...","stage":"parsing"}],"valid":false,"warnings":[]}"#,
                  cause: "YAML syntax error or unresolvable include.",
                  fix: "Check the YAML structure and any included files."),
        ],
        relatedCommands: ["generate", "dump", "cache"]
    )

    // MARK: - Portuguese (Brazil)

    static let ptBR = CommandGuide(
        command: "validate",
        purpose: "Validar o spec do projeto sem gerar o .xcodeproj.",
        agentSummary: "Use este comando para verificar se o project.yml está correto antes de executar o generate. Retorna JSON estruturado com arrays separados de erros e warnings e um campo booleano valid. Seguro para chamar em loop — apenas lê, nunca escreve no disco.",
        whenToUse: [
            "Após editar o project.yml para confirmar que o spec é válido antes de invocar o generate.",
            "Em CI como pré-verificação rápida antes da etapa completa de geração.",
            "Quando um agente faz edições iterativas no spec e precisa de feedback por edição sem side effects.",
        ],
        workflow: [
            "Carregar e parsear o(s) arquivo(s) de spec.",
            "Coletar warnings do validateProjectDictionaryWarnings().",
            "Executar validação completa do spec (targets, schemes, configs, packages).",
            "Emitir resultado JSON e sair com 0 (válido) ou 1 (erros presentes).",
        ],
        parameters: [
            .init(name: "--spec", required: false, kind: "key",
                  description: "Caminho para o arquivo de spec. Separe múltiplos com vírgula.",
                  defaultValue: "project.yml",
                  example: "--spec caminho/para/project.yml"),
            .init(name: "--project-root", required: false, kind: "key",
                  description: "Sobrescreve o diretório raiz do projeto.",
                  defaultValue: "Diretório que contém o arquivo de spec",
                  example: "--project-root /caminho/para/raiz"),
            .init(name: "--no-env", required: false, kind: "flag",
                  description: "Desabilita expansão de variáveis de ambiente no spec.",
                  defaultValue: "false",
                  example: "--no-env"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suprime toda saída (o JSON ainda é emitido).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para a saída do --guide. Um de: en, pt-br, es.",
                  defaultValue: "Detectado da variável de ambiente LANG",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Validar o spec padrão",
                  command: "xcodegen validate",
                  expectedOutput: #"{"errors":[],"valid":true,"warnings":[]}"#),
            .init(description: "Validar e detectar dependência de target inválida",
                  command: "xcodegen validate --spec project.yml",
                  expectedOutput: #"{"errors":[{"message":"Target 'Tests' has invalid dependency 'App'","stage":"validation"}],"valid":false,"warnings":[]}"#),
        ],
        commonErrors: [
            .init(error: #"{"errors":[{"message":"No project spec found at ...","stage":"parsing"}],"valid":false,"warnings":[]}"#,
                  cause: "Arquivo de spec não existe no caminho informado.",
                  fix: "Passe --spec com o caminho correto."),
            .init(error: #"{"errors":[{"message":"...","stage":"parsing"}],"valid":false,"warnings":[]}"#,
                  cause: "Erro de sintaxe YAML ou include não resolvível.",
                  fix: "Verifique a estrutura YAML e os arquivos incluídos."),
        ],
        relatedCommands: ["generate", "dump", "cache"]
    )

    // MARK: - Spanish

    static let es = CommandGuide(
        command: "validate",
        purpose: "Validar el spec del proyecto sin generar el .xcodeproj.",
        agentSummary: "Use este comando para verificar que el project.yml es correcto antes de ejecutar generate. Devuelve JSON estructurado con arrays separados de errores y warnings y un campo booleano valid. Seguro para llamar en un bucle ajustado — solo lee, nunca escribe en disco.",
        whenToUse: [
            "Después de editar el project.yml para confirmar que el spec es válido antes de invocar generate.",
            "En CI como verificación previa rápida antes del paso completo de generación.",
            "Cuando un agente hace ediciones iterativas al spec y necesita retroalimentación por edición sin efectos secundarios.",
        ],
        workflow: [
            "Cargar y parsear el/los archivo(s) de spec.",
            "Recopilar warnings de validateProjectDictionaryWarnings().",
            "Ejecutar validación completa del spec (targets, schemes, configs, packages).",
            "Emitir resultado JSON y salir con 0 (válido) o 1 (errores presentes).",
        ],
        parameters: [
            .init(name: "--spec", required: false, kind: "key",
                  description: "Ruta al archivo de spec. Separe múltiples con coma.",
                  defaultValue: "project.yml",
                  example: "--spec ruta/al/project.yml"),
            .init(name: "--project-root", required: false, kind: "key",
                  description: "Sobreescribe el directorio raíz del proyecto.",
                  defaultValue: "Directorio que contiene el archivo de spec",
                  example: "--project-root /ruta/a/raiz"),
            .init(name: "--no-env", required: false, kind: "flag",
                  description: "Deshabilita la expansión de variables de entorno en el spec.",
                  defaultValue: "false",
                  example: "--no-env"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suprime toda la salida (el JSON se emite igual).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para la salida de --guide. Uno de: en, pt-br, es.",
                  defaultValue: "Detectado de la variable de entorno LANG",
                  example: "--lang es"),
        ],
        examples: [
            .init(description: "Validar el spec predeterminado",
                  command: "xcodegen validate",
                  expectedOutput: #"{"errors":[],"valid":true,"warnings":[]}"#),
            .init(description: "Validar y detectar dependencia de target inválida",
                  command: "xcodegen validate --spec project.yml",
                  expectedOutput: #"{"errors":[{"message":"Target 'Tests' has invalid dependency 'App'","stage":"validation"}],"valid":false,"warnings":[]}"#),
        ],
        commonErrors: [
            .init(error: #"{"errors":[{"message":"No project spec found at ...","stage":"parsing"}],"valid":false,"warnings":[]}"#,
                  cause: "El archivo de spec no existe en la ruta indicada.",
                  fix: "Pase --spec con la ruta correcta."),
            .init(error: #"{"errors":[{"message":"...","stage":"parsing"}],"valid":false,"warnings":[]}"#,
                  cause: "Error de sintaxis YAML o include no resolvible.",
                  fix: "Verifique la estructura YAML y los archivos incluidos."),
        ],
        relatedCommands: ["generate", "dump", "cache"]
    )
}
