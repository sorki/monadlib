module Monad.Prelude (module Monad.Prelude, module Monad) where

import Monad

-- | The class of monad transformers.
class Trans t where

  -- | Lift a computation in the underlying monad, to the constructed monad.
  lift             :: Monad m => m a -> t m a


-- | Provides means to execute a computation in the base of
-- a tower of monads.
class (Monad m, Monad b) => BaseM m b | m -> b where
  inBase           :: b a -> m a

instance BaseM IO IO where inBase x = x
instance BaseM [] [] where inBase x = x
instance BaseM Maybe Maybe where inBase x = x



-- | Monads that provide access to a context.
class Monad m => ReaderM m r | m -> r where
  
  -- | Get the value of the context.
  get              :: m r

  -- | Modify the context for the duration of a computation.
  local            :: (r -> r) -> m a -> m a


-- | Set the context to a particular value for the duration of a computation.
letLocal           :: ReaderM m r => r -> m a -> m a
letLocal r m        = local (\_ -> r) m         


-- | Monads that can perform output.
class Monad m => WriterM m w | m -> w where

  -- | Add a value to the output.
  put              :: w -> m ()


-- | Monads that can perform output, and it is possible to gather the output of a subcomputation. 
class WriterM m w => TakeWriterM m w | m -> w where
  takeFrom         :: m a -> m (a,w)

-- | 'mapBuffer f m' is a computation that behaves as 'm', 
-- except that its output is modified by 'f'.  Note that 
-- any output produced by 'f' will appear /before/ any of the output of 'm'.
mapBuffer          :: TakeWriterM m w => (w -> m w) -> m a -> m a
mapBuffer f m       = do ~(a,w) <- takeFrom m
                         put =<< f w
                         return a 



-- | Monads that can manipulate state.
class Monad m => StateM m s | m -> s where

  -- | Get the value of the state.
  peek             :: m s

  -- | Set the value of the state.  Returns the old state.
  poke             :: s -> m s

-- | Update the value of the state.  Returns the old state.
update             :: StateM m s => (s -> s) -> m s
update f            = do x <- peek
                         poke (f x)
                         return x

update_            :: StateM m s => (s -> s) -> m ()
update_ f           = update f >> return ()

poke_              :: StateM m s => s -> m ()
poke_ s             = poke s >> return ()


-- | Monads that can throw and catch exceptions.
class Monad m => ExceptM m e | m -> e where

  -- | Raise an exception.
  raise            :: e -> m a

  -- | Execute a computation in the context of a handler.
  -- If an exception occurs the handler is invoked.
  handle           :: m a -> (e -> m a) -> m a


-- | Install an error handler that ignores the exception.
-- | The handler is the second argument.
handle_            :: ExceptM m e => m a -> m a -> m a
handle_ m h         = m `handle` \_ -> h


-- | Monads that allow for explicit handling of continuations.
class Monad m => ContM m where

  -- | Capture the current continuation.
  callcc           :: ((a -> m b) -> m a) -> m a


-- | Like '(=<<'), but we need to compute to get the first function.
(<##)              :: Monad m => m (a -> m b) -> m a -> m b
mf <## mx           = do f <- mf
                         x <- mx
                         f x


-- | Like 'map', but we need to compute to get the first function.
(<#)               :: Monad m => m (a -> b) -> m a -> m b
mf <# mx            = do f <- mf
                         x <- mx
                         return (f x)

-- | A convenient name for 'map'.
( # )              :: Monad m => (a -> b) -> m a -> m b
f # mx              = do x <- mx
                         return (f x)

-- | Kleisli composition.  Composes two effectful functions.
(@@)               :: Monad m => (b -> m c) -> (a -> m b) -> (a -> m c)
(g @@ f) x          = g =<< f x



-- | A monadic version of 'concatMap'.
concatMapM         :: Monad m => (a -> m [b]) -> [a] -> m [b]
concatMapM f        = liftM concat . mapM f

-- | A monadic version of 'partition'.
-- The test happens before checking the rest of the list.
partitionM         :: Monad m => (a -> m Bool) -> [a] -> m ([a],[a])
partitionM p []     = return ([],[])
partitionM p (a:as) = do b <- p a 
                         (xs,ys) <- partitionM   p as
                         return (if b then (a:xs,ys) else (xs,a:ys))

-- | Combine 3 lists using a monadic funciton.
zipWith3M          :: Monad m => (a -> b -> c -> m d) -> [a] -> [b] -> [c] -> m [d]
zipWith3M f [] _ _                = return []
zipWith3M f _ [] _                = return []
zipWith3M f _ _ []                = return []
zipWith3M f (x:xs) (y:ys) (z:zs)  = (:) # f x y z <# zipWith3M f xs ys zs

zipWith3M_         :: Monad m => (a -> b -> c -> m d) -> [a] -> [b] -> [c] -> m ()
zipWith3M_ f [] _ _                 = return ()
zipWith3M_ f _ [] _                 = return ()
zipWith3M_ f _ _ []                 = return ()
zipWith3M_ f (x:xs) (y:ys) (z:zs)   = f x y z >> zipWith3M_ f xs ys zs


-- | Apply a monadic function to each element in a container.
-- In theory speak, this is a class that identifies functors which
-- distribute over all monads.
class ForEach f where
  forEach          :: Monad m => f a -> (a -> m b) -> m (f b)

instance ForEach [] where
  forEach xs f      = mapM f xs

instance ForEach Maybe where
  forEach Nothing f   = return Nothing
  forEach (Just x) f  = Just # f x

forEach_           :: (Monad m, ForEach f) => f a -> (a -> m b) -> m ()
forEach_ xs f       = forEach xs f >> return ()






                          
                     

