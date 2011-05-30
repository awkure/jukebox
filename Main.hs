module Main where

import TPTP.ParseProblem
import System.Environment
import Formula

main = do
  [arg] <- getArgs
  res <- parseProblem arg
  case res of
    Left err -> print err
    Right p -> putStrLn $ "ok, " ++ show (length (inputs p)) ++ " clauses"
