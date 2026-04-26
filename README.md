# Laboratório 1 — Teoria da Computação

**Mestrado Profissional em Computação Aplicada — IFES**

> Implementação em Haskell de algoritmos clássicos de teoria dos autômatos:
> conversão **NFAε → NFA → DFA mínimo** e conversão **Expressão Regular → NFAε**
> pela Construção de Thompson.

| Campo      | Valor                                          |
|------------|------------------------------------------------|
| Disciplina | Teoria da Computação                           |
| Professor  | Prof. Jefferson Oliveira Andrade               |
| Aluno      | Flávio Miozzi Batista                          |
| Linguagem  | Haskell (GHC 9.4)                              |
| Ambiente   | Nix Flakes — reprodutível em qualquer máquina  |

---

## Sumário

1. [Visão Geral](#1-visão-geral)
2. [Estrutura do Repositório](#2-estrutura-do-repositório)
3. [Pré-requisitos](#3-pré-requisitos)
4. [Clonando o Repositório](#4-clonando-o-repositório)
5. [Ativando o Ambiente](#5-ativando-o-ambiente)
6. [Compilando o Projeto](#6-compilando-o-projeto)
7. [Executando — Parte 1: NFAε → DFA](#7-executando--parte-1-nfaε--dfa)
8. [Executando — Parte 2: Regex → DFA](#8-executando--parte-2-regex--dfa)
9. [Gerando o Relatório PDF](#9-gerando-o-relatório-pdf)
10. [Formato dos Arquivos YAML](#10-formato-dos-arquivos-yaml)
11. [Algoritmos Implementados](#11-algoritmos-implementados)
12. [Operadores de Expressão Regular Suportados](#12-operadores-de-expressão-regular-suportados)

---

## 1. Visão Geral

O laboratório é dividido em duas partes:

**Parte 1 — `src/Main.hs`**

Lê um autômato descrito em YAML (NFAε, NFA ou DFA) e aplica o pipeline:

```
NFAε  ──[remoção de ε]──►  NFA  ──[subconjuntos]──►  DFA  ──[Hopcroft]──►  DFA mínimo
```

**Parte 2 — `src/Regex.hs`**

Lê uma expressão regular em texto e aplica a **Construção de Thompson** para gerar um NFAε. O resultado é compatível com a Parte 1, permitindo encadear os dois programas:

```
Regex  ──[Thompson]──►  NFAε  ──[Parte 1]──►  DFA mínimo
```

Ambos os módulos leem e escrevem arquivos **YAML** com formato padronizado.

---

## 2. Estrutura do Repositório

```
lab1/
│
├── src/
│   ├── Main.hs              # Parte 1: NFAε/NFA/DFA → DFA mínimo
│   └── Regex.hs             # Parte 2: Regex → NFAε (Thompson)
│
├── Files/
│   ├── NFAe/                # Autômatos NFAε de entrada (exemplos prontos)
│   │   ├── nfae_simple.yaml
│   │   ├── nfae_02.yaml     # L = {a,b}
│   │   ├── nfae_04.yaml     # L = {ab}
│   │   ├── nfae_06.yaml     # L = (a|b)*
│   │   ├── nfae_08.yaml     # L = (0|1)*01
│   │   ├── nfae_10.yaml     # Exemplo complexo com 13 estados
│   │   └── nfae_complex.yaml
│   ├── NFA/                 # Saída: NFA após remoção de ε  (gerado automaticamente)
│   ├── DFA/                 # Saída: DFA mínimo             (gerado automaticamente)
│   ├── REGEX/               # Expressões regulares de entrada (uma por arquivo)
│   │   ├── regex_1.txt      # ab*
│   │   ├── regex_2.txt      # a*b+
│   │   ├── regex_3.txt      # (a|b)*abb
│   │   ├── regex_4.txt      # a?
│   │   └── regex_5.txt      # (a|b)*c(a+b|ba?)*
│   ├── REGEX_NFA/           # Saída: NFAε gerado por Thompson (gerado automaticamente)
│   └── REGEX_DFA/           # Saída: DFA mínimo da regex    (gerado automaticamente)
│
├── Exec/
│   ├── NFAe_to_DFA.sh       # Converte um único arquivo NFAε/NFA/DFA
│   ├── dfa_batch.sh         # Converte em lote todos os arquivos de Files/NFAe/
│   ├── rgx_to_dfa.sh        # Converte uma regex para DFA (pipeline completo)
│   └── regex_batch.sh       # Converte em lote todos os arquivos de Files/REGEX/
│
├── doc_pdf/
│   ├── lab1.tex             # Relatório do laboratório (LaTeX/abntex2)
│   ├── pdf.sh               # Compilação do PDF (silencioso, 3 passadas)
│   ├── ifes8.cls            # Classe LaTeX IFES (fornecida pela instituição)
│   └── img/                 # Imagens do relatório
│
├── output/                  # Saída padrão para conversões individuais
│   ├── NFA/
│   ├── DFA/
│   ├── REGEX_NFA/
│   └── REGEX_DFA/
│
├── flake.nix                # Ambiente Nix reproduzível (GHC 9.4 + Cabal + LaTeX)
├── shell.nix                # Alternativa: nix-shell clássico
└── lab1.cabal               # Configuração de build Cabal
```

---

## 3. Pré-requisitos

### Opção A — Nix (recomendada)

O arquivo `flake.nix` define um ambiente fixo com **GHC 9.4**, **Cabal** e **LaTeX/abntex2**. Qualquer máquina com Nix reproduz o ambiente exato, sem instalar dependências manualmente.

**Requisito único:** [Nix](https://nixos.org/download.html) com suporte a Flakes habilitado.

Para habilitar Flakes, adicione ao arquivo `~/.config/nix/nix.conf` (criando-o se necessário):

```
experimental-features = nix-command flakes
```

### Opção B — Instalação manual

| Ferramenta | Versão mínima |
|------------|---------------|
| GHC        | 9.4.x         |
| Cabal      | 3.6           |

Pacotes Haskell necessários (instalados automaticamente pelo Cabal na primeira compilação):

```
yaml  ·  aeson  ·  bytestring  ·  containers
```

Para gerar o PDF também é necessária uma distribuição LaTeX com `abntex2`, `tikz` e `booktabs`.

---

## 4. Clonando o Repositório

```bash
git clone <URL-do-repositório>
cd lab1
```

Após clonar, a estrutura de diretórios de saída já existe no repositório. Nenhum passo adicional de configuração é necessário antes de compilar.

---

## 5. Ativando o Ambiente

### Com Nix (recomendado)

```bash
nix develop
```

Este comando baixa o GHC, o Cabal e o LaTeX na versão exata definida em `flake.nix` e abre um shell de desenvolvimento. Na primeira execução pode demorar vários minutos (download dos pacotes Nix). Nas execuções seguintes é imediato.

O prompt indica que o ambiente está ativo:

```
Ambiente Haskell + LaTeX/abntex2 carregado
```

> Os scripts em `Exec/` e `doc_pdf/pdf.sh` ativam o ambiente automaticamente via
> `nix develop --command` — não é necessário rodar `nix develop` manualmente
> antes de usá-los.

---

## 6. Compilando o Projeto

```bash
# Dentro do shell Nix (após nix develop), ou com GHC/Cabal instalados manualmente:
cabal build all
```

Isso compila dois executáveis:

| Executável   | Fonte          | Função                         |
|--------------|----------------|--------------------------------|
| `lab1`       | `src/Main.hs`  | NFAε/NFA/DFA → DFA mínimo      |
| `lab1-part2` | `src/Regex.hs` | Regex → NFAε (Thompson)        |

Os binários ficam em `dist-newstyle/` e são invocados pelos scripts via `cabal run`, sem necessidade de localizar o caminho manualmente.

---

## 7. Executando — Parte 1: NFAε → DFA

### 7.1 Converter um único arquivo

```bash
./Exec/NFAe_to_DFA.sh <input.yaml> [output_nfa.yaml] [output_dfa.yaml]
```

| Argumento         | Padrão                               | Descrição                              |
|-------------------|--------------------------------------|----------------------------------------|
| `input.yaml`      | (obrigatório)                        | Autômato de entrada (NFAε, NFA ou DFA) |
| `output_nfa.yaml` | `output/NFA/<nome-do-arquivo>`       | NFA após remoção de ε                  |
| `output_dfa.yaml` | `output/DFA/<nome-do-arquivo>`       | DFA mínimo                             |

**Exemplos:**

```bash
# Usando os exemplos prontos (saída em output/NFA/ e output/DFA/)
./Exec/NFAe_to_DFA.sh Files/NFAe/nfae_simple.yaml
./Exec/NFAe_to_DFA.sh Files/NFAe/nfae_08.yaml

# Especificando destinos
./Exec/NFAe_to_DFA.sh Files/NFAe/nfae_10.yaml output/NFA/ex10.yaml output/DFA/ex10.yaml
```

**Saída no terminal:**

```
📥 Input      : Files/NFAe/nfae_simple.yaml
📤 Output NFA : output/NFA/nfae_simple.yaml
📤 Output DFA : output/DFA/nfae_simple.yaml
```

### 7.2 Converter todos os exemplos em lote

```bash
./Exec/dfa_batch.sh [diretório_entrada]
```

| Argumento            | Padrão        | Descrição                             |
|----------------------|---------------|---------------------------------------|
| `diretório_entrada`  | `Files/NFAe/` | Diretório com os arquivos YAML        |

```bash
# Processa todos os arquivos de Files/NFAe/ → Files/NFA/ e Files/DFA/
./Exec/dfa_batch.sh

# Processa um diretório alternativo
./Exec/dfa_batch.sh outro_diretorio/
```

**Saída no terminal:**

```
📂 Entrada : Files/NFAe/  (7 arquivo(s))
📤 NFA     : Files/NFA
📤 DFA     : Files/DFA

📥 nfae_simple.yaml
   ✅ NFA → Files/NFA/nfae_simple.yaml
   ✅ DFA → Files/DFA/nfae_simple.yaml
...
Concluído — 7 arquivo(s) processado(s), 0 erro(s)
```

### 7.3 Invocação direta via Cabal

```bash
cabal run lab1 -- <input.yaml> <output_nfa.yaml> <output_dfa.yaml>
```

```bash
cabal run lab1 -- Files/NFAe/nfae_simple.yaml output/NFA/result.yaml output/DFA/result.yaml
```

---

## 8. Executando — Parte 2: Regex → DFA

### 8.1 Converter uma expressão regular (pipeline completo)

```bash
./Exec/rgx_to_dfa.sh "<regex>" [output_nfa.yaml] [output_dfa.yaml]
```

| Argumento         | Padrão                          | Descrição                     |
|-------------------|---------------------------------|-------------------------------|
| `<regex>`         | (obrigatório)                   | Expressão regular entre aspas |
| `output_nfa.yaml` | `output/REGEX_NFA/result.yaml`  | NFA resultante                |
| `output_dfa.yaml` | `output/REGEX_DFA/result.yaml`  | DFA mínimo resultante         |

**Exemplos:**

```bash
./Exec/rgx_to_dfa.sh "(a|b)*abb"
./Exec/rgx_to_dfa.sh "a*b+"
./Exec/rgx_to_dfa.sh "(0|1)*01"
./Exec/rgx_to_dfa.sh "a?" output/REGEX_NFA/a_opt.yaml output/REGEX_DFA/a_opt.yaml
```

**Saída no terminal:**

```
🔤 Regex      : (a|b)*abb
📤 Output NFA : output/REGEX_NFA/result.yaml
📤 Output DFA : output/REGEX_DFA/result.yaml
```

Internamente, o script executa:

```
"(a|b)*abb"  →  [lab1-part2/Thompson]  →  NFAε (temp)  →  [lab1]  →  NFA + DFA mínimo
```

### 8.2 Converter todos os arquivos de regex em lote

Os arquivos em `Files/REGEX/` contêm cada um uma expressão regular na primeira linha.

```bash
./Exec/regex_batch.sh [diretório_entrada]
```

| Argumento            | Padrão          | Descrição                                |
|----------------------|-----------------|------------------------------------------|
| `diretório_entrada`  | `Files/REGEX/`  | Diretório com arquivos de regex (`.txt`) |

```bash
# Processa Files/REGEX/ → Files/REGEX_NFA/ e Files/REGEX_DFA/
./Exec/regex_batch.sh
```

**Saída no terminal:**

```
📂 Entrada : Files/REGEX/  (5 arquivo(s))
📤 NFA     : Files/REGEX_NFA
📤 DFA     : Files/REGEX_DFA

🔤 regex_1.txt : ab*
   ✅ NFA → Files/REGEX_NFA/regex_1.yaml
   ✅ DFA → Files/REGEX_DFA/regex_1.yaml
...
Concluído — 5 arquivo(s) processado(s), 0 erro(s)
```

### 8.3 Gerar apenas o NFAε (Thompson, sem converter para DFA)

```bash
cabal run lab1-part2 -- "<regex>" <output_nfae.yaml>
```

```bash
cabal run lab1-part2 -- "(a|b)*abb" output/nfae_thompson.yaml
```

---

## 9. Gerando o Relatório PDF

O relatório está em `doc_pdf/lab1.tex` (LaTeX com classe `ifes8`/abntex2, normas ABNT). O script `pdf.sh` compila silenciosamente em três passadas e exibe apenas avisos reais ao final.

```bash
./doc_pdf/pdf.sh
```

**Saída esperada (compilação limpa):**

```
📄 Compilando lab1.tex → lab1.pdf

✅ PDF gerado sem avisos: doc_pdf/lab1.pdf
```

O PDF gerado fica em `doc_pdf/lab1.pdf`. O script requer o ambiente Nix (ativado automaticamente via `nix develop --command`).

---

## 10. Formato dos Arquivos YAML

### 10.1 Autômato de entrada

```yaml
type: nfae               # Tipo: "dfa", "nfa" ou "nfae"
alphabet: ["0", "1"]     # Símbolos do alfabeto — strings entre aspas
states: ["q0", "q1", "q2"]
initial_state: "q0"
final_states: ["q2"]
transitions:
  - from:   "q0"
    symbol: "0"
    to:     ["q0", "q1"]   # Lista — suporta múltiplos destinos (NFA)
  - from:   "q0"
    symbol: "epsilon"       # Transição ε
    to:     ["q1"]
  - from:   "q1"
    symbol: "1"
    to:     ["q2"]
```

**Regras obrigatórias:**

- Todos os valores de string devem estar entre **aspas duplas**: `"q0"`, `"0"`, `"epsilon"`.
- O campo `to` é **sempre uma lista**, mesmo para DFA (lista com um único elemento: `["q1"]`).
- Transições ε usam `symbol: "epsilon"` (literal string).
- Transições ausentes implicam rejeição (estado morto implícito).

### 10.2 Autômato de saída (DFA mínimo)

O arquivo de saída usa `type: dfa`. Os nomes dos estados refletem a construção de subconjuntos:

```yaml
type: dfa
alphabet: ["0", "1"]
states: ["{q0}", "{q0,q1}", "{q0,q1,q2}"]
initial_state: "{q0}"
final_states: ["{q0,q1,q2}"]
transitions:
  - from:   "{q0}"
    symbol: "0"
    to:     ["{q0,q1}"]
  - from:   "{q0}"
    symbol: "1"
    to:     ["{q0}"]
  - from:   "{q0,q1}"
    symbol: "1"
    to:     ["{q0,q1,q2}"]
  ...
```

### 10.3 Arquivo de expressão regular

Arquivo de texto com a expressão regular na **primeira linha**:

```
(a|b)*abb
```

---

## 11. Algoritmos Implementados

### 11.1 ε-closure e Remoção de ε-transições (NFAε → NFA)

A **ε-closure** de um estado *s* é o conjunto de todos os estados alcançáveis
exclusivamente por transições ε, incluindo o próprio *s*. É calculada por BFS.

A função de transição do NFA resultante é:

```
δ'(s, a) = ⋃_{q ∈ ε-closure(s)} δ(q, a)      ∀ s ∈ Q, a ∈ Σ
```

Os estados finais são atualizados para incluir todo estado cuja ε-closure intercepte *F*:

```
F' = { s ∈ Q  |  ε-closure(s) ∩ F ≠ ∅ }
```

### 11.2 Construção de Subconjuntos (NFA → DFA)

Cada estado do DFA corresponde a um subconjunto de estados do NFA.
A construção parte de `{q₀}` e expande por BFS:

```
move(S, a) = ⋃_{s ∈ S} δ(s, a)      ∀ S ⊆ Q, a ∈ Σ
```

```
F_DFA = { S ⊆ Q  |  S ∩ F ≠ ∅ }
```

### 11.3 Minimização do DFA (Refinamento de Partições)

1. **Partição inicial:** `{ F, Q \ F }`.
2. **Refinamento:** para cada grupo *G* e símbolo *a*, verifica se todos os estados
   de *G* transitam para o **mesmo grupo** sob *a*.
3. Grupos com comportamento distinto são divididos.
4. Repete até atingir **ponto fixo**.

O representante lexicograficamente menor de cada grupo torna-se o estado do DFA mínimo.

### 11.4 Construção de Thompson (Regex → NFAε)

Parser de descida recursiva com precedências:

| Nível | Regra    | Operador       |
|-------|----------|----------------|
| 1     | `expr`   | `\|` (união)   |
| 2     | `term`   | concatenação   |
| 3     | `factor` | `*`, `+`, `?`  |
| 4     | `atom`   | literal, `(…)` |

Cada subexpressão produz um fragmento NFA com exatamente um estado de entrada e um de saída:

| Expressão   | Construção                                                                          |
|-------------|-------------------------------------------------------------------------------------|
| `c`         | *n* —[c]→ *n+1*                                                                    |
| `r₁ · r₂`  | fim(*r₁*) —[ε]→ início(*r₂*)                                                      |
| `r₁ \| r₂` | novo início —ε→ {início(*r₁*), início(*r₂*)}; fins —ε→ novo fim                   |
| `r*`        | novo início —ε→ {início(*r*), fim}; fim(*r*) —ε→ {início(*r*), fim}               |
| `r+`        | equivalente a `r · r*`                                                              |
| `r?`        | equivalente a `r \| ε`                                                              |

---

## 12. Operadores de Expressão Regular Suportados

| Operador     | Sintaxe      | Exemplo       | Linguagem reconhecida                       |
|--------------|--------------|---------------|---------------------------------------------|
| Literal      | `c`          | `a`           | A string `"a"`                              |
| Concatenação | justaposição | `ab`          | A string `"ab"`                             |
| União        | `\|`         | `a\|b`        | `"a"` ou `"b"`                              |
| Kleene       | `*`          | `a*`          | `""`, `"a"`, `"aa"`, …                     |
| Uma ou mais  | `+`          | `a+`          | `"a"`, `"aa"`, `"aaa"`, …                 |
| Opcional     | `?`          | `a?`          | `""` ou `"a"`                               |
| Agrupamento  | `(…)`        | `(a\|b)*`     | Qualquer cadeia sobre {a, b}                |

> Caracteres com significado especial (`|`, `*`, `+`, `?`, `(`, `)`) não podem
> ser usados como literais. Todos os demais ASCII imprimíveis são tratados como literais.

**Expressões utilizadas no laboratório:**

```
ab*                      # 'a' seguido de zero ou mais 'b'
a*b+                     # zero ou mais 'a', depois um ou mais 'b'
(a|b)*abb                # terminadas em "abb" sobre {a, b}
a?                       # string vazia ou "a"
(a|b)*c(a+b|ba?)*        # padrão complexo sobre {a, b, c}
```
