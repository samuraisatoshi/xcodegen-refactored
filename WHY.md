# WHY — Refactor: SOLID + DDD + Performance + Security

Branch: `refactor/solid-ddd-performance`
Sprint: SP-001 (2026-03-28)
Cards: CD-001 → CD-006 (28 story points)

---

## O que foi feito

Seis mudanças estruturais no codebase do xcodegen, sem alteração de comportamento externo:

| Commit | Card | Mudança |
|--------|------|---------|
| `241a5885` | CD-001 | Cache de `NSRegularExpression` em `SourceGenerator` |
| `9c05eda2` | CD-002 | Decomposição de `PBXProjGenerator.swift` (1724 → 1308L) em 3 extension files |
| `e1eb8d7a` | CD-003 | Protocolo `CarthageResolving` + eliminação de IUO em `SourceGenerator` |
| `601f8b31` | CD-004 | Validação de include path traversal (`validateIncludePaths`) |
| `26df2613` | CD-005 | Decomposição de `SourceGenerator.swift` (923 → 186L) em 3 extension files |
| `ef0d3ee1` | CD-006 | Extração de `Scheme+Codable.swift` de `Scheme.swift` (1095 → 441L) |

### Arquivos antes e depois

```
PBXProjGenerator.swift        1724L → 1308L  (-416)
  + PBXProjGenerator+BuildPhases.swift         80L  (novo)
  + PBXProjGenerator+DependencyHelpers.swift  159L  (novo)
  + PBXProjGenerator+Helpers.swift            199L  (novo)

SourceGenerator.swift          923L →  186L  (-737)
  + SourceGenerator+FileReferences.swift      129L  (novo)
  + SourceGenerator+Groups.swift              176L  (novo)
  + SourceGenerator+SourceFiles.swift         450L  (novo)

Scheme.swift                  1095L →  441L  (-654)
  + Scheme+Codable.swift                      659L  (novo)

CarthageResolving.swift                        12L  (novo — protocolo DIP)
SpecFile.swift                             +10L  (validação de paths)
SpecOptions.swift                           +6L  (opção validateIncludePaths)
SpecValidationError.swift                   +3L  (novo caso de erro)
Tests/SpecLoadingTests.swift               +55L  (teste de regressão)
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
SourceGenerator+FileReferences.swift  → "aqui ficam as refs de arquivos"
SourceGenerator+Groups.swift          → "aqui ficam os grupos Xcode"
SourceGenerator+SourceFiles.swift     → "aqui fica o traversal de sources"
PBXProjGenerator+BuildPhases.swift    → "aqui ficam as build phases"
Scheme+Codable.swift                  → "aqui fica a serialização JSON do Scheme"
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

---

## Benefícios para desenvolvimento com LLM agents

### Contexto menor = respostas melhores

| Tarefa | Contexto antes | Contexto depois |
|--------|---------------|-----------------|
| Modificar criação de grupos Xcode | 923L (SourceGenerator inteiro) | 176L (+186L main) |
| Adicionar build phase | 1724L (PBXProjGenerator inteiro) | 80L (+1308L main) |
| Modificar serialização de Scheme | 1095L | 659L |
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
    Scheme.swift              ← modelo puro
    Scheme+Codable.swift      ← serialização
    SpecFile.swift            ← carregamento + validação de includes
    SpecOptions.swift         ← opções do projeto
    SpecValidationError.swift ← todos os erros de validação

  XcodeGenKit/
    PBXProjGenerator.swift              ← orquestrador principal
    PBXProjGenerator+BuildPhases.swift  ← geração de build phases
    PBXProjGenerator+DependencyHelpers.swift ← helpers de dependência
    PBXProjGenerator+Helpers.swift      ← atributos, ordenação de grupos
    CarthageResolving.swift             ← protocolo DIP
    CarthageDependencyResolver.swift    ← implementação concreta
    SourceGenerator.swift               ← init + geração de source files
    SourceGenerator+FileReferences.swift ← resolução de file refs
    SourceGenerator+Groups.swift        ← criação de grupos Xcode
    SourceGenerator+SourceFiles.swift   ← traversal de sources
```

Um agente pode ler esta estrutura e saber exatamente onde procurar antes de abrir qualquer arquivo.

---

## O que não mudou

- Nenhum comportamento externo foi alterado
- A API pública dos módulos `ProjectSpec` e `XcodeGenKit` é idêntica
- Todos os 75 testes existentes passam
- Compatibilidade retroativa com specs existentes (validateIncludePaths é opt-in)
- Nenhuma dependência nova foi adicionada
