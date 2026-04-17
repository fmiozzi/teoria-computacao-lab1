main :: IO ()
main = do
    putStrLn "Iniciando programa..."
    let numeros = [1,2,3,4,9]
    let dobrados = map dobro numeros
    let somaTotal = soma dobrados
    putStrLn ("Resultado: " ++ show somaTotal)

dobro :: Int -> Int
dobro x = x * 2

soma :: [Int] -> Int
soma xs = foldl (+) 0 xs