-- Parse little bits of TPTP, e.g. a prelude for a particular tool.

{-# LANGUAGE CPP #-}
module Jukebox.TPTP.ParseSnippet where

import Jukebox.TPTP.Parse.Core as TPTP.Parse.Core
import Jukebox.TPTP.Parsec as TPTP.Parsec
import Jukebox.TPTP.Lexer
import Jukebox.Name
import Jukebox.Form hiding (run_)
import qualified Data.Map.Strict as Map
import Data.List
#if __GLASGOW_HASKELL__ < 710
import Control.Applicative
#endif

tff, cnf :: [(String, Type)] -> [(String, Function)] -> String -> Form
tff = form TPTP.Parse.Core.tff
cnf = form TPTP.Parse.Core.cnf

form :: Symbolic a => Parser a -> [(String, Type)] -> [(String, Function)] -> String -> a
form parser types funs0 str =
  case run_ (parser <* eof)
            (UserState (MkState Nothing [] (Map.delete "$i" (Map.fromList types)) (Map.fromList funs) Map.empty 0) (scan str)) of
    Ok (UserState (MkState _ _ types' funs' _ _) (At _ (Cons Eof _))) res
      | Map.insert "$i" indType (Map.fromList types) /=
        Map.insert "$i" indType types' ->
        error $ "ParseSnippet: type implicitly defined: " ++
                show (map snd (Map.toList types' \\ types))
      | Map.fromList funs /= funs' ->
        error $ "ParseSnippet: function implicitly defined: " ++
                show (map snd (Map.toList funs' \\ funs))
      | otherwise -> mapType elimI res
    Ok{} -> error "ParseSnippet: lexical error"
    TPTP.Parsec.Error _ msg -> error $ "ParseSnippet: parse error: " ++ msg
    Expected _ exp -> error $ "ParseSnippet: parse error: expected " ++ show exp

  where
    funs = map (mapFunType introI) funs0

    mapFunType f (xs, name ::: FunType args res) =
      (xs, [name ::: FunType (map f args) (f res)])

    elimI =
      case lookup "$i" types of
        Nothing -> id
        Just i ->
          \ty -> if ty == indType then i else ty
    introI =
      case lookup "$i" types of
        Nothing -> id
        Just i ->
          \ty -> if ty == i then indType else ty
