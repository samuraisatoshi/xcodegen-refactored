# WHY — Refactored Fork of XcodeGen v2.45.3

Branch: `master` (samuraisatoshi/xcodegen-refactored)
Sprint: SP-001 (2026-03-28)
Cards: CD-001 → CD-009 + EP-002

---

## O que foi feito

Dois blocos de melhoria em cima do upstream **v2.45.3**, sem breaking changes:

### EP-001 — SOLID / DDD / Performance / Security (CD-001 → CD-009)

| Card | Mudança |
|------|---------|
| CD-001 | Cache de `NSRegularExpression` em `SourceGenerator` |
| CD-002 | Decomposição de `PBXProjGenerator.swift` (1724 → 97L) em 8 extension files |
| CD-003 | Protocolo `CarthageResolving` + eliminação de IUO em `SourceGenerator` |
| CD-004 | Validação de include path traversal (`validateIncludePaths`) |
| CD-005 | Decomposição de `SourceGenerator.swift` (923 → 186L) em 3 extension files |
| CD-006 | Extração de `Scheme+Codable.swift` de `Scheme.swift` (1095 → 441L) |
| CD-007–009 | Decomposição final: `+ProjectSetup`, `+TargetGeneration`, `+TargetDependencies` |

### EP-002 — Novos comandos e output flags

| Adição | Descrição |
|--------|-----------|
| `xcodegen validate` | Valida o spec sem gerar projeto; saída JSON estruturada |
| `xcodegen query` | Consulta targets, sources, settings ou dependências como JSON |
| `xcodegen generate --dry-run` | Diff do projeto em memória sem escrever arquivos |
| `xcodegen watch` | Regenera automaticamente ao detectar mudanças no spec |
| `xcodegen patch` | Edita o spec semanticamente e regenera de forma atômica |
| `xcodegen infer` | Gera `project.yml` a partir de um `.xcodeproj` existente |
| `--llm-output` | Saída em formato TOON (~40% menos tokens que JSON) |
| `--enriched-output` | Saída rica com box-drawing chars, ícones e tabelas alinhadas |
| `--guide [--lang]` | JSON de documentação estruturada para MCP servers e agents |

---

## Arquivos antes e depois

```
PBXProjGenerator.swift              1724L →   97L  (-1627)
  + PBXProjGenerator+BuildPhases.swift          80L  (novo)
  + PBXProjGenerator+DependencyHelpers.swift   159L  (novo)
  + PBXProjGenerator+Helpers.swift             199L  (novo)
  + PBXProjGenerator+ProjectSetup.swift        194L  (novo)
  + PBXProjGenerator+TargetContext.swift        28L  (novo)
  + PBXProjGenerator+TargetDependencies.swift  453L  (novo)
  + PBXProjGenerator+TargetGeneration.swift    393L  (novo)
  + PBXProjGenerator+TargetHelpers.swift       103L  (novo)

SourceGenerator.swift                923L →  186L  (-737)
  + SourceGenerator+FileReferences.swift       129L  (novo)
  + SourceGenerator+Groups.swift               176L  (novo)
  + SourceGenerator+SourceFiles.swift          450L  (novo)

Scheme.swift                        1095L →  441L  (-654)
  + Scheme+Codable.swift                       659L  (novo)

CarthageResolving.swift                         12L  (novo — protocolo DIP)
SpecFile.swift                               +10L   (validação de paths)
SpecOptions.swift                             +6L   (opção validateIncludePaths)
SpecValidationError.swift                     +3L   (novo caso de erro)

TOONEncoder.swift                              179L  (novo)
RichFormatter.swift                            180L  (novo)
ValidateCommand.swift                          129L  (novo)
QueryCommand.swift                             234L  (novo)
WatchCommand.swift                             151L  (novo)
PatchCommand.swift                             176L  (novo)
InferCommand.swift                             130L  (novo)
ProjectDiff.swift                               77L  (novo)
ProjectCommand.swift                        +34L   (flags llmOutput, enrichedOutput, guide, lang)
GenerateCommand.swift                        +22L   (--dry-run flag + outputFormat switch)

Tests/XcodeGenKitTests/TOONEncoderTests.swift  134L  (19 testes novos)
Total de testes: 75 → 110 (0 falhas)
```

---

## Por que foi feito

### 1. Arquivos god-class dificultam trabalho com LLM agents

Os três arquivos principais tinham entre 923 e 1724 linhas. Quando um agente LLM precisa entender ou modificar uma funcionalidade, ele lê o arquivo inteiro — ou perde contexto ao ler por partes. Arquivos grandes:

- Consomem tokens desnecessariamente (leitura de código irrelevante para a tarefa)
- Aumentam a probabilidade de alucinação (o modelo precisa "segurar" mais contexto)
- Dificultam edições cirúrgicas (o agente pode quebrar código não relacionado)
- Tornam o diff de revisão ininteligível

Após o refactor, cada arquivo tem uma única responsabilidade clara. Um agente que precisa modificar como grupos Xcode são criados lê `SourceGenerator+Groups.swift` (176L), não um arquivo de 923 linhas.

### 2. SRP como interface de descoberta

A convenção de nomes `Tipo+Responsabilidade.swift` é legível tanto por humanos quanto por LLMs sem precisar ler o código:

```
SourceGenerator+FileReferences.swift    → "aqui ficam as refs de arquivos"
SourceGenerator+Groups.swift            → "aqui ficam os grupos Xcode"
SourceGenerator+SourceFiles.swift       → "aqui fica o traversal de sources"
PBXProjGenerator+BuildPhases.swift      → "aqui ficam as build phases"
PBXProjGenerator+ProjectSetup.swift     → "aqui fica o setup inicial do projeto"
PBXProjGenerator+TargetGeneration.swift → "aqui fica a geração de targets"
PBXProjGenerator+TargetDependencies.swift → "aqui ficam as dependências entre targets"
Scheme+Codable.swift                    → "aqui fica a serialização JSON do Scheme"
```

Um agente pode fazer `glob("**/*.swift")` e inferir onde procurar antes de ler qualquer linha.

### 3. Inversão de dependência (CD-003) permite substituição e teste

`PBXProjGenerator` dependia diretamente de `CarthageDependencyResolver` (classe concreta). Agora depende de `CarthageResolving` (protocolo):

```swift
// antes
let carthageResolver: CarthageDependencyResolver

// depois
let carthageResolver: CarthageResolving
```

Benefícios:
- Testes podem injetar um mock sem subclassear nada
- A implementação de Carthage pode ser substituída sem modificar `PBXProjGenerator`
- Agentes LLM podem gerar implementações alternativas sem entender toda a classe geradora

A eliminação do Implicitly Unwrapped Optional (`var sourceGenerator: SourceGenerator!` → `let sourceGenerator: SourceGenerator`) remove uma fonte de crashes silenciosos e torna o fluxo de inicialização explícito no código.

### 4. Segurança: path traversal em includes (CD-004)

`SpecFile` aceitava include paths arbitrários, incluindo `../../etc/passwd` ou qualquer path fora do diretório do projeto. Em pipelines CI/CD, variáveis de ambiente são frequentemente injetadas no ambiente de build — um include malicioso poderia exfiltrar essas variáveis para o `.xcodeproj` gerado (que é commitado no repositório).

A correção:
```yaml
# project.yml
options:
  validateIncludePaths: true  # default: false (compatibilidade retroativa)

include:
  - ../../outside/secrets.yml  # ← lança SpecValidationError
```

O opt-in via `validateIncludePaths: false` (default) garante que projetos existentes não quebrem.

### 5. Performance: regex compilada uma vez (CD-001)

`makeDestinationFilters` compilava a mesma `NSRegularExpression` em cada chamada — potencialmente milhares de vezes num projeto com muitos sources. A expressão é determinística (baseada em `SupportedDestination.allCases`), então compilar uma vez por processo é correto:

```swift
// antes: compilava por chamada
let regex = try? NSRegularExpression(pattern: "\/\(destination)\/", ...)

// depois: cache estático compilado na inicialização do tipo
private static let destinationRegexCache: [SupportedDestination: (...)] = ...
```

### 6. Novos comandos para CI/CD e LLM tooling (EP-002)

O upstream tem apenas `generate`, `dump` e `cache`. Os novos comandos adicionam:

**`validate`** — separar validação de geração é fundamental para pipelines CI que querem falhar rápido:
```bash
xcodegen validate --spec project.yml
# { "valid": true, "errors": [], "warnings": [] }
```

**`generate --dry-run`** — permite revisar o que mudaria antes de commitar:
```bash
xcodegen generate --dry-run
# { "added": ["ABC123"], "modified": ["DEF456"], "removed": [] }
```

**`query`** — introspect o projeto como dados estruturados, sem parsear o `.xcodeproj`:
```bash
xcodegen query --type targets --llm-output
# targets[3]{name,type,platform}:
#   MyApp,application,iOS
#   MyTests,bundle.unit-test,iOS
```

**`--llm-output` (TOON)** — o formato JSON padrão repete chaves em cada linha de um array de objetos. TOON elimina essa repetição:
```
# JSON: 120 tokens
[{"name":"MyApp","type":"application"},{"name":"MyTests","type":"bundle.unit-test"}]

# TOON: ~70 tokens
targets[2]{name,type}:
  MyApp,application
  MyTests,bundle.unit-test
```

**`--enriched-output`** — saída visual moderna para uso humano interativo, sem scripts de formatação externos.

---

## Benefícios para desenvolvimento com LLM agents

### Contexto menor = respostas melhores

| Tarefa | Contexto antes | Contexto depois |
|--------|----------------|-----------------|
| Modificar criação de grupos Xcode | 923L (SourceGenerator inteiro) | 176L (+186L main) |
| Adicionar build phase | 1724L (PBXProjGenerator inteiro) | 80L (+97L main) |
| Modificar serialização de Scheme | 1095L | 659L |
| Modificar geração de targets | 1724L | 393L (+97L main) |
| Implementar Carthage alternativo | toda a classe geradora | protocolo de 12L |

### Menor chance de edição destrutiva

Arquivos menores com escopo claro reduzem o risco de um agente editar código não relacionado durante um patch. A superfície de colisão por tarefa é proporcional ao tamanho do arquivo.

### Testabilidade via DIP

O protocolo `CarthageResolving` permite que agentes escrevam testes de `PBXProjGenerator` sem dependência do sistema de arquivos ou do binário `carthage`:

```swift
struct MockCarthageResolver: CarthageResolving {
    var buildPath: String = "Carthage/Build"
    var executable: String = "carthage"
    func buildPath(for platform: Platform, linkType: Dependency.CarthageLinkType) -> String { buildPath }
    func dependencies(for topLevelTarget: Target) -> [ResolvedCarthageDependency] { [] }
    func relatedDependencies(for dependency: Dependency, in platform: Platform) -> [Dependency] { [] }
}
```

### Descoberta estrutural sem leitura de código

```
Sources/
  ProjectSpec/
    Scheme.swift                  ← modelo puro
    Scheme+Codable.swift          ← serialização
    SpecFile.swift                ← carregamento + validação de includes
    SpecOptions.swift             ← opções do projeto
    SpecValidationError.swift     ← todos os erros de validação

  XcodeGenKit/
    PBXProjGenerator.swift                    ← orquestrador (38L de lógica real)
    PBXProjGenerator+BuildPhases.swift        ← geração de build phases
    PBXProjGenerator+DependencyHelpers.swift  ← helpers de dependência
    PBXProjGenerator+Helpers.swift            ← atributos, ordenação de grupos
    PBXProjGenerator+ProjectSetup.swift       ← setup inicial: stubs, packages, grupos
    PBXProjGenerator+TargetContext.swift      ← contexto de geração por target
    PBXProjGenerator+TargetDependencies.swift ← dependências entre targets
    PBXProjGenerator+TargetGeneration.swift   ← geração completa de target
    PBXProjGenerator+TargetHelpers.swift      ← helpers internos de target
    CarthageResolving.swift                   ← protocolo DIP
    CarthageDependencyResolver.swift          ← implementação concreta
    SourceGenerator.swift                     ← init + geração de source files
    SourceGenerator+FileReferences.swift      ← resolução de file refs
    SourceGenerator+Groups.swift              ← criação de grupos Xcode
    SourceGenerator+SourceFiles.swift         ← traversal de sources
    TOONEncoder.swift                         ← encoder TOON para --llm-output
    ProjectDiff.swift                         ← diff de pbxproj para --dry-run

  XcodeGenCLI/
    Commands/ProjectCommand.swift    ← base: flags globais, outputFormat
    Commands/GenerateCommand.swift   ← generate (+ --dry-run)
    Commands/ValidateCommand.swift   ← validate
    Commands/QueryCommand.swift      ← query
    Commands/WatchCommand.swift      ← watch
    Commands/PatchCommand.swift      ← patch
    Commands/InferCommand.swift      ← infer
    RichFormatter.swift              ← box/tabela para --enriched-output
```

Um agente pode ler esta estrutura e saber exatamente onde procurar antes de abrir qualquer arquivo.

---

## O que não mudou

- Nenhum comportamento externo foi alterado
- A API pública dos módulos `ProjectSpec` e `XcodeGenKit` é idêntica ao upstream
- Todos os 110 testes passam (75 upstream + 35 novos)
- Compatibilidade retroativa com specs existentes (`validateIncludePaths` é opt-in)
- Nenhuma dependência nova foi adicionada
