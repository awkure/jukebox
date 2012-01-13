{-# LANGUAGE GADTs, PatternGuards #-}
module GuessModel where

import Control.Monad
import qualified Data.ByteString.Char8 as BS
import Name
import Form
import Clausify hiding (cnf)
import TPTP.Print
import TPTP.ParseSnippet
import Utils

ind :: Symbolic a => a -> Type
ind x =
  case filter (/= O) (types x) of
    [ty] -> ty
    [] -> Type nameI Infinite Infinite
    _ -> error "ProgramModel: can't deal with many-typed problems"

annotate :: Problem Form -> Problem Form
annotate prob = close prob $ \forms -> do
  let i = ind forms
  zero <- newFunction "zero" [] i
  succ <- newFunction "succ" [i] i
  pred <- newFunction "pred" [i] i
  let types = [("$i", i)]
      funs = [("zero", zero),
              ("succ", succ),
              ("pred", pred)]
      constructors = [zero, succ]
  
  prelude <- mapM (cnf types funs) [
    "zero != succ(X)",
    "X = zero | X = succ(pred(X))",
    "succ(X) != succ(Y) | X = Y"
    ]

  program <- fmap concat (mapM (function constructors) (functions forms))
  return (map (Input (BS.pack "adt") Axiom) prelude ++
          map (Input (BS.pack "program") Axiom) program ++
          forms)

function :: [Function] -> Function -> NameM [Form]
function constructors f = fmap concat $ do
  argss <- cases constructors (funArgs f)
  forM argss $ \args -> do
    let theRhss = rhss constructors args f
    alts <- forM theRhss $ \rhs -> do
      pred <- newFunction (prettyShow rhs) [] O
      return (Literal (Pos (Tru (pred :@: []))))
    return $
      disj alts:
      [ closeForm (Connective Implies alt rhs)
      | (alt, rhs) <- zip alts theRhss ]

rhss :: [Function] -> [Term] -> Function -> [Form]
rhss constructors args f =
  case typ f of
    O ->
      Literal (Pos (Tru (f :@: args))):
      Literal (Neg (Tru (f :@: args))):
      map (f :@: args .=.) (map (f :@:) (recursive args))
    _ ->
      map (f :@: args .=.) . usort $
        map (f :@:) (recursive args) ++ constructor ++ subterm
  where recursive [] = []
        recursive (a:as) = reduce a ++ map (a:) (recursive as)
          where reduce (f :@: xs) = [ x:as' | x <- xs, as' <- as:recursive as ]
                reduce _ = []
        
        constructor = [ c :@: xs
                      | c <- constructors,
                        xs <- sequence (replicate (arity c) subterm) ]
        
        subterm = terms args

cases :: [Function] -> [Type] -> NameM [[Term]]
cases constructors [] = return [[]]
cases constructors (ty:tys) = do
  ts <- cases1 constructors ty
  tss <- cases constructors tys
  return (liftM2 (:) ts tss)

cases1 :: [Function] -> Type -> NameM [Term]
cases1 constructors ty = do
  let maxArity = maximum (map arity constructors)
      varNames = take maxArity (cycle ["X", "Y", "Z"])
  vars <- mapM (flip newSymbol ty) varNames
  return [ c :@: take (arity c) (map Var vars)
         | c <- constructors ]