-- Habilita a extensão OverloadedStrings, permitindo que strings literais sejam
-- interpretadas como outros tipos além de String (ex: ByteString, Text)
{-# LANGUAGE OverloadedStrings #-}

-- Importa o módulo para leitura e escrita de arquivos YAML
import Data.Yaml
-- Importa funções e operadores para parsing/serialização JSON (base do YAML)
-- FromJSON e ToJSON são typeclasses; (.:) lê campos; (.=) e object criam objetos JSON
import Data.Aeson (FromJSON(..), ToJSON(..), (.:), (.=), object, withObject)
-- nub: remove duplicatas; sort: ordena; intercalate: junta com separador
-- groupBy: agrupa elementos consecutivos iguais; sortBy: ordena com comparador
-- findIndex: retorna o índice do primeiro elemento que satisfaz um predicado
import Data.List (nub, sort, intercalate, groupBy, sortBy, findIndex)
-- listToMaybe: converte lista para Maybe (Nothing se vazia, Just head se não vazia)
import Data.Maybe (listToMaybe)
-- getArgs: obtém os argumentos passados na linha de comando
import System.Environment (getArgs)

-- =============================
-- Definição de tipos base
-- =============================

-- Alias: um Estado é representado como uma String (ex: "q0", "q1")
type State = String
-- Alias: um Símbolo do alfabeto também é uma String (ex: "a", "b", "epsilon")
type Symbol = String

-- Tipo enumerado que representa os três tipos de autômatos suportados
-- DFA: Determinístico; NFA: Não-determinístico; NFAE: NFA com transições epsilon
data AutomatonType = DFA | NFA | NFAE deriving (Show, Eq)

-- Representa uma transição do autômato:
-- de um estado (from), lendo um símbolo (symbol), vai para uma lista de estados (to)
-- O campo "to" é uma lista para suportar NFA (múltiplos destinos por transição)
data Transition = Transition
  { from   :: State    -- estado de origem
  , symbol :: Symbol   -- símbolo consumido
  , to     :: [State]  -- estados de destino (lista suporta NFA)
  } deriving (Show, Eq)

-- Representa o autômato completo com todos os seus componentes
data Automaton = Automaton
  { autoType     :: AutomatonType  -- tipo do autômato (DFA, NFA, NFAE)
  , alphabet     :: [Symbol]       -- lista de símbolos do alfabeto
  , states       :: [State]        -- lista de todos os estados
  , initialState :: State          -- estado inicial
  , finalStates  :: [State]        -- lista de estados finais/aceitadores
  , transitions  :: [Transition]   -- lista de todas as transições
  } deriving (Show, Eq)

-- =============================
-- Instâncias JSON/YAML
-- Definem como serializar e deserializar os tipos de/para YAML
-- =============================

-- Lê o tipo do autômato a partir de uma string YAML ("dfa", "nfa", "nfae")
instance FromJSON AutomatonType where
  parseJSON (String "dfa")  = return DFA   -- "dfa" → construtor DFA
  parseJSON (String "nfa")  = return NFA   -- "nfa" → construtor NFA
  parseJSON (String "nfae") = return NFAE  -- "nfae" → construtor NFAE
  parseJSON _ = fail "Invalid automaton type"  -- qualquer outra string falha

-- Converte o tipo do autômato para string ao escrever no YAML
instance ToJSON AutomatonType where
  toJSON DFA  = "dfa"   -- DFA → "dfa"
  toJSON NFA  = "nfa"   -- NFA → "nfa"
  toJSON NFAE = "nfae"  -- NFAE → "nfae"

-- Lê uma Transition a partir de um objeto YAML com campos "from", "symbol" e "to"
instance FromJSON Transition where
  parseJSON = withObject "Transition" $ \v ->
    Transition <$> v .: "from"    -- lê o campo "from"
               <*> v .: "symbol"  -- lê o campo "symbol"
               <*> v .: "to"      -- lê o campo "to" (lista de estados)

-- Serializa uma Transition para objeto YAML com campos "from", "symbol" e "to"
instance ToJSON Transition where
  toJSON (Transition f s t) =
    object ["from" .= f, "symbol" .= s, "to" .= t]  -- monta objeto com os três campos

-- Lê um Automaton completo a partir de um objeto YAML
instance FromJSON Automaton where
  parseJSON = withObject "Automaton" $ \v ->
    Automaton <$> v .: "type"          -- tipo do autômato
              <*> v .: "alphabet"      -- lista de símbolos
              <*> v .: "states"        -- lista de estados
              <*> v .: "initial_state" -- estado inicial
              <*> v .: "final_states"  -- estados finais
              <*> v .: "transitions"   -- lista de transições

-- Serializa um Automaton completo para objeto YAML
instance ToJSON Automaton where
  toJSON a =
    object [ "type"          .= autoType a      -- campo "type"
           , "alphabet"      .= alphabet a      -- campo "alphabet"
           , "states"        .= states a        -- campo "states"
           , "initial_state" .= initialState a  -- campo "initial_state"
           , "final_states"  .= finalStates a   -- campo "final_states"
           , "transitions"   .= transitions a   -- campo "transitions"
           ]

-- =============================
-- ε-closure (fecho épsilon)
-- Calcula todos os estados alcançáveis a partir de um estado
-- usando apenas transições epsilon (sem consumir símbolo)
-- =============================

-- Retorna a ε-closure de um estado: o estado em si mais todos alcançáveis via epsilon
epsilonClosure :: Automaton -> State -> [State]
epsilonClosure auto s = go [s] []  -- inicia com o próprio estado na fila, visitados vazio
  where
    -- Caso base: fila vazia → retorna todos os estados visitados
    go [] visited = visited
    go (x:xs) visited
      -- Se x já foi visitado, ignora e continua com o restante da fila
      | x `elem` visited = go xs visited
      | otherwise =
          -- Coleta todos os estados destino de transições epsilon saindo de x
          let epsMoves = concat
                [ to t
                | t <- transitions auto  -- percorre todas as transições
                , from t == x            -- que partem de x
                , symbol t == "epsilon"  -- que são transições epsilon
                ]
          -- Adiciona os novos estados à fila e marca x como visitado
          in go (xs ++ epsMoves) (x : visited)

-- =============================
-- Remoção de transições epsilon (NFA-ε → NFA)
-- Para cada estado e símbolo, calcula para onde se pode ir
-- passando primeiro por qualquer número de transições epsilon
-- =============================

-- Converte um NFAE em NFA equivalente sem transições epsilon
removeEpsilon :: Automaton -> Automaton
removeEpsilon auto =
  auto
    { autoType = NFA           -- o resultado é um NFA
    , transitions = newTransitions  -- substitui as transições originais
    , finalStates = newFinals  -- atualiza os estados finais
    }
  where
    -- Atalho: calcula a ε-closure de um estado no autômato original
    cls s = epsilonClosure auto s

    -- Gera as novas transições sem epsilon:
    -- para cada estado s e símbolo a, calcula os estados alcançáveis
    -- lendo a a partir de qualquer estado na ε-closure de s
    newTransitions =
      nub  -- remove transições duplicadas
        [ Transition s a (nub targets)  -- cria transição sem epsilon
        | s <- states auto              -- para cada estado do autômato
        , a <- alphabet auto            -- para cada símbolo do alfabeto
        , let closureStates = cls s     -- calcula a ε-closure de s
        , let targets =
                concat
                  [ to t
                  | q <- closureStates     -- para cada estado na ε-closure de s
                  , t <- transitions auto  -- percorre as transições
                  , from t == q            -- que partem de q
                  , symbol t == a          -- lendo o símbolo a
                  ]
        , not (null targets)  -- só inclui a transição se houver destinos
        ]

    -- Um estado s passa a ser final se algum estado em sua ε-closure era final no original
    newFinals =
      [ s
      | s <- states auto                          -- para cada estado
      , any (`elem` finalStates auto) (cls s)     -- se algum da ε-closure é final
      ]

-- =============================
-- Construção de Subconjuntos (NFA → DFA)
-- Converte NFA em DFA onde cada estado do DFA representa
-- um conjunto de estados do NFA
-- =============================

-- Tipo auxiliar: um estado do DFA é representado por uma lista de estados do NFA
type DFAState = [State]

-- Remove duplicatas e ordena uma lista de estados (garante forma canônica)
normalize :: [State] -> [State]
normalize = sort . nub  -- primeiro remove duplicatas, depois ordena

-- Converte um conjunto de estados NFA no nome do estado DFA correspondente.
-- Usa notação de conjunto para ficar legível: ["q0","q1"] → "{q0,q1}"
-- O estado morto (conjunto vazio) recebe o nome "{}"
dfaStateName :: DFAState -> State
dfaStateName [] = "{}"
dfaStateName ss = "{" ++ intercalate "," ss ++ "}"

-- Calcula os estados do NFA alcançáveis a partir de um conjunto de estados lendo um símbolo
move :: Automaton -> [State] -> Symbol -> [State]
move auto sts sym =
  nub  -- remove destinos duplicados
    [ t'
    | s <- sts               -- para cada estado no conjunto atual
    , t <- transitions auto  -- percorre todas as transições
    , from t == s            -- que partem de s
    , symbol t == sym        -- lendo o símbolo sym
    , t' <- to t             -- coleta cada estado destino
    ]

-- Aplica a construção de subconjuntos para converter um NFA em DFA equivalente
subsetConstruction :: Automaton -> Automaton
subsetConstruction nfa =
  Automaton
    { autoType = DFA                              -- resultado é um DFA
    , alphabet = alphabet nfa                     -- mesmo alfabeto do NFA
    , states = map dfaStateName dfaStates         -- estados nomeados como "{q0,q1}"
    , initialState = dfaStateName start           -- estado inicial do DFA
    , finalStates = map dfaStateName dfaFinals    -- estados finais do DFA
    , transitions = dfaTransitions                -- transições calculadas
    }
  where
    -- Estado inicial do DFA: conjunto contendo apenas o estado inicial do NFA
    start = normalize [initialState nfa]

    -- BFS: explora todos os estados do DFA a partir da fila de estados a processar
    go [] visited = visited  -- fila vazia: retorna todos os estados descobertos
    go (q:queue) visited
      -- Se q já foi visitado, pula para o próximo
      | q `elem` visited = go queue visited
      | otherwise =
          -- Calcula os conjuntos de estados destino para cada símbolo do alfabeto
          let next =
                [ normalize (move nfa q a)  -- conjunto de estados após ler a a partir de q
                | a <- alphabet nfa          -- para cada símbolo
                ]
          -- Adiciona os novos conjuntos à fila e marca q como visitado
          in go (queue ++ next) (q : visited)

    -- Conjunto de todos os estados do DFA (descobertos pelo BFS).
    -- O conjunto vazio [] (estado morto) é excluído: transições ausentes
    -- já implicam rejeição, então exibi-lo sem entradas seria inconsistente.
    dfaStates = filter (not . null) (go [start] [])

    -- Estados finais do DFA: conjuntos que contêm pelo menos um estado final do NFA
    dfaFinals =
      [ s
      | s <- dfaStates                      -- para cada estado do DFA
      , any (`elem` finalStates nfa) s      -- se algum estado do conjunto é final no NFA
      ]

    -- Transições do DFA: para cada estado-conjunto e símbolo, calcula o conjunto destino
    dfaTransitions =
      [ Transition (dfaStateName s) a [dfaStateName t]  -- nomes limpos "{q0,q1}"
      | s <- dfaStates                                   -- para cada estado do DFA
      , a <- alphabet nfa                                -- para cada símbolo do alfabeto
      , let t = normalize (move nfa s a)                -- calcula o conjunto destino
      , not (null t)                                     -- ignora transições para conjunto vazio
      ]

-- =============================
-- Minimização do DFA
-- Algoritmo de refinamento de partições:
-- começa com {estados finais} e {estados não-finais} e divide grupos
-- cujos estados têm comportamentos distintos, até a partição estabilizar.
-- Cada grupo final vira um único estado no DFA mínimo.
-- =============================

-- Minimiza um DFA removendo estados equivalentes (indistinguíveis)
minimizeDFA :: Automaton -> Automaton
minimizeDFA dfa = buildMinDFA finalPartition
  where
    -- Função de transição parcial: dado estado e símbolo, retorna o destino (se existir)
    trans s a = listToMaybe
      [ head (to t)
      | t <- transitions dfa  -- percorre todas as transições
      , from t == s            -- que partem de s
      , symbol t == a          -- lendo o símbolo a
      , not (null (to t))      -- com destino não vazio
      ]

    -- Partição inicial: dois grupos — estados finais e estados não-finais
    -- filter remove grupos vazios (caso todos os estados sejam finais ou nenhum seja)
    initialPartition = filter (not . null)
      [ sort (finalStates dfa)
      , sort [s | s <- states dfa, s `notElem` finalStates dfa]
      ]

    -- Retorna o índice do grupo ao qual um estado pertence na partição p
    groupOf p s = findIndex (s `elem`) p

    -- Assinatura de um estado em relação à partição p:
    -- para cada símbolo do alfabeto, qual grupo o estado alcança?
    -- Nothing significa sem transição para aquele símbolo
    signature p s = [groupOf p =<< trans s a | a <- alphabet dfa]

    -- Refina um único grupo: estados com assinaturas diferentes são separados
    refineGroup p grp =
      let sorted = sortBy (\x y -> compare (signature p x) (signature p y)) grp
          groups = groupBy (\x y -> signature p x == signature p y) sorted
      in map sort groups  -- cada subgrupo ordenado

    -- Aplica uma rodada de refinamento em toda a partição
    refineOnce p = concatMap (refineGroup p) p

    -- Repete o refinamento até a partição não mudar mais (estabilização)
    refineUntilStable p =
      let p' = refineOnce p
      in if length p' == length p then p else refineUntilStable p'

    finalPartition = refineUntilStable initialPartition

    -- Constrói o DFA minimizado a partir da partição final estável
    buildMinDFA partition =
      let -- Usa o menor estado (lexicográfico) como representante do grupo
          rep grp    = head (sort grp)
          -- Encontra o representante do grupo ao qual s pertence
          repOf s    = rep $ head [g | g <- partition, s `elem` g]
          newStates  = sort (map rep partition)               -- um estado por grupo
          newInitial = repOf (initialState dfa)               -- representante do grupo inicial
          newFinals  = nub (sort (map repOf (finalStates dfa))) -- representantes dos grupos finais
          newTrans   = nub
            [ Transition (repOf (from t)) (symbol t) [repOf (head (to t))]
            | t <- transitions dfa   -- remapeia cada transição para representantes
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

-- =============================
-- Serializador YAML customizado
-- Produz o mesmo formato do input: arrays inline, chaves na ordem correta
-- e aspas duplas em todos os valores de string.
-- O encoder padrão do Data.Yaml usa ordem alfabética de chaves e estilo
-- bloco para listas, o que diverge do formato de entrada.
-- =============================

-- Converte o tipo do autômato para a string YAML correspondente
autoTypeToStr :: AutomatonType -> String
autoTypeToStr DFA  = "dfa"
autoTypeToStr NFA  = "nfa"
autoTypeToStr NFAE = "nfae"

-- Envolve uma string em aspas duplas, escapando '"' e '\' internos
yamlQuote :: String -> String
yamlQuote s = "\"" ++ concatMap escape s ++ "\""
  where
    escape '"'  = "\\\""  -- aspas duplas viram \"
    escape '\\' = "\\\\"  -- barra invertida vira \\
    escape c    = [c]      -- demais caracteres passam sem alteração

-- Produz um array YAML no estilo inline: ["a", "b", "c"]
yamlInlineList :: [String] -> String
yamlInlineList xs = "[" ++ intercalate ", " (map yamlQuote xs) ++ "]"

-- Serializa uma transição como bloco indentado de 2 espaços
transitionToYaml :: Transition -> String
transitionToYaml t =
  "  - from: "   ++ yamlQuote (from t)   ++ "\n" ++  -- origem da transição
  "    symbol: " ++ yamlQuote (symbol t) ++ "\n" ++  -- símbolo lido
  "    to: "     ++ yamlInlineList (to t) ++ "\n"    -- destino(s) inline

-- Serializa o Automaton completo, respeitando a ordem de chaves do input:
-- type → alphabet → states → initial_state → final_states → transitions
formatAutomaton :: Automaton -> String
formatAutomaton a =
  "type: "          ++ autoTypeToStr (autoType a)        ++ "\n" ++
  "alphabet: "      ++ yamlInlineList (alphabet a)       ++ "\n" ++
  "states: "        ++ yamlInlineList (states a)         ++ "\n" ++
  "initial_state: " ++ yamlQuote (initialState a)        ++ "\n" ++
  "final_states: "  ++ yamlInlineList (finalStates a)    ++ "\n" ++
  "transitions:\n"  ++ concatMap transitionToYaml (transitions a)

-- =============================
-- MAIN
-- Ponto de entrada do programa
-- Lê um autômato de um arquivo YAML, converte para DFA e salva o resultado
-- =============================

main :: IO ()
main = do
  -- Lê os argumentos da linha de comando
  args <- getArgs
  case args of
    -- Espera exatamente dois argumentos: arquivo de entrada e de saída
    [input, output] -> do
      -- Tenta decodificar o arquivo YAML de entrada como um Automaton
      result <- decodeFileEither input
      case result of
        -- Se falhou no parse, imprime o erro
        Left err -> print err
        -- Se leu com sucesso, realiza a conversão
        Right auto -> do
          -- Passo 1: remove transições epsilon (NFA-ε → NFA)
          let nfa    = removeEpsilon auto
          -- Passo 2: aplica construção de subconjuntos (NFA → DFA)
          let dfa    = subsetConstruction nfa
          -- Passo 3: minimiza o DFA fundindo estados equivalentes
          let minDfa = minimizeDFA dfa
          -- Salva o DFA mínimo no arquivo de saída no mesmo formato do input
          writeFile output (formatAutomaton minDfa)
          -- Informa ao usuário que a conversão foi concluída com sucesso
          putStrLn "✅ Conversão concluída!"
    -- Se o número de argumentos for diferente de 2, exibe instruções de uso
    _ -> putStrLn "Uso: ./run.sh input.yaml output.yaml"
