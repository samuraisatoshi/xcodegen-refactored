import Foundation

enum CacheGuide {
    static func content(locale: GuideLocale) -> CommandGuide {
        switch locale {
        case .en:   return en
        case .ptBR: return ptBR
        case .es:   return es
        }
    }

    // MARK: - English

    static let en = CommandGuide(
        command: "cache",
        purpose: "Write the spec hash to the cache file without generating the .xcodeproj.",
        agentSummary: "Use this command to prime or refresh the cache after a known-good generation, so subsequent `generate --use-cache` calls are skipped if the spec has not changed. Agents can call this after confirming the generated project is correct.",
        whenToUse: [
            "After manually verifying a generated project to mark it as cached.",
            "In CI to warm the cache before parallel build jobs that each run `generate --use-cache`.",
            "When an agent wants to persist the current spec hash without triggering a full regeneration.",
        ],
        workflow: [
            "Load and parse the spec file(s).",
            "Compute the spec hash.",
            "Write the hash to the cache file path.",
        ],
        parameters: [
            .init(name: "--cache-path", required: false, kind: "key",
                  description: "Custom path for the cache file.",
                  defaultValue: "~/.xcodegen/cache/{SPEC_HASH}",
                  example: "--cache-path .xcodegen-cache"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Path to the spec file.",
                  defaultValue: "project.yml",
                  example: "--spec path/to/project.yml"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suppress all informational output.",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Language for --guide output. One of: en, pt-br, es.",
                  defaultValue: "Detected from LANG environment variable",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Prime the default cache after a known-good generate",
                  command: "xcodegen cache",
                  expectedOutput: "Wrote cache to ~/.xcodegen/cache/abc123"),
            .init(description: "Use a project-local cache file",
                  command: "xcodegen cache --cache-path .xcodegen-cache",
                  expectedOutput: "Wrote cache to .xcodegen-cache"),
        ],
        commonErrors: [
            .init(error: "No project spec found at /path/project.yml",
                  cause: "Spec file missing.",
                  fix: "Pass --spec with the correct path."),
            .init(error: "Failed to write cache",
                  cause: "Insufficient permissions to write to the cache directory.",
                  fix: "Check permissions on ~/.xcodegen/cache/ or pass --cache-path to a writable location."),
        ],
        relatedCommands: ["generate", "dump"]
    )

    // MARK: - Portuguese (Brazil)

    static let ptBR = CommandGuide(
        command: "cache",
        purpose: "Escrever o hash do spec no arquivo de cache sem gerar o .xcodeproj.",
        agentSummary: "Use este comando para inicializar ou atualizar o cache após uma geração conhecidamente boa, para que chamadas subsequentes de `generate --use-cache` sejam puladas se o spec não tiver mudado. Agentes podem chamar isso após confirmar que o projeto gerado está correto.",
        whenToUse: [
            "Após verificar manualmente um projeto gerado para marcá-lo como cacheado.",
            "Em CI para aquecer o cache antes de jobs de build paralelos que executam `generate --use-cache`.",
            "Quando um agente quer persistir o hash atual do spec sem acionar uma regeneração completa.",
        ],
        workflow: [
            "Carregar e parsear o(s) arquivo(s) de spec.",
            "Computar o hash do spec.",
            "Escrever o hash no caminho do arquivo de cache.",
        ],
        parameters: [
            .init(name: "--cache-path", required: false, kind: "key",
                  description: "Caminho customizado para o arquivo de cache.",
                  defaultValue: "~/.xcodegen/cache/{SPEC_HASH}",
                  example: "--cache-path .xcodegen-cache"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Caminho para o arquivo de spec.",
                  defaultValue: "project.yml",
                  example: "--spec caminho/para/project.yml"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suprime toda saída informacional.",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para a saída do --guide. Um de: en, pt-br, es.",
                  defaultValue: "Detectado da variável de ambiente LANG",
                  example: "--lang pt-br"),
        ],
        examples: [
            .init(description: "Inicializar o cache padrão após um generate bem-sucedido",
                  command: "xcodegen cache",
                  expectedOutput: "Wrote cache to ~/.xcodegen/cache/abc123"),
            .init(description: "Usar um arquivo de cache local do projeto",
                  command: "xcodegen cache --cache-path .xcodegen-cache",
                  expectedOutput: "Wrote cache to .xcodegen-cache"),
        ],
        commonErrors: [
            .init(error: "No project spec found at /caminho/project.yml",
                  cause: "Arquivo de spec ausente.",
                  fix: "Passe --spec com o caminho correto."),
            .init(error: "Failed to write cache",
                  cause: "Permissões insuficientes para escrever no diretório de cache.",
                  fix: "Verifique permissões em ~/.xcodegen/cache/ ou passe --cache-path para um local gravável."),
        ],
        relatedCommands: ["generate", "dump"]
    )

    // MARK: - Spanish

    static let es = CommandGuide(
        command: "cache",
        purpose: "Escribir el hash del spec en el archivo de caché sin generar el .xcodeproj.",
        agentSummary: "Use este comando para inicializar o refrescar la caché después de una generación conocidamente buena, para que las llamadas subsecuentes de `generate --use-cache` se omitan si el spec no ha cambiado. Los agentes pueden llamar a esto después de confirmar que el proyecto generado es correcto.",
        whenToUse: [
            "Después de verificar manualmente un proyecto generado para marcarlo como cacheado.",
            "En CI para calentar la caché antes de jobs de build paralelos que ejecutan `generate --use-cache`.",
            "Cuando un agente quiere persistir el hash actual del spec sin disparar una regeneración completa.",
        ],
        workflow: [
            "Cargar y parsear el/los archivo(s) de spec.",
            "Calcular el hash del spec.",
            "Escribir el hash en la ruta del archivo de caché.",
        ],
        parameters: [
            .init(name: "--cache-path", required: false, kind: "key",
                  description: "Ruta personalizada para el archivo de caché.",
                  defaultValue: "~/.xcodegen/cache/{SPEC_HASH}",
                  example: "--cache-path .xcodegen-cache"),
            .init(name: "--spec", required: false, kind: "key",
                  description: "Ruta al archivo de spec.",
                  defaultValue: "project.yml",
                  example: "--spec ruta/al/project.yml"),
            .init(name: "--quiet", required: false, kind: "flag",
                  description: "Suprime toda la salida informacional.",
                  defaultValue: "false",
                  example: "--quiet"),
            .init(name: "--lang", required: false, kind: "key",
                  description: "Idioma para la salida de --guide. Uno de: en, pt-br, es.",
                  defaultValue: "Detectado de la variable de entorno LANG",
                  example: "--lang es"),
        ],
        examples: [
            .init(description: "Inicializar la caché predeterminada después de un generate exitoso",
                  command: "xcodegen cache",
                  expectedOutput: "Wrote cache to ~/.xcodegen/cache/abc123"),
            .init(description: "Usar un archivo de caché local del proyecto",
                  command: "xcodegen cache --cache-path .xcodegen-cache",
                  expectedOutput: "Wrote cache to .xcodegen-cache"),
        ],
        commonErrors: [
            .init(error: "No project spec found at /ruta/project.yml",
                  cause: "Archivo de spec ausente.",
                  fix: "Pase --spec con la ruta correcta."),
            .init(error: "Failed to write cache",
                  cause: "Permisos insuficientes para escribir en el directorio de caché.",
                  fix: "Verifique los permisos en ~/.xcodegen/cache/ o pase --cache-path a una ubicación con escritura."),
        ],
        relatedCommands: ["generate", "dump"]
    )
}
