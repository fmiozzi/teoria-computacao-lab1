-- ^ Habilita a interpretação polimórfica de literais String (necessário
--   para que Data.Yaml possa deserializar campos YAML como Text interno).
{-# LANGUAGE OverloadedStrings #-}

import Data.Yaml
import Data.List  (nub, sort, intercalate, groupBy, sortBy, findIndex)
import Data.Maybe (listToMaybe)
import System.Environment (getArgs)

-- =====================================================================
-- Tipos de dados
-- =====================================================================

type State  = String   -- identificador de estado (ex.: "q0", "{q1,q2}")
type Symbol = String   -- símbolo do alfabeto ou o literal "epsilon"

data AutomatonType = DFA | NFA | NFAE deriving (Show, Eq)

-- Representa a função de transição δ(from, symbol) = to.
-- O campo 'to' é uma lista para acomodar NFA (múltiplos destinos)
-- e DFA (singleton); a lista vazia codifica ausência de transição.
data Transition = Transition
  { from   :: State
  , symbol :: Symbol
  , to     :: [State]
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
-- Serialização / Deserialização YAML (via Data.Aeson)
-- =====================================================================

instance FromJSON AutomatonType where
  parseJSON (String "dfa")  = return DFA
  parseJSON (String "nfa")  = return NFA
  parseJSON (String "nfae") = return NFAE
  parseJSON _ = fail "Tipo inválido: esperado \"dfa\", \"nfa\" ou \"nfae\""

instance ToJSON AutomatonType where
  toJSON DFA  = "dfa"
  toJSON NFA  = "nfa"
  toJSON NFAE = "nfae"

instance FromJSON Transition where
  parseJSON = withObject "Transition" $ \v ->
    Transition <$> v .: "from" <*> v .: "symbol" <*> v .: "to"

instance ToJSON Transition where
  toJSON (Transition f s t) = object ["from" .= f, "symbol" .= s, "to" .= t]

instance FromJSON Automaton where
  parseJSON = withObject "Automaton" $ \v ->
    Automaton <$> v .: "type"
              <*> v .: "alphabet"
              <*> v .: "states"
              <*> v .: "initial_state"
              <*> v .: "final_states"
              <*> v .: "transitions"

instance ToJSON Automaton where
  toJSON a =
    object [ "type"          .= autoType a
           , "alphabet"      .= alphabet a
           , "states"        .= states a
           , "initial_state" .= initialState a
           , "final_states"  .= finalStates a
           , "transitions"   .= transitions a
           ]

-- =====================================================================
-- ε-fecho (ε-closure)
-- Computa ε*(q) = conjunto de estados alcançáveis a partir de q por
-- zero ou mais transições ε, via busca em largura sobre o subgrafo
-- de transições ε do autômato.
-- =====================================================================

epsilonClosure :: Automaton -> State -> [State]
epsilonClosure auto s = go [s] []
  where
    go [] visited = visited
    go (x:xs) visited
      | x `elem` visited = go xs visited
      | otherwise =
          let epsMoves = concat
                [ to t
                | t <- transitions auto
                , from t == x
                , symbol t == "epsilon"
                ]
          in go (xs ++ epsMoves) (x : visited)

-- =====================================================================
-- Remoção de transições ε (NFAε → NFA)
-- Implementa a transformação formal:
--   δ'(q, a) = ε*(∪{ δ(p, a) | p ∈ ε*(q) })
-- Um estado q torna-se final no NFA resultante se ε*(q) ∩ F ≠ ∅.
-- =====================================================================

removeEpsilon :: Automaton -> Automaton
removeEpsilon auto =
  auto
    { autoType    = NFA
    , transitions = newTransitions
    , finalStates = newFinals
    }
  where
    cls s = epsilonClosure auto s

    newTransitions =
      nub
        [ Transition s a (nub finalTargets)
        | s <- states auto
        , a <- alphabet auto
        , let closureStates = cls s
        , let rawTargets    = concat
                [ to t
                | q <- closureStates
                , t <- transitions auto
                , from t == q
                , symbol t == a
                ]
        , let finalTargets  = concatMap cls rawTargets
        , not (null finalTargets)
        ]

    newFinals =
      [ s | s <- states auto, any (`elem` finalStates auto) (cls s) ]

-- =====================================================================
-- Construção de subconjuntos (NFA → DFA)
-- Cada estado do DFA representa um subconjunto de estados do NFA,
-- codificado canonicamente como "{q_i,q_j,...}" (elementos ordenados).
-- A BFS explora todos os subconjuntos alcançáveis a partir de {q₀}.
-- =====================================================================

type DFAState = [State]

-- Normaliza um subconjunto: remove duplicatas e ordena lexicograficamente,
-- garantindo uma representação canônica única para cada conjunto de estados.
normalize :: [State] -> [State]
normalize = sort . nub

-- Codifica um subconjunto de estados NFA como identificador de estado DFA.
-- Convenção adotada: [] → "{}" (estado morto); [q_i,...] → "{q_i,...}".
dfaStateName :: DFAState -> State
dfaStateName [] = "{}"
dfaStateName ss = "{" ++ intercalate "," ss ++ "}"

-- Função de transição não-determinística estendida a conjuntos:
-- δ(S, a) = ∪{ δ(s, a) | s ∈ S }.
move :: Automaton -> [State] -> Symbol -> [State]
move auto sts sym =
  nub
    [ t'
    | s  <- sts
    , t  <- transitions auto
    , from t == s
    , symbol t == sym
    , t' <- to t
    ]

subsetConstruction :: Automaton -> Automaton
subsetConstruction nfa =
  Automaton
    { autoType     = DFA
    , alphabet     = alphabet nfa
    , states       = map dfaStateName dfaStates
    , initialState = dfaStateName start
    , finalStates  = map dfaStateName dfaFinals
    , transitions  = dfaTransitions
    }
  where
    start = normalize [initialState nfa]

    go [] visited = visited
    go (q:queue) visited
      | q `elem` visited = go queue visited
      | otherwise =
          let next = [ normalize (move nfa q a) | a <- alphabet nfa ]
          in go (queue ++ next) (q : visited)

    -- O estado morto (subconjunto vazio) é excluído intencionalmente,
    -- produzindo um DFA parcial. Transições ausentes equivalem à rejeição,
    -- reduzindo o número de estados sem afetar a linguagem reconhecida.
    dfaStates = filter (not . null) (go [start] [])

    dfaFinals =
      [ s | s <- dfaStates, any (`elem` finalStates nfa) s ]

    dfaTransitions =
      [ Transition (dfaStateName s) a [dfaStateName t]
      | s <- dfaStates
      , a <- alphabet nfa
      , let t = normalize (move nfa s a)
      , not (null t)
      ]

-- Ordena identificadores de estado DFA por cardinalidade do subconjunto
-- NFA codificado e, como critério de desempate, lexicograficamente.
-- Motivação: a ordem ASCII pura produz "{q0,q1}" < "{q0}" (pois ',' < '}'),
-- elegendo representantes contra-intuitivos na minimização — por exemplo,
-- um estado inicial nomeado com o conjunto maior em vez do singleton.
compareStateNames :: State -> State -> Ordering
compareStateNames a b = compare (stateCount a, a) (stateCount b, b)
  where
    stateCount "{}" = 0 :: Int
    stateCount s    = 1 + length (filter (== ',') s)

-- =====================================================================
-- Minimização do DFA (refinamento de partições)
-- Variante do algoritmo de Hopcroft: inicializa a partição com os dois
-- blocos {F, Q\F} e refina iterativamente até atingir ponto fixo.
-- Dois estados s, s' são equivalentes se, para todo símbolo a, ambos
-- transitam para o mesmo bloco da partição corrente (mesma assinatura).
-- Cada bloco final é colapsado em um único estado representante.
-- =====================================================================

minimizeDFA :: Automaton -> Automaton
minimizeDFA dfa = buildMinDFA finalPartition
  where
    -- Função de transição parcial: retorna o destino único de (s, a).
    trans s a = listToMaybe
      [ head (to t)
      | t <- transitions dfa
      , from t == s
      , symbol t == a
      , not (null (to t))
      ]

    initialPartition = filter (not . null)
      [ sort (finalStates dfa)
      , sort [s | s <- states dfa, s `notElem` finalStates dfa]
      ]

    -- Índice do bloco da partição p ao qual o estado s pertence.
    groupOf p s = findIndex (s `elem`) p

    -- Assinatura de distinguibilidade de s em relação à partição p:
    -- vetor dos índices de bloco para cada símbolo do alfabeto.
    -- Nothing indica ausência de transição (DFA parcial).
    signature p s = [groupOf p =<< trans s a | a <- alphabet dfa]

    -- Refinamento de um bloco: estados com assinaturas distintas
    -- são separados em subgrupos distintos.
    refineGroup p grp =
      let sorted = sortBy (\x y -> compare (signature p x) (signature p y)) grp
          groups = groupBy (\x y -> signature p x == signature p y) sorted
      in map sort groups

    refineOnce p = concatMap (refineGroup p) p

    -- Iteração até ponto fixo. Como refinamento é monótono (apenas divide
    -- blocos, nunca os une), a condição p' == p é necessária e suficiente
    -- para a convergência do algoritmo.
    refineUntilStable p =
      let p' = refineOnce p
      in if p' == p then p else refineUntilStable p'

    finalPartition = refineUntilStable initialPartition

    -- Constrói o DFA mínimo colapsando cada bloco em seu representante.
    -- O representante é o estado de menor cardinalidade (via compareStateNames)
    -- para preservar identificadores intuitivos (ex.: "{q0}" como inicial).
    buildMinDFA partition =
      let rep grp    = head (sortBy compareStateNames grp)
          repOf s    = rep $ head [g | g <- partition, s `elem` g]
          newStates  = sort (map rep partition)
          newInitial = repOf (initialState dfa)
          newFinals  = nub (sort (map repOf (finalStates dfa)))
          newTrans   = nub
            [ Transition (repOf (from t)) (symbol t) [repOf (head (to t))]
            | t <- transitions dfa
            , not (null (to t))
            ]
      in Automaton
           { autoType     = DFA
           , alphabet     = alphabet dfa
           , states       = newStates
           , initialState = newInitial
           , finalStates  = newFinals
           , transitions  = newTrans
           }

-- =====================================================================
-- Serializador YAML customizado
-- O encoder padrão de Data.Yaml ordena chaves alfabeticamente e produz
-- listas em bloco, divergindo do formato de entrada. Este serializador
-- garante a ordem canônica de campos, listas inline e aspas duplas.
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
  "  - from: "   ++ yamlQuote (from t)    ++ "\n" ++
  "    symbol: " ++ yamlQuote (symbol t)  ++ "\n" ++
  "    to: "     ++ yamlInlineList (to t) ++ "\n"

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
-- Ponto de entrada
-- Pipeline de conversão: NFAε → NFA → DFA → DFA mínimo.
-- Recebe três argumentos: arquivo de entrada, saída do NFA intermediário
-- e saída do DFA mínimo. Os estágios ativos dependem do tipo da entrada.
-- =====================================================================

main :: IO ()
main = do
  args <- getArgs
  case args of
    [input, outputNfa, outputDfa] -> do
      result <- decodeFileEither input
      case result of
        Left err -> print err
        Right auto -> do
          case autoType auto of

            -- Entrada já é DFA: minimização direta, sem conversão prévia.
            DFA -> do
              let minDfa = minimizeDFA auto
              writeFile outputNfa (formatAutomaton auto)
              writeFile outputDfa (formatAutomaton minDfa)
              putStrLn "✅ Entrada já é um DFA — minimização aplicada."

            -- Entrada é NFA: omite removeEpsilon, aplica subsetConstruction.
            NFA -> do
              let dfa    = subsetConstruction auto
              let minDfa = minimizeDFA dfa
              writeFile outputNfa (formatAutomaton auto)
              writeFile outputDfa (formatAutomaton minDfa)
              putStrLn "✅ NFA → DFA concluído."

            -- Pipeline completo em três estágios.
            NFAE -> do
              let nfa    = removeEpsilon auto
              let dfa    = subsetConstruction nfa
              let minDfa = minimizeDFA dfa
              writeFile outputNfa (formatAutomaton nfa)
              writeFile outputDfa (formatAutomaton minDfa)
              putStrLn "✅ NFAε → NFA → DFA mínimo concluído."

    _ -> putStrLn "Uso: ./run.sh input.yaml output_nfa.yaml output_dfa.yaml"
