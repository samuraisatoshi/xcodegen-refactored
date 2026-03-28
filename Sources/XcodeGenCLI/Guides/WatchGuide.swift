import Foundation

enum WatchGuide {
    static func content(locale: GuideLocale) -> CommandGuide {
        switch locale {
        case .en:   return en
        case .ptBR: return ptBR
        case .es:   return es
        }
    }

    // MARK: - English

    static let en = CommandGuide(
        command: "watch",
        purpose: "Regenerate the .xcodeproj automatically whenever project.yml is saved.",
        agentSummary: "Use this command for interactive local development sessions where the spec changes frequently. Runs an initial generation, then watches the spec file(s) with a 300ms debounce and regenerates on every save. Errors are printed inline and watching continues — the process never exits on a bad spec. Stop with Ctrl+C.",
        whenToUse: [
            "During active development when you expect to edit project.yml multiple times.",
            "When an agent is making iterative edits to the spec and you want Xcode to stay in sync.",
            "As a background process in a split terminal alongside your editor.",
        ],
        workflow: [
            "Run an initial generation.",
            "Open file descriptors on spec file(s) via DispatchSource.",
            "On each write/rename/delete event, debounce 300ms then regenerate.",
            "Print timestamp and result after each regeneration.",
            "Ctrl+C cancels all watchers and exits cleanly.",
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
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suppress informational output (errors still print).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Language for --guide output. One of: en, pt-br, es.",
                  defaultValue: "Detected from LANG environment variable",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Watch the default spec",
                  command: "xcodegen watch",
                  expectedOutput: "👁  Watching project.yml — Ctrl+C to stop\n[2026-03-28T20:00:00Z] Regenerating...\n✓ MyApp.xcodeproj"),
            .init(description: "Watch a custom spec path",
                  command: "xcodegen watch --spec configs/project.yml",
                  expectedOutput: "👁  Watching project.yml — Ctrl+C to stop"),
        ],
        commonErrors: [
            .init(error: "No project spec found at /path/project.yml",
                  cause: "Spec file does not exist when the command starts.",
                  fix: "Ensure project.yml exists before running watch."),
            .init(error: "Validation error: ...",
                  cause: "The spec became invalid after an edit.",
                  fix: "Fix the YAML error — the watcher will retry on the next save."),
        ],
        relatedCommands: ["generate", "validate", "query"]
    )

    // MARK: - Portuguese (Brazil)

    static let ptBR = CommandGuide(
        command: "watch",
        purpose: "Regenerar o .xcodeproj automaticamente sempre que o project.yml for salvo.",
        agentSummary: "Use este comando em sessões de desenvolvimento local onde o spec muda frequentemente. Executa uma geração inicial, depois monitora o(s) arquivo(s) de spec com debounce de 300ms e regenera a cada salvamento. Erros são impressos inline e o monitoramento continua — o processo nunca encerra por spec inválido. Pare com Ctrl+C.",
        whenToUse: [
            "Durante desenvolvimento ativo quando você espera editar o project.yml múltiplas vezes.",
            "Quando um agente está fazendo edições iterativas no spec e você quer que o Xcode fique sincronizado.",
            "Como processo em background em um terminal dividido ao lado do seu editor.",
        ],
        workflow: [
            "Executa uma geração inicial.",
            "Abre file descriptors no(s) arquivo(s) de spec via DispatchSource.",
            "A cada evento de escrita/rename/delete, debounce de 300ms e então regenera.",
            "Imprime timestamp e resultado após cada regeneração.",
            "Ctrl+C cancela todos os watchers e encerra limpo.",
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
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suprime saída informacional (erros ainda são impressos).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para a saída do --guide. Um de: en, pt-br, es.",
                  defaultValue: "Detectado da variável de ambiente LANG",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Monitorar o spec padrão",
                  command: "xcodegen watch",
                  expectedOutput: "👁  Watching project.yml — Ctrl+C to stop\n[2026-03-28T20:00:00Z] Regenerating...\n✓ MyApp.xcodeproj"),
        ],
        commonErrors: [
            .init(error: "No project spec found at /caminho/project.yml",
                  cause: "Arquivo de spec não existe quando o comando inicia.",
                  fix: "Certifique-se de que project.yml existe antes de executar watch."),
            .init(error: "Validation error: ...",
                  cause: "O spec se tornou inválido após uma edição.",
                  fix: "Corrija o erro no YAML — o watcher tentará novamente no próximo salvamento."),
        ],
        relatedCommands: ["generate", "validate", "query"]
    )

    // MARK: - Spanish

    static let es = CommandGuide(
        command: "watch",
        purpose: "Regenerar el .xcodeproj automáticamente cada vez que se guarda el project.yml.",
        agentSummary: "Use este comando en sesiones de desarrollo local donde el spec cambia frecuentemente. Ejecuta una generación inicial, luego monitorea el/los archivo(s) de spec con un debounce de 300ms y regenera en cada guardado. Los errores se imprimen inline y el monitoreo continúa — el proceso nunca termina por un spec inválido. Detenga con Ctrl+C.",
        whenToUse: [
            "Durante el desarrollo activo cuando espera editar project.yml múltiples veces.",
            "Cuando un agente está haciendo ediciones iterativas al spec y quiere que Xcode permanezca sincronizado.",
            "Como proceso en segundo plano en una terminal dividida junto a su editor.",
        ],
        workflow: [
            "Ejecuta una generación inicial.",
            "Abre file descriptors en el/los archivo(s) de spec via DispatchSource.",
            "En cada evento de escritura/rename/delete, debounce de 300ms y luego regenera.",
            "Imprime timestamp y resultado después de cada regeneración.",
            "Ctrl+C cancela todos los watchers y sale limpiamente.",
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
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suprime la salida informacional (los errores aún se imprimen).",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para la salida de --guide. Uno de: en, pt-br, es.",
                  defaultValue: "Detectado de la variable de entorno LANG",
                  example: "--lang es"),
        ],
        examples: [
            .init(description: "Monitorear el spec predeterminado",
                  command: "xcodegen watch",
                  expectedOutput: "👁  Watching project.yml — Ctrl+C to stop\n[2026-03-28T20:00:00Z] Regenerating...\n✓ MyApp.xcodeproj"),
        ],
        commonErrors: [
            .init(error: "No project spec found at /ruta/project.yml",
                  cause: "El archivo de spec no existe cuando el comando inicia.",
                  fix: "Asegúrese de que project.yml existe antes de ejecutar watch."),
            .init(error: "Validation error: ...",
                  cause: "El spec se volvió inválido después de una edición.",
                  fix: "Corrija el error en el YAML — el watcher reintentará en el próximo guardado."),
        ],
        relatedCommands: ["generate", "validate", "query"]
    )
}
