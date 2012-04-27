module Sat3 where

import MiniSat

--------------------------------------------------------------------------------

data Lit3 = Lit3{ isFalse :: Lit, isTrue :: Lit }

neg3 :: Lit3 -> Lit3
neg3 (Lit3 f t) = Lit3 t f

newLit3 :: Solver -> IO Lit3
newLit3 s =
  do a <- newLit s
     b <- newLit s
     addClause s [neg a, neg b]
     return (Lit3 a b)

newLit2 :: Solver -> IO Lit3
newLit2 s =
  do a <- newLit s
     return (Lit3 a (neg a))

--------------------------------------------------------------------------------

modelValue3 :: Solver -> Lit3 -> IO (Maybe Bool)
modelValue3 s = val3 (modelValue s)

value3 :: Solver -> Lit3 -> IO (Maybe Bool)
value3 s = val3 (value s)

val3 :: (Lit -> IO (Maybe Bool)) -> Lit3 -> IO (Maybe Bool)
val3 get (Lit3 f t) =
  do mf <- get f
     case mf of
       Just True -> do return (Just False)
       _         -> do mt <- get t
                       case mt of
                         Just True -> return (Just True)
                         _         -> return Nothing

--------------------------------------------------------------------------------