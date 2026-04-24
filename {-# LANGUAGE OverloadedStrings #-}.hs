{-# LANGUAGE OverloadedStrings #-}
-- Ativa uma extensão do Haskell que permite usar strings normais ("texto")
-- em contextos onde seriam esperados outros tipos (como JSON/YAML).
-- Sem isso, várias conversões dariam erro.

import Data.Yaml
-- Biblioteca para ler e escrever arquivos YAML

import Data.Aeson (FromJSON(..), ToJSON(..), (.:), (.=), object, withObject)
-- Biblioteca base de JSON (YAML usa isso por baixo)
-- FromJSON / ToJSON → conversão de/para Haskell
-- (.:) → lê um campo
-- (.=) → cria um campo
-- object → cria objeto JSON
-- withObject → garante que estamos lidando com um objeto

import qualified Data.ByteString as BS
-- Manipulação de bytes (não usado diretamente aqui, mas comum em YAML)

import Data.List (nub, sort)
-- nub → remove duplicados
-- sort → ordena lista

import qualified Data.Set as Set
-- Estrutura de conjunto (não usada diretamente no código)

import Data.Maybe (fromMaybe)
-- Funções para valores opcionais (também não usada aqui)

import System.Environment (getArgs)
-- Permite ler argumentos da linha de comando

-- =========================
-- TIPOS BÁSICOS
-- =========================

type State = String
-- Um estado é representado como texto (ex: "q0")

type Symbol = String
-- Um símbolo também é texto (ex: "a", "b")

-- Tipo do autômato

data AutomatonType = DFA | NFA | NFAE deriving (Show, Eq)
-- DFA = determinístico
-- NFA = não determinístico
-- NFAE = com epsilon
-- deriving (Show, Eq) → permite imprimir e comparar

-- =========================
-- TRANSIÇÃO
-- =========================

data Transition = Transition
  { from   :: State     -- estado de origem
  , symbol :: Symbol    -- símbolo da transição
  , to     :: [State]   -- estados de destino (lista!)
  } deriving (Show, Eq)

-- Exemplo:
-- q0 --a--> q1,q2

-- =========================
-- AUTÔMATO COMPLETO
-- =========================

data Automaton = Automaton
  { autoType     :: AutomatonType   -- tipo (DFA/NFA/NFAE)
  , alphabet     :: [Symbol]        -- alfabeto (ex: ["a","b"])
  , states       :: [State]         -- lista de estados
  , initialState :: State           -- estado inicial
  , finalStates  :: [State]         -- estados finais
  , transitions  :: [Transition]    -- transições
  } deriving (Show, Eq)

-- =========================
-- CONVERSÃO JSON/YAML
-- =========================

instance FromJSON AutomatonType where
  parseJSON (String "dfa")  = return DFA
  -- Se no YAML vier "dfa", vira DFA

  parseJSON (String "nfa")  = return NFA
  parseJSON (String "nfae") = return NFAE

  parseJSON _ = fail "Invalid automaton type"
  -- Qualquer outro valor dá erro

instance ToJSON AutomatonType where
  toJSON DFA  = "dfa"
  toJSON NFA  = "nfa"
  toJSON NFAE = "nfae"
-- Faz o caminho inverso: Haskell → YAML

-- -------------------------

instance FromJSON Transition where
  parseJSON = withObject "Transition" $ \v ->
    Transition <$> v .: "from"
               <*> v .: "symbol"
               <*> v .: "to"

-- Explicação:
-- v é o objeto YAML
-- lê:
-- "from", "symbol", "to"
-- e monta um Transition

-- -------------------------

instance ToJSON Transition where
  toJSON (Transition f s t) =
    object ["from" .= f, "symbol" .= s, "to" .= t]

-- Converte Transition → YAML

-- -------------------------

instance FromJSON Automaton where
  parseJSON = withObject "Automaton" $ \v ->
    Automaton <$> v .: "type"
              <*> v .: "alphabet"
              <*> v .: "states"
              <*> v .: "initial_state"
              <*> v .: "final_states"
              <*> v .: "transitions"

-- Lê o YAML inteiro e monta o automato

-- -------------------------

instance ToJSON Automaton where
  toJSON a =
    object [ "type" .= autoType a
           , "alphabet" .= alphabet a
           , "states" .= states a
           , "initial_state" .= initialState a
           , "final_states" .= finalStates a
           , "transitions" .= transitions a
           ]

-- Converte o automato de volta para YAML

-- =============================
-- ε-CLOSURE
-- =============================

epsilonClosure :: Automaton -> State -> [State]
-- Entrada:
-- automato + estado
-- Saída:
-- todos estados alcançáveis via epsilon

epsilonClosure auto s = go [s] []
  where

    go [] visited = visited
    -- Se não há mais estados para explorar → retorna os visitados

    go (x:xs) visited
      | x `elem` visited = go xs visited
      -- Se já visitou x, ignora

      | otherwise =
          let epsMoves = concat
                [ to t
                | t <- transitions auto
                , from t == x
                , symbol t == "epsilon"
                ]
          -- pega todas transições epsilon saindo de x

          in go (xs ++ epsMoves) (x : visited)
          -- continua explorando

-- =============================
-- REMOVER EPSILON
-- =============================

removeEpsilon :: Automaton -> Automaton
removeEpsilon auto =
  auto
    { autoType = NFA
    -- agora vira NFA normal

    , transitions = newTransitions
    -- substitui transições

    , finalStates = newFinals
    -- substitui finais
    }
  where

    cls s = epsilonClosure auto s
    -- função auxiliar: closure de s

    newTransitions =
      nub
        [ Transition s a (nub targets)
        | s <- states auto
        -- para cada estado

        , a <- alphabet auto
        -- para cada símbolo

        , let closureStates = cls s
        -- pega closure de s

        , let targets =
                concat
                  [ to t
                  | q <- closureStates
                  , t <- transitions auto
                  , from t == q
                  , symbol t == a
                  ]
        -- segue transições normais a partir do closure

        , not (null targets)
        -- ignora se não houver destino
        ]

    newFinals =
      [ s
      | s <- states auto
      , any (`elem` finalStates auto) (cls s)
      ]
    -- se algum estado do closure é final → s vira final

-- =============================
-- SUBSET CONSTRUCTION
-- =============================

type DFAState = [State]
-- estado do DFA = conjunto de estados

normalize :: [State] -> [State]
normalize = sort . nub
-- remove duplicados e ordena

-- -------------------------

move :: Automaton -> [State] -> Symbol -> [State]
move auto sts sym =
  nub
    [ t'
    | s <- sts
    -- para cada estado do conjunto

    , t <- transitions auto
    , from t == s
    , symbol t == sym
    -- pega transições com símbolo

    , t' <- to t
    -- pega destino
    ]

-- -------------------------

subsetConstruction :: Automaton -> Automaton
subsetConstruction nfa =
  Automaton
    { autoType = DFA
    -- resultado é DFA

    , alphabet = alphabet nfa

    , states = map show dfaStates
    -- converte estados (listas) para string

    , initialState = show start

    , finalStates = map show dfaFinals

    , transitions = dfaTransitions
    }

  where

    start = normalize [initialState nfa]
    -- estado inicial do DFA

    go [] visited = visited
    -- BFS terminou

    go (q:queue) visited
      | q `elem` visited = go queue visited
      -- já visitado

      | otherwise =
          let next =
                [ normalize (move nfa q a)
                | a <- alphabet nfa
                ]
          -- calcula próximos estados

          in go (queue ++ next) (q : visited)
          -- continua busca

    dfaStates = go [start] []
    -- todos estados possíveis

    dfaFinals =
      [ s
      | s <- dfaStates
      , any (`elem` finalStates nfa) s
      ]
    -- se contém estado final → é final

    dfaTransitions =
      [ Transition (show s) a [show t]
      | s <- dfaStates
      , a <- alphabet nfa
      , let t = normalize (move nfa s a)
      , not (null t)
      ]
    -- cria transições

-- =============================
-- MAIN
-- =============================

main :: IO ()
main = do

  args <- getArgs
  -- lê argumentos do terminal

  case args of

    [input, output] -> do
      -- espera exatamente 2 argumentos

      result <- decodeFileEither input
      -- tenta ler YAML

      case result of

        Left err -> print err
        -- erro na leitura

        Right auto -> do
          -- sucesso

          let nfa = removeEpsilon auto
          -- remove epsilon

          let dfa = subsetConstruction nfa
          -- converte para DFA

          encodeFile output dfa
          -- salva no arquivo

          putStrLn "✅ Conversão concluída!"
          -- mensagem final

    _ -> putStrLn "Uso: ./run.sh input.yaml output.yaml"
    -- caso usuário use errado