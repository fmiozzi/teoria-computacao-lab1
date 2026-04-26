-- Laboratório 1 — Teoria da Computação (Mestrado)
-- Parte 2: Geração de NFA-ε a partir de Expressão Regular
--
-- Converte uma regex em NFA-ε pela Construção de Thompson,
-- e serializa o resultado em YAML compatível com Main.hs.
--
-- Uso  : cabal run lab1-part2 -- "<regex>" output.yaml
-- Fluxo: regex (string) → AST → NFA-ε (Thompson) → YAML

import Data.List (nub, sort, intercalate)
import System.Environment (getArgs)

-- =====================================================================
-- Árvore Sintática Abstrata da Expressão Regular
-- Representa as seis operações da álgebra regular: concatenação,
-- união, fecho de Kleene (r*), fecho positivo (r+) e opcional (r?).
-- RPlus e ROpt são açúcar sintático: expandidos durante a construção
-- de Thompson para evitar casos especiais no algoritmo.
-- =====================================================================

data Regex
  = RChar   Char
  | REpsilon
  | RConcat Regex Regex
  | RUnion  Regex Regex
  | RStar   Regex
  | RPlus   Regex
  | ROpt    Regex
  deriving (Show, Eq)

-- =====================================================================
-- Parser de Expressão Regular (combinadores descendentes recursivos)
-- Implementa a gramática com precedências explícitas:
--
--   expr   ::= term ('|' term)*        -- menor precedência: união
--   term   ::= factor+                 -- média: concatenação
--   factor ::= atom ('*'|'+'|'?')*     -- alta: sufixos unários
--   atom   ::= char | '(' expr ')' | ⊥ -- maior: átomos e grupos
--
-- Cada nível é uma função separada que retorna o resultado consumido e
-- o sufixo não consumido da entrada, seguindo o padrão parser-combinator.
-- =====================================================================

-- Resultado de um passo de parse: erro ou (AST parcial, resto da entrada).
type ParseResult a = Either String (a, String)

-- Ponto de entrada: exige consumo total da entrada para garantir que
-- não haja lixo sintático após a expressão reconhecida.
parseRegex :: String -> Either String Regex
parseRegex input = case parseExpr input of
  Right (r, [])   -> Right r
  Right (_, rest) -> Left ("Entrada inesperada: " ++ rest)
  Left err        -> Left err

parseExpr :: String -> ParseResult Regex
parseExpr input = do
  (t1, rest1) <- parseTerm input
  parseUnionTail t1 rest1

-- Acumula termos de união com associatividade à esquerda.
parseUnionTail :: Regex -> String -> ParseResult Regex
parseUnionTail left ('|':rest) = do
  (t2, rest2) <- parseTerm rest
  parseUnionTail (RUnion left t2) rest2
parseUnionTail left rest = Right (left, rest)

parseTerm :: String -> ParseResult Regex
parseTerm input = do
  (f1, rest1) <- parseFactor input
  parseConcatTail f1 rest1

-- Encerra o termo quando encontra '|', ')' ou fim de entrada — todos
-- delimitadores que sinalizam o término do nível de concatenação.
parseConcatTail :: Regex -> String -> ParseResult Regex
parseConcatTail left [] = Right (left, [])
parseConcatTail left rest@(c:_)
  | c `elem` ['|', ')'] = Right (left, rest)
  | otherwise = do
      (f2, rest2) <- parseFactor rest
      parseConcatTail (RConcat left f2) rest2

parseFactor :: String -> ParseResult Regex
parseFactor input = do
  (a, rest) <- parseAtom input
  parseSuffix a rest

-- Permite sufixos encadeados (ex.: a*? → ROpt(RStar a)).
parseSuffix :: Regex -> String -> ParseResult Regex
parseSuffix r ('*':rest) = parseSuffix (RStar r) rest
parseSuffix r ('+':rest) = parseSuffix (RPlus r) rest
parseSuffix r ('?':rest) = parseSuffix (ROpt  r) rest
parseSuffix r rest       = Right (r, rest)

-- Operadores em posição de átomo ('*', '+', '?', '|') indicam erro de
-- sintaxe. O parser os rejeita com mensagem diagnóstica explícita para
-- cobrir casos como "*a", "a||b" e evitar falhas silenciosas.
parseAtom :: String -> ParseResult Regex
parseAtom ('(':rest) = do
  (e, rest2) <- parseExpr rest
  case rest2 of
    (')':rest3) -> Right (e, rest3)
    _           -> Left "Parêntese de fechamento esperado"
parseAtom []       = Left "Fim inesperado da entrada"
parseAtom ('|':_)  = Left "Operador '|' em posição inválida: falta termo à esquerda"
parseAtom ('*':_)  = Left "Operador '*' em posição inválida: requer átomo precedente"
parseAtom ('+':_)  = Left "Operador '+' em posição inválida: requer átomo precedente"
parseAtom ('?':_)  = Left "Operador '?' em posição inválida: requer átomo precedente"
parseAtom (c:rest) = Right (RChar c, rest)

-- =====================================================================
-- Construção de Thompson (Regex → NFA-ε)
-- Cada sub-regex produz um fragmento com exatamente um estado de entrada
-- e um estado de saída, identificados por inteiros crescentes alocados
-- sequencialmente. Essa invariante de singleton (início, fim) garante a
-- composição correta das operações: concatenação, união e fecho conectam
-- fragmentos exclusivamente por ε-transições sobre esses dois pontos.
-- =====================================================================

-- Fragmento de NFA gerado por Thompson: três componentes extraídos da
-- chamada recursiva e combinados na função de montagem principal.
data NFAFrag = NFAFrag
  { fragStart :: Int
  , fragEnd   :: Int
  , fragTrans :: [(Int, String, Int)]
  } deriving (Show)

-- Constrói recursivamente o NFA-ε a partir da AST. O parâmetro n
-- representa o próximo inteiro de estado livre; retornado atualizado.
build :: Regex -> Int -> (NFAFrag, Int)

-- n --[c]--> n+1
build (RChar c) n =
  ( NFAFrag n (n+1) [(n, [c], n+1)]
  , n+2 )

-- n --ε--> n+1
build REpsilon n =
  ( NFAFrag n (n+1) [(n, "epsilon", n+1)]
  , n+2 )

-- [r1.start --> r1.end] --ε--> [r2.start --> r2.end]
build (RConcat r1 r2) n =
  let (f1, n1) = build r1 n
      (f2, n2) = build r2 n1
      bridge   = (fragEnd f1, "epsilon", fragStart f2)
      trans    = fragTrans f1 ++ [bridge] ++ fragTrans f2
  in ( NFAFrag (fragStart f1) (fragEnd f2) trans
     , n2 )

--         ε→ [r1] →ε
--  start →              → end
--         ε→ [r2] →ε
build (RUnion r1 r2) n =
  let start    = n
      end      = n+1
      (f1, n1) = build r1 (n+2)
      (f2, n2) = build r2 n1
      trans    = [ (start,      "epsilon", fragStart f1)
                 , (start,      "epsilon", fragStart f2)
                 , (fragEnd f1, "epsilon", end)
                 , (fragEnd f2, "epsilon", end)
                 ] ++ fragTrans f1 ++ fragTrans f2
  in ( NFAFrag start end trans
     , n2 )

--  start →ε→ [r] →ε→ (loop) e →ε→ end
--  start →ε→ end  (0 repetições)
build (RStar r) n =
  let start   = n
      end     = n+1
      (f, n1) = build r (n+2)
      trans   = [ (start,     "epsilon", fragStart f)
                , (start,     "epsilon", end)
                , (fragEnd f, "epsilon", fragStart f)
                , (fragEnd f, "epsilon", end)
                ] ++ fragTrans f
  in ( NFAFrag start end trans
     , n1 )

-- RPlus e ROpt são açúcar sintático expandido diretamente em termos
-- das construções primitivas, evitando casos especiais no algoritmo.
build (RPlus r) n = build (RConcat r (RStar r)) n
build (ROpt  r) n = build (RUnion  r REpsilon)  n

-- =====================================================================
-- Tipos Automaton (espelho de Main.hs)
-- Redefinidos aqui para manter este módulo independente de Main.hs,
-- permitindo compilação e execução isolada da Parte 2.
-- =====================================================================

type State  = String
type Symbol = String

data AutomatonType = DFA | NFA | NFAE deriving (Show, Eq)

data Transition = Transition
  { tranFrom   :: State
  , tranSymbol :: Symbol
  , tranTo     :: [State]
  } deriving (Show, Eq)

data Automaton = Automaton
  { autoType     :: AutomatonType
  , alphabet     :: [Symbol]
  , states       :: [State]
  , initialState :: State
  , finalStates  :: [State]
  , transitions  :: [Transition]
  } deriving (Show, Eq)

-- =====================================================================
-- Serializador YAML customizado
-- Produz o mesmo formato de Main.hs: arrays inline, ordem canônica
-- de campos e aspas duplas em todos os valores de string.
-- =====================================================================

autoTypeToStr :: AutomatonType -> String
autoTypeToStr DFA  = "dfa"
autoTypeToStr NFA  = "nfa"
autoTypeToStr NFAE = "nfae"

-- Envolve uma string em aspas duplas, escapando '"' e '\' internos.
yamlQuote :: String -> String
yamlQuote s = "\"" ++ concatMap escape s ++ "\""
  where
    escape '"'  = "\\\""
    escape '\\' = "\\\\"
    escape c    = [c]

-- Produz um array YAML inline: ["a", "b", "c"].
yamlInlineList :: [String] -> String
yamlInlineList xs = "[" ++ intercalate ", " (map yamlQuote xs) ++ "]"

transitionToYaml :: Transition -> String
transitionToYaml t =
  "  - from: "   ++ yamlQuote (tranFrom   t) ++ "\n" ++
  "    symbol: " ++ yamlQuote (tranSymbol t) ++ "\n" ++
  "    to: "     ++ yamlInlineList (tranTo t) ++ "\n"

-- Serializa um Automaton na ordem canônica de campos:
-- type → alphabet → states → initial_state → final_states → transitions.
formatAutomaton :: Automaton -> String
formatAutomaton a =
  "type: "          ++ autoTypeToStr (autoType a)     ++ "\n" ++
  "alphabet: "      ++ yamlInlineList (alphabet a)    ++ "\n" ++
  "states: "        ++ yamlInlineList (states a)      ++ "\n" ++
  "initial_state: " ++ yamlQuote (initialState a)     ++ "\n" ++
  "final_states: "  ++ yamlInlineList (finalStates a) ++ "\n" ++
  "transitions:\n"  ++ concatMap transitionToYaml (transitions a)

-- =====================================================================
-- Conversão NFAFrag → Automaton
-- =====================================================================

stateName :: Int -> State
stateName n = "q" ++ show n

-- Percorre a AST coletando todos os símbolos literais (= Σ da linguagem).
-- Epsilon não é elemento do alfabeto e é excluído sistematicamente.
collectAlphabet :: Regex -> [Symbol]
collectAlphabet (RChar c)       = [[c]]
collectAlphabet REpsilon        = []
collectAlphabet (RConcat r1 r2) = nub (collectAlphabet r1 ++ collectAlphabet r2)
collectAlphabet (RUnion  r1 r2) = nub (collectAlphabet r1 ++ collectAlphabet r2)
collectAlphabet (RStar r)       = collectAlphabet r
collectAlphabet (RPlus r)       = collectAlphabet r
collectAlphabet (ROpt  r)       = collectAlphabet r

-- Agrupa as transições brutas (Int, String, Int) em Transitions com
-- to :: [State]. Pares (from, symbol) com múltiplos destinos — gerados
-- pelas ε-transições de RUnion — são fundidos em uma única Transition.
groupTransitions :: [(Int, String, Int)] -> [Transition]
groupTransitions trans =
  [ Transition (stateName f) sym dests
  | (f, sym) <- keys
  , let dests = nub [stateName t | (f', sym', t) <- trans, f' == f, sym' == sym]
  ]
  where
    keys = nub [(f, sym) | (f, sym, _) <- trans]

-- Converte um NFAFrag para o tipo Automaton compatível com Main.hs.
-- Thompson garante exatamente um estado final por fragmento; essa
-- invariante é preservada pela atribuição singleton de finalStates.
fragToAutomaton :: NFAFrag -> Regex -> Automaton
fragToAutomaton frag regex =
  Automaton
    { autoType     = NFAE
    , alphabet     = sort (collectAlphabet regex)
    , states       = map stateName allStateIds
    , initialState = stateName (fragStart frag)
    , finalStates  = [stateName (fragEnd frag)]
    , transitions  = groupTransitions (fragTrans frag)
    }
  where
    allStateIds = sort . nub $
      [fragStart frag, fragEnd frag]     ++
      [s | (s, _, _) <- fragTrans frag]  ++
      [t | (_, _, t) <- fragTrans frag]

-- =====================================================================
-- Ponto de entrada
-- Pipeline: regex (string) → AST → NFAFrag (Thompson) → Automaton → YAML.
-- O NFA-ε gerado é compatível com Main.hs para continuar a conversão
-- removeEpsilon → subsetConstruction → minimizeDFA.
-- =====================================================================

main :: IO ()
main = do
  args <- getArgs
  case args of
    [regexStr, output] -> do
      case parseRegex regexStr of
        Left err -> putStrLn ("Erro de sintaxe na regex: " ++ err)
        Right regex -> do
          let (frag, totalStates) = build regex 0
          let automaton = fragToAutomaton frag regex
          writeFile output (formatAutomaton automaton)
          putStrLn ("✅ NFA-ε gerado em: " ++ output)
          putStrLn ("   Regex    : " ++ regexStr)
          putStrLn ("   Alfabeto : " ++ show (alphabet automaton))
          putStrLn ("   Estados  : " ++ show totalStates)
          putStrLn ("   (use ./Exec/NFAe_to_DFA.sh para converter o NFAε em DFA mínimo)")
    _ -> putStrLn "Uso: ./lab1_part2 \"<regex>\" output.yaml"
