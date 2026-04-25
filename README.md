# Laboratório 1 — Teoria da Computação

## Conversão de Autômatos Finitos e Expressões Regulares

> **NFAε → NFA → DFA** via Construção de Subconjuntos e Minimização  
> **Regex → NFAε** via Construção de Thompson

| Campo        | Valor                        |
|--------------|------------------------------|
| Disciplina   | Teoria da Computação         |
| Nível        | Mestrado                     |
| Aluno        | Flavio Miozzi                |
| Contato      | fmiozzi@gmail.com            |
| Linguagem    | Haskell (GHC 9.4)            |
| Ambiente     | Nix Flakes (reproduzível)    |

---

## Sumário

1. [Objetivos](#objetivos)
2. [Estrutura do Projeto](#estrutura-do-projeto)
3. [Pré-requisitos e Ambiente](#pré-requisitos-e-ambiente)
4. [Como Compilar](#como-compilar)
5. [Como Executar](#como-executar)
6. [Formato dos Arquivos YAML](#formato-dos-arquivos-yaml)
7. [Exemplos de Entrada e Saída](#exemplos-de-entrada-e-saída)
8. [Algoritmos Implementados](#algoritmos-implementados)
9. [Operadores de Expressão Regular Suportados](#operadores-de-expressão-regular-suportados)
10. [Estrutura do Código](#estrutura-do-código)

---

## Objetivos

Este laboratório implementa dois módulos de conversão de autômatos finitos:

**Parte 1** (`src/Main.hs`) — Converte um autômato NFAε para DFA em três etapas sequenciais:

1. **Remoção de transições ε** (NFAε → NFA): para cada estado *s* e símbolo *a*, computa δ'(*s*, *a*) = move(ε-closure(*s*), *a*). Estados finais são atualizados para incluir qualquer estado cuja ε-closure contenha um estado final do autômato original.

2. **Construção de subconjuntos** (NFA → DFA): cada estado do DFA representa um conjunto de estados do NFA. A partir do conjunto inicial {*q₀*}, explora-se por BFS todos os conjuntos alcançáveis via move(*S*, *a*).

3. **Minimização do DFA** (algoritmo de refinamento de partições): inicia com a bipartição {*F*, *Q*\*F*} e refina iterativamente até estabilização, fundindo estados com comportamento idêntico.

**Parte 2** (`src/Regex.hs`) — Converte uma Expressão Regular para NFAε pela **Construção de Thompson**, gerando um NFA com exatamente um estado de entrada e um de saída por subexpressão. O resultado é compatível com a pipeline da Parte 1.

---

## Estrutura do Projeto

```
lab1/
├── src/
│   ├── Main.hs             # Parte 1: NFAε → NFA → DFA
│   └── Regex.hs            # Parte 2: Regex → NFAε (Thompson)
├── input/
│   ├── nfae_simple.yaml    # Caso de teste simples  (3 estados, alfabeto {0,1})
│   └── nfae_complex.yaml   # Caso de teste complexo (13 estados, alfabeto {a,b,c})
├── output/                 # Diretório para arquivos de saída gerados
├── flake.nix               # Ambiente Nix reproduzível (GHC 9.4 + Cabal)
├── shell.nix               # Ambiente Nix alternativo (nix-shell)
├── lab1.cabal              # Configuração de build (Cabal 2.4)
├── run.sh                  # Script de execução — Parte 1
├── run2.sh                 # Script de execução — Parte 2 (pipeline completo)
└── tc-lab01.pdf            # Enunciado do laboratório
```

---

## Pré-requisitos e Ambiente

### Via Nix — recomendado (ambiente reproduzível)

O arquivo `flake.nix` define um ambiente fixo com **GHC 9.4** e **Cabal**, garantindo reprodutibilidade total da compilação.

**Pré-requisito único:** [Nix](https://nixos.org/download.html) com suporte a Flakes.

```bash
# Habilitar Nix Flakes (adicionar a /etc/nix/nix.conf ou ~/.config/nix/nix.conf):
experimental-features = nix-command flakes
```

### Via instalação manual

| Ferramenta | Versão mínima |
|------------|---------------|
| GHC        | 9.4           |
| Cabal      | 3.6           |

Pacotes Haskell necessários: `yaml`, `aeson`, `containers`, `bytestring`.

---

## Como Compilar

### Com Nix (recomendado)

```bash
# Entrar no ambiente de desenvolvimento
nix develop

# Compilar ambos os executáveis
cabal build all
```

### Sem Nix (GHC/Cabal instalados manualmente)

```bash
cabal build all
```

> Os binários compilados ficam em `dist-newstyle/`. Os scripts `run.sh` e `run2.sh` invocam `cabal run` diretamente, sem necessidade de localizar o binário manualmente.

---

## Como Executar

### Parte 1 — NFAε → DFA

**Via script:**

```bash
./run.sh [input.yaml] [output.yaml]
```

| Argumento     | Padrão                    | Descrição             |
|---------------|---------------------------|-----------------------|
| `input.yaml`  | `input/nfae_simple.yaml`  | Autômato de entrada   |
| `output.yaml` | `output/result.yaml`      | DFA mínimo de saída   |

**Exemplos:**

```bash
./run.sh                                               # usa arquivos padrão
./run.sh input/nfae_simple.yaml  output/dfa_simple.yaml
./run.sh input/nfae_complex.yaml output/dfa_complex.yaml
```

**Diretamente com Cabal:**

```bash
cabal run lab1 -- input/nfae_simple.yaml output/result.yaml
```

---

### Parte 2 — Expressão Regular → DFA (pipeline completo)

O script `run2.sh` executa a pipeline completa: **Regex → NFAε → NFA → DFA**.

**Via script:**

```bash
./run2.sh "<regex>" [output.yaml]
```

| Argumento     | Padrão               | Descrição           |
|---------------|----------------------|---------------------|
| `<regex>`     | (obrigatório)        | Expressão regular   |
| `output.yaml` | `output/result.yaml` | DFA mínimo de saída |

**Exemplos:**

```bash
./run2.sh "(a|b)*abb"
./run2.sh "a*b+c?"              output/resultado.yaml
./run2.sh "(0|1)*00(0|1)*"      output/dfa_00.yaml
```

**Apenas Thompson (NFAε sem conversão para DFA):**

```bash
cabal run lab1-part2 -- "(a|b)*abb" output/nfae.yaml
```

---

## Formato dos Arquivos YAML

### Entrada

```yaml
type: nfae               # "dfa", "nfa" ou "nfae"
alphabet: ["0", "1"]     # símbolos do alfabeto (sem "epsilon")
states: ["q0", "q1", "q2"]
initial_state: "q0"
final_states: ["q2"]
transitions:
  - from:   "q0"
    symbol: "0"
    to:     ["q0", "q1"]   # lista: suporta NFA (múltiplos destinos)
  - from:   "q0"
    symbol: "epsilon"       # transição ε
    to:     ["q1"]
  - from:   "q1"
    symbol: "1"
    to:     ["q2"]
```

**Campos obrigatórios:**

| Campo           | Tipo   | Descrição                                             |
|-----------------|--------|-------------------------------------------------------|
| `type`          | string | Tipo do autômato: `dfa`, `nfa` ou `nfae`              |
| `alphabet`      | lista  | Símbolos do alfabeto (não inclui `"epsilon"`)         |
| `states`        | lista  | Todos os estados                                      |
| `initial_state` | string | Estado inicial                                        |
| `final_states`  | lista  | Estados finais/aceitadores                            |
| `transitions`   | lista  | Lista de transições (`from`, `symbol`, `to`)          |

> Transições ε são representadas com `symbol: "epsilon"`. O campo `to` é sempre uma lista, mesmo para DFA (lista com um único elemento).

### Saída

O arquivo de saída segue o mesmo formato YAML com `type: dfa`. Os estados são nomeados em notação de conjunto, refletindo a construção de subconjuntos:

```yaml
type: dfa
alphabet: ["0", "1"]
states: ["{q0,q1}", "{q0,q1,q2}", "{q0}"]
initial_state: "{q0}"
final_states: ["{q0,q1,q2}"]
transitions:
  - from:   "{q0}"
    symbol: "0"
    to:     ["{q0,q1}"]
  ...
```

---

## Exemplos de Entrada e Saída

### Exemplo 1 — NFAε simples (3 estados)

**Entrada:** `input/nfae_simple.yaml`

Reconhece cadeias sobre {0, 1} que contêm `"01"` como subcadeia.

```
NFAε:  q0 --[0]--> {q0,q1}
       q0 --[ε]--> q1
       q1 --[1]--> q2  (final)
```

```bash
./run.sh input/nfae_simple.yaml output/dfa_simple.yaml
```

---

### Exemplo 2 — NFAε complexo (13 estados)

**Entrada:** `input/nfae_complex.yaml`

Reconhece cadeias sobre {a, b, c} que iniciam com `"ab"` ou `"cb"`, contêm pelo menos um `"c"` no meio e terminam com `"ba"` ou `"cc"`.

```bash
./run.sh input/nfae_complex.yaml output/dfa_complex.yaml
```

O DFA minimizado resultante possui **8 estados** (reduzido dos 13 originais).

---

### Exemplo 3 — Expressão Regular

```bash
./run2.sh "(a|b)*abb"         # terminadas em "abb" sobre {a,b}
./run2.sh "a*b+"              # zero ou mais 'a' seguido de um ou mais 'b'
./run2.sh "(0|1)*00"          # terminadas em "00" sobre {0,1}
./run2.sh "(a|b|c)?(ab)*"     # prefixo opcional + repetições de "ab"
```

---

## Algoritmos Implementados

### Parte 1 — `src/Main.hs`

#### Etapa 1: ε-closure e Remoção de Transições ε (NFAε → NFA)

A ε-closure de um estado *s* é o conjunto de todos os estados alcançáveis a partir de *s* usando apenas transições ε (incluindo *s* mesmo). Calculada por BFS sobre as transições ε.

Para cada estado *s* ∈ *Q* e símbolo *a* ∈ Σ:

```
δ'(s, a) = ⋃_{q ∈ ε-closure(s)} δ(q, a)
```

Estados finais do NFA resultante:

```
F' = { s ∈ Q  |  ε-closure(s) ∩ F ≠ ∅ }
```

#### Etapa 2: Construção de Subconjuntos (NFA → DFA)

Cada estado do DFA é um subconjunto de estados do NFA. A partir do estado inicial {*q₀*}, computa-se por BFS:

```
move(S, a) = ⋃_{s ∈ S} δ(s, a)
```

O nome de cada estado DFA usa notação de conjunto: `{q0,q1,q2}`. O estado morto (∅) é omitido — transições ausentes implicam rejeição.

Estados finais do DFA:

```
F_DFA = { S ⊆ Q  |  S ∩ F ≠ ∅ }
```

#### Etapa 3: Minimização do DFA (Refinamento de Partições)

Algoritmo baseado em Myhill-Nerode:

1. Partição inicial: {*F*, *Q*\*F*} (estados finais e não-finais).
2. Para cada grupo *G* da partição atual, verifica se todos os estados de *G* transitam para o **mesmo grupo** sob cada símbolo.
3. Se não, divide *G* em subgrupos com comportamento idêntico.
4. Repete até a partição se estabilizar (ponto fixo).

O representante de cada grupo (lexicograficamente menor) torna-se o estado do DFA mínimo.

---

### Parte 2 — `src/Regex.hs`

#### Parser de Expressão Regular

Parser de descida recursiva (recursive descent) com precedência correta de operadores:

| Nível | Construção | Operador         | Precedência |
|-------|-----------|------------------|-------------|
| 1     | `expr`     | `\|` (união)     | Mais baixa  |
| 2     | `term`     | concatenação      | Média       |
| 3     | `factor`   | `*`, `+`, `?`    | Alta        |
| 4     | `atom`     | literal, `(...)`  | Mais alta   |

Resultado intermediário: AST do tipo `Regex` com construtores `RChar`, `REpsilon`, `RConcat`, `RUnion`, `RStar`, `RPlus`, `ROpt`.

#### Construção de Thompson (Regex → NFAε)

Cada subexpressão gera um **fragmento NFA** com exatamente um estado de entrada e um de saída. Estados são identificados por inteiros crescentes (`q0`, `q1`, …).

| Expressão  | Construção Thompson                                                     |
|------------|-------------------------------------------------------------------------|
| `c`        | *n* —[c]→ *n+1*                                                        |
| `ε`        | *n* —[ε]→ *n+1*                                                        |
| `r1 · r2`  | Conecta fim(*r1*) a início(*r2*) por ε                                 |
| `r1 \| r2` | Novo início —ε→ início(*r1*) e início(*r2*); fim(*r1*) e fim(*r2*) —ε→ novo fim |
| `r*`       | Novo início —ε→ início(*r*) e fim; fim(*r*) —ε→ início(*r*) e fim    |
| `r+`       | Equivalente a `r · r*`                                                  |
| `r?`       | Equivalente a `r \| ε`                                                  |

---

## Operadores de Expressão Regular Suportados

| Operador      | Exemplo        | Linguagem reconhecida                  |
|---------------|----------------|----------------------------------------|
| Literal       | `a`            | A string `"a"`                         |
| Concatenação  | `ab`           | A string `"ab"`                        |
| União         | `a\|b`         | `"a"` ou `"b"`                         |
| Kleene        | `a*`           | `""`, `"a"`, `"aa"`, …                 |
| Uma ou mais   | `a+`           | `"a"`, `"aa"`, `"aaa"`, …             |
| Opcional      | `a?`           | `""` ou `"a"`                          |
| Agrupamento   | `(a\|b)*c`     | Zero ou mais {a,b} seguido de `"c"`    |
| Combinado     | `(a\|b)*abb`   | Strings sobre {a,b} terminadas em `"abb"` |

> **Nota:** caracteres especiais (`|`, `*`, `+`, `?`, `(`, `)`) não podem ser usados como literais. Todos os demais caracteres ASCII imprimíveis são tratados como literais.

---

## Estrutura do Código

```
src/Main.hs
├── Tipos base              — State, Symbol, AutomatonType, Transition, Automaton
├── Instâncias JSON/YAML    — FromJSON / ToJSON para leitura e escrita de YAML
├── epsilonClosure          — BFS sobre transições ε
├── removeEpsilon           — NFAε → NFA
├── subsetConstruction      — NFA → DFA (construção de subconjuntos)
├── minimizeDFA             — DFA → DFA mínimo (refinamento de partições)
├── formatAutomaton         — Serializador YAML customizado (formato idêntico ao input)
└── main                    — Lê YAML → aplica pipeline → escreve YAML

src/Regex.hs
├── Tipo Regex (AST)        — RChar, REpsilon, RConcat, RUnion, RStar, RPlus, ROpt
├── Parser                  — parseRegex, parseExpr, parseTerm, parseFactor, parseAtom
├── Construção de Thompson  — build :: Regex → Int → (NFAFrag, Int)
├── Tipos Automaton         — espelho de Main.hs (arquivo independente)
├── collectAlphabet         — extrai símbolos literais da AST
├── groupTransitions        — agrupa transições brutas por (origem, símbolo)
├── fragToAutomaton         — converte NFAFrag para Automaton
└── main                    — lê regex → Thompson → escreve YAML
```
