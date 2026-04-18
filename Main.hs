{-# LANGUAGE OverloadedStrings #-}

import Data.Yaml
import Data.Aeson (FromJSON(..), ToJSON(..), (.:), (.=), object, withObject)
import qualified Data.ByteString as BS
import Data.List (nub, sort)
import qualified Data.Set as Set
import Data.Maybe (fromMaybe)
import System.Environment (getArgs)

type State = String
type Symbol = String

data AutomatonType = DFA | NFA | NFAE deriving (Show, Eq)

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

-- JSON/YAML instances

instance FromJSON AutomatonType where
  parseJSON (String "dfa")  = return DFA
  parseJSON (String "nfa")  = return NFA
  parseJSON (String "nfae") = return NFAE
  parseJSON _ = fail "Invalid automaton type"

instance ToJSON AutomatonType where
  toJSON DFA  = "dfa"
  toJSON NFA  = "nfa"
  toJSON NFAE = "nfae"

instance FromJSON Transition where
  parseJSON = withObject "Transition" $ \v ->
    Transition <$> v .: "from"
               <*> v .: "symbol"
               <*> v .: "to"

instance ToJSON Transition where
  toJSON (Transition f s t) =
    object ["from" .= f, "symbol" .= s, "to" .= t]

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
    object [ "type" .= autoType a
           , "alphabet" .= alphabet a
           , "states" .= states a
           , "initial_state" .= initialState a
           , "final_states" .= finalStates a
           , "transitions" .= transitions a
           ]

-- =============================
-- ε-closure
-- =============================

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

-- =============================
-- Remove epsilon transitions
-- =============================

removeEpsilon :: Automaton -> Automaton
removeEpsilon auto =
  auto
    { autoType = NFA
    , transitions = newTransitions
    , finalStates = newFinals
    }
  where
    cls s = epsilonClosure auto s

    newTransitions =
      nub
        [ Transition s a (nub targets)
        | s <- states auto
        , a <- alphabet auto
        , let closureStates = cls s
        , let targets =
                concat
                  [ to t
                  | q <- closureStates
                  , t <- transitions auto
                  , from t == q
                  , symbol t == a
                  ]
        , not (null targets)
        ]

    newFinals =
      [ s
      | s <- states auto
      , any (`elem` finalStates auto) (cls s)
      ]

-- =============================
-- Subset Construction (NFA → DFA)
-- =============================

type DFAState = [State]

normalize :: [State] -> [State]
normalize = sort . nub

move :: Automaton -> [State] -> Symbol -> [State]
move auto sts sym =
  nub
    [ t'
    | s <- sts
    , t <- transitions auto
    , from t == s
    , symbol t == sym
    , t' <- to t
    ]

subsetConstruction :: Automaton -> Automaton
subsetConstruction nfa =
  Automaton
    { autoType = DFA
    , alphabet = alphabet nfa
    , states = map show dfaStates
    , initialState = show start
    , finalStates = map show dfaFinals
    , transitions = dfaTransitions
    }
  where
    start = normalize [initialState nfa]

    go [] visited = visited
    go (q:queue) visited
      | q `elem` visited = go queue visited
      | otherwise =
          let next =
                [ normalize (move nfa q a)
                | a <- alphabet nfa
                ]
          in go (queue ++ next) (q : visited)

    dfaStates = go [start] []

    dfaFinals =
      [ s
      | s <- dfaStates
      , any (`elem` finalStates nfa) s
      ]

    dfaTransitions =
      [ Transition (show s) a [show t]
      | s <- dfaStates
      , a <- alphabet nfa
      , let t = normalize (move nfa s a)
      , not (null t)
      ]

-- =============================
-- MAIN
-- =============================

main :: IO ()
main = do
  args <- getArgs
  case args of
    [input, output] -> do
      result <- decodeFileEither input
      case result of
        Left err -> print err
        Right auto -> do
          let nfa = removeEpsilon auto
          let dfa = subsetConstruction nfa
          encodeFile output dfa
          putStrLn "✅ Conversão concluída!"
    _ -> putStrLn "Uso: ./run.sh input.yaml output.yaml"