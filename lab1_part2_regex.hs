-- Flavioooo
-- Motor de geração de autômatos baseado em expressões regulares.
-- Converte uma regex em NFA-ε usando a Construção de Thompson,
-- e salva o resultado em YAML compatível com o formato de Main.hs.
-- Uso: ./lab1_part2 "<regex>" output.yaml
-- Fluxo: regex (string) → AST → NFA-ε (Thompson) → YAML

-- Habilita OverloadedStrings para usar literais de string como Text/ByteString
{-# LANGUAGE OverloadedStrings #-}

-- Serialização e escrita de arquivos YAML
import Data.Yaml (encodeFile)
-- Operadores e funções para montar objetos JSON/YAML
import Data.Aeson (ToJSON(..), (.=), object)
-- nub: remove duplicatas; sort: ordena; intercalate: junta com separador
import Data.List (nub, sort)
-- Leitura dos argumentos da linha de comando
import System.Environment (getArgs)

-- =============================
-- AST da Expressão Regular
-- Representa a árvore sintática de uma regex
-- =============================

data Regex
  = RChar   Char         -- literal: um único caractere (ex: 'a')
  | REpsilon             -- palavra vazia (epsilon)
  | RConcat Regex Regex  -- concatenação: r1 seguido de r2 (ex: ab)
  | RUnion  Regex Regex  -- união/alternância: r1 ou r2 (ex: a|b)
  | RStar   Regex        -- fecho de Kleene: 0 ou mais repetições (ex: a*)
  | RPlus   Regex        -- uma ou mais repetições (ex: a+), equivale a r·r*
  | ROpt    Regex        -- opcional: 0 ou 1 ocorrência (ex: a?), equivale a r|ε
  deriving (Show, Eq)

-- =============================
-- Parser de Expressão Regular
-- Converte a string da regex em uma AST (Regex)
--
-- Gramática (precedência crescente, menor para maior):
--   expr   ::= term ('|' term)*        ← menor: união
--   term   ::= factor+                 ← médio: concatenação
--   factor ::= atom ('*'|'+'|'?')*     ← alto: sufixos
--   atom   ::= char | '(' expr ')'     ← maior: átomos
-- =============================

-- Tipo de resultado do parser: ou erro ou (valor, resto da string não consumida)
type ParseResult a = Either String (a, String)

-- Ponto de entrada: parseia a string inteira e exige que não sobre nada
parseRegex :: String -> Either String Regex
parseRegex input = case parseExpr input of
  Right (r, [])   -> Right r                               -- sucesso: toda a string foi consumida
  Right (_, rest) -> Left ("Entrada inesperada: " ++ rest) -- sobrou texto não reconhecido
  Left err        -> Left err                              -- erro de sintaxe

-- Parseia uma expressão completa (nível mais baixo de precedência: união)
parseExpr :: String -> ParseResult Regex
parseExpr input = do
  (t1, rest1) <- parseTerm input     -- parseia o primeiro termo
  parseUnionTail t1 rest1            -- verifica se há '|' para mais termos

-- Continua lendo termos separados por '|', acumulando no nó RUnion
parseUnionTail :: Regex -> String -> ParseResult Regex
parseUnionTail left ('|':rest) = do
  (t2, rest2) <- parseTerm rest               -- parseia o próximo termo após '|'
  parseUnionTail (RUnion left t2) rest2       -- acumula à esquerda (left-associative)
parseUnionTail left rest = Right (left, rest) -- não há mais '|': retorna o que acumulou

-- Parseia um termo (nível médio: concatenação de fatores)
parseTerm :: String -> ParseResult Regex
parseTerm input = do
  (f1, rest1) <- parseFactor input   -- parseia o primeiro fator
  parseConcatTail f1 rest1           -- concatena com os fatores seguintes

-- Continua concatenando fatores enquanto houver caracteres que iniciam um átomo
parseConcatTail :: Regex -> String -> ParseResult Regex
parseConcatTail left [] = Right (left, [])         -- fim da string: retorna o acumulado
parseConcatTail left rest@(c:_)
  | c `elem` ['|', ')'] = Right (left, rest)        -- '|' ou ')' encerra o termo
  | otherwise = do
      (f2, rest2) <- parseFactor rest              -- parseia o próximo fator
      parseConcatTail (RConcat left f2) rest2      -- acumula concatenação

-- Parseia um fator: um átomo seguido de zero ou mais sufixos (*, +, ?)
parseFactor :: String -> ParseResult Regex
parseFactor input = do
  (a, rest) <- parseAtom input   -- parseia o átomo base
  parseSuffix a rest             -- aplica sufixos se houver

-- Aplica sufixos ao átomo; permite encadeamento (ex: a*? é ROpt(RStar(a)))
parseSuffix :: Regex -> String -> ParseResult Regex
parseSuffix r ('*':rest) = parseSuffix (RStar r) rest  -- fecho de Kleene
parseSuffix r ('+':rest) = parseSuffix (RPlus r) rest  -- uma ou mais repetições
parseSuffix r ('?':rest) = parseSuffix (ROpt  r) rest  -- opcional
parseSuffix r rest       = Right (r, rest)             -- nenhum sufixo: retorna como está

-- Parseia um átomo: caractere literal ou subexpressão entre parênteses
parseAtom :: String -> ParseResult Regex
parseAtom ('(':rest) = do
  (e, rest2) <- parseExpr rest          -- parseia a subexpressão interna
  case rest2 of
    (')':rest3) -> Right (e, rest3)     -- consome o ')' de fechamento
    _           -> Left "Parêntese de fechamento esperado"
parseAtom [] = Left "Fim inesperado da entrada"  -- string acabou sem um átomo
parseAtom (c:rest) = Right (RChar c, rest)       -- caractere literal

-- =============================
-- Construção de Thompson (Regex → NFA-ε)
-- Cada sub-regex gera um fragmento de NFA com exatamente:
--   - um estado de entrada (fragStart)
--   - um estado de saída (fragEnd)
--   - uma lista de transições (fragTrans)
-- Os estados são identificados por inteiros crescentes.
-- =============================

-- Fragmento de NFA produzido por Thompson
data NFAFrag = NFAFrag
  { fragStart :: Int                   -- ID do estado de entrada do fragmento
  , fragEnd   :: Int                   -- ID do estado de saída do fragmento
  , fragTrans :: [(Int, String, Int)]  -- transições brutas: (origem, símbolo, destino)
  } deriving (Show)

-- Constrói recursivamente o NFA-ε a partir da AST da regex.
-- Recebe o próximo ID de estado livre (n) e retorna o fragmento + novo próximo ID.
build :: Regex -> Int -> (NFAFrag, Int)

-- Literal 'c': dois estados, uma transição no símbolo [c]
--   n --[c]--> n+1
build (RChar c) n =
  ( NFAFrag n (n+1) [(n, [c], n+1)]
  , n+2 )

-- Epsilon: dois estados, uma transição epsilon
--   n --[ε]--> n+1
build REpsilon n =
  ( NFAFrag n (n+1) [(n, "epsilon", n+1)]
  , n+2 )

-- Concatenação r1·r2: liga o fim de r1 ao início de r2 via epsilon
--   [r1.start --> r1.end] --ε--> [r2.start --> r2.end]
build (RConcat r1 r2) n =
  let (f1, n1) = build r1 n          -- constrói r1 a partir do estado n
      (f2, n2) = build r2 n1         -- constrói r2 a partir do próximo ID disponível
      bridge   = (fragEnd f1, "epsilon", fragStart f2)  -- ponte epsilon entre r1 e r2
      trans    = fragTrans f1 ++ [bridge] ++ fragTrans f2
  in ( NFAFrag (fragStart f1) (fragEnd f2) trans
     , n2 )

-- União r1|r2: novo estado inicial com ε para cada sub-NFA;
-- cada sub-NFA tem ε para o novo estado final.
--         ε→ [r1] →ε
--  start →              → end
--         ε→ [r2] →ε
build (RUnion r1 r2) n =
  let start    = n      -- novo estado inicial único
      end      = n+1    -- novo estado final único
      (f1, n1) = build r1 (n+2)   -- constrói r1 depois dos dois novos estados
      (f2, n2) = build r2 n1      -- constrói r2 depois de r1
      trans    = [ (start,      "epsilon", fragStart f1)  -- start → início de r1
                 , (start,      "epsilon", fragStart f2)  -- start → início de r2
                 , (fragEnd f1, "epsilon", end)           -- fim de r1 → end
                 , (fragEnd f2, "epsilon", end)           -- fim de r2 → end
                 ] ++ fragTrans f1 ++ fragTrans f2
  in ( NFAFrag start end trans
     , n2 )

-- Fecho de Kleene r*: 0 ou mais repetições.
-- Novo início pode pular direto para o fim (0 reps) ou entrar em r.
-- O fim de r pode voltar ao início de r (mais reps) ou sair para o fim.
--  start →ε→ [r] →ε→ (loop back) e →ε→ end
--  start →ε→ end  (0 repetições)
build (RStar r) n =
  let start  = n      -- novo estado inicial
      end    = n+1    -- novo estado final
      (f, n1) = build r (n+2)   -- constrói o corpo de r após os dois novos estados
      trans  = [ (start,     "epsilon", fragStart f)  -- start → r (entrar)
               , (start,     "epsilon", end)          -- start → end (0 repetições)
               , (fragEnd f, "epsilon", fragStart f)  -- fim r → início r (repetir)
               , (fragEnd f, "epsilon", end)          -- fim r → end (sair)
               ] ++ fragTrans f
  in ( NFAFrag start end trans
     , n1 )

-- Uma ou mais repetições r+: equivale a r·r*
-- Obriga pelo menos uma passagem por r antes de entrar no fecho
build (RPlus r) n = build (RConcat r (RStar r)) n

-- Opcional r?: equivale a r|ε (r ou a palavra vazia)
build (ROpt r) n = build (RUnion r REpsilon) n

-- =============================
-- Tipos Automaton (espelho de Main.hs)
-- Redefinidos aqui para manter este arquivo independente
-- =============================

-- Alias: estado e símbolo são strings
type State  = String
type Symbol = String

-- Tipos de autômato suportados
data AutomatonType = DFA | NFA | NFAE deriving (Show, Eq)

-- Uma transição: de um estado, lendo um símbolo, vai para uma lista de estados
data Transition = Transition
  { tranFrom   :: State    -- estado de origem
  , tranSymbol :: Symbol   -- símbolo consumido
  , tranTo     :: [State]  -- estados de destino (lista suporta NFA/NFAE)
  } deriving (Show, Eq)

-- Autômato completo
data Automaton = Automaton
  { autoType     :: AutomatonType  -- tipo: DFA, NFA ou NFAE
  , alphabet     :: [Symbol]       -- lista de símbolos do alfabeto (sem epsilon)
  , states       :: [State]        -- todos os estados
  , initialState :: State          -- estado inicial
  , finalStates  :: [State]        -- estados finais/aceitadores
  , transitions  :: [Transition]   -- todas as transições
  } deriving (Show, Eq)

-- =============================
-- Instâncias ToJSON (serialização para YAML)
-- Mesmo formato de Main.hs para compatibilidade
-- =============================

-- Serializa o tipo do autômato como string YAML
instance ToJSON AutomatonType where
  toJSON NFAE = "nfae"
  toJSON NFA  = "nfa"
  toJSON DFA  = "dfa"

-- Serializa uma transição como objeto YAML com campos from, symbol, to
instance ToJSON Transition where
  toJSON (Transition f s t) =
    object ["from" .= f, "symbol" .= s, "to" .= t]

-- Serializa o autômato completo como objeto YAML
instance ToJSON Automaton where
  toJSON a =
    object [ "type"          .= autoType a
           , "alphabet"      .= alphabet a
           , "states"        .= states a
           , "initial_state" .= initialState a
           , "final_states"  .= finalStates a
           , "transitions"   .= transitions a
           ]

-- =============================
-- Funções auxiliares de conversão
-- =============================

-- Converte um ID inteiro de estado para o nome canônico "qN"
stateName :: Int -> State
stateName n = "q" ++ show n

-- Percorre a AST e coleta todos os símbolos literais usados (= alfabeto da regex)
collectAlphabet :: Regex -> [Symbol]
collectAlphabet (RChar c)       = [[c]]                                          -- único símbolo
collectAlphabet REpsilon        = []                                             -- epsilon não entra no alfabeto
collectAlphabet (RConcat r1 r2) = nub (collectAlphabet r1 ++ collectAlphabet r2) -- união dos dois
collectAlphabet (RUnion  r1 r2) = nub (collectAlphabet r1 ++ collectAlphabet r2) -- idem
collectAlphabet (RStar r)       = collectAlphabet r                              -- delega para o corpo
collectAlphabet (RPlus r)       = collectAlphabet r                              -- idem
collectAlphabet (ROpt  r)       = collectAlphabet r                              -- idem

-- Agrupa transições brutas (Int, String, Int) em Transitions com to :: [State].
-- Transições com mesmo (from, symbol) são fundidas numa única Transition com
-- todos os destinos numa lista — necessário para ε-transições da União.
groupTransitions :: [(Int, String, Int)] -> [Transition]
groupTransitions trans =
  [ Transition (stateName f) sym dests
  | (f, sym) <- keys                                                        -- para cada par único (origem, símbolo)
  , let dests = nub [stateName t | (f', sym', t) <- trans, f' == f, sym' == sym]  -- coleta todos os destinos
  ]
  where
    keys = nub [(f, sym) | (f, sym, _) <- trans]  -- todos os pares (origem, símbolo) distintos

-- Converte um NFAFrag (resultado de Thompson) para o tipo Automaton de Main.hs.
-- O resultado é sempre NFAE pois Thompson gera ε-transições.
fragToAutomaton :: NFAFrag -> Regex -> Automaton
fragToAutomaton frag regex =
  Automaton
    { autoType     = NFAE                                    -- Thompson sempre produz NFA-ε
    , alphabet     = sort (collectAlphabet regex)            -- alfabeto ordenado, sem epsilon
    , states       = map stateName allStateIds               -- nomes dos estados (qN)
    , initialState = stateName (fragStart frag)              -- estado inicial do fragmento
    , finalStates  = [stateName (fragEnd frag)]              -- Thompson tem exatamente 1 estado final
    , transitions  = groupTransitions (fragTrans frag)       -- transições agrupadas por (from, symbol)
    }
  where
    -- Coleta todos os IDs de estado mencionados em qualquer transição (mais início e fim)
    allStateIds = sort . nub $
      [fragStart frag, fragEnd frag]            ++   -- estados extremos do fragmento
      [s | (s, _, _) <- fragTrans frag]         ++   -- origens das transições
      [t | (_, _, t) <- fragTrans frag]              -- destinos das transições

-- =============================
-- MAIN
-- Lê a regex e o arquivo de saída da linha de comando,
-- parseia a regex, aplica Thompson, e salva o NFA-ε em YAML.
-- O YAML gerado é compatível com Main.hs para continuar a pipeline
-- (removeEpsilon → subsetConstruction → DFA).
-- =============================

main :: IO ()
main = do
  -- Lê os argumentos passados na linha de comando
  args <- getArgs
  case args of
    -- Espera exatamente: a string da regex e o arquivo de saída YAML
    [regexStr, output] -> do
      case parseRegex regexStr of
        -- Parse falhou: exibe a mensagem de erro de sintaxe
        Left err -> putStrLn ("Erro de sintaxe na regex: " ++ err)
        -- Parse bem-sucedido: aplica Thompson e salva o resultado
        Right regex -> do
          let (frag, totalStates) = build regex 0    -- constrói o NFA-ε a partir do estado q0
          let automaton = fragToAutomaton frag regex  -- converte para o formato Automaton
          encodeFile output automaton                 -- escreve o YAML no arquivo de saída
          putStrLn ("✅ NFA-ε gerado em: " ++ output)
          putStrLn ("   Regex    : " ++ regexStr)
          putStrLn ("   Alfabeto : " ++ show (alphabet automaton))
          putStrLn ("   Estados  : " ++ show totalStates)
          putStrLn ("   (use Main.hs para converter para DFA)")
    -- Número errado de argumentos: exibe instrução de uso
    _ -> putStrLn "Uso: ./lab1_part2 \"<regex>\" output.yaml"
