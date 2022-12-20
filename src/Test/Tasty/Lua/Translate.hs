{-|
Module      : Test.Tasty.Lua.Translate
Copyright   : © 2019–2020 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <albert+hslua@zeitkraut.de>
Stability   : alpha
Portability : Requires GHC

Translate test results from Lua into a Tasty @'TestTree'@.
-}
module Test.Tasty.Lua.Translate
  ( translateResultsFromFile
  , pathFailure
  )
where

import Foreign.Lua (Lua)
import Test.Tasty.Lua.Core (Outcome (..), ResultTree (..), UnnamedTree (..),
                            runTastyFile)
import qualified Test.Tasty as Tasty
import qualified Test.Tasty.Providers as Tasty

-- | Run tasty.lua tests from the given file and translate the result
-- into a mock Tasty @'TestTree'@.
translateResultsFromFile :: FilePath -> Lua Tasty.TestTree
translateResultsFromFile fp = do
  result <- runTastyFile fp
  case result of
    Left errMsg -> return $ pathFailure fp errMsg
    Right tree  -> return $ Tasty.testGroup fp (map testTree tree)

-- | Report failure of testing a path.
pathFailure :: FilePath -> String -> Tasty.TestTree
pathFailure fp errMsg = Tasty.singleTest fp (MockTest (Failure errMsg))

-- | Convert internal (tasty.lua) result tree format into Tasty tree.
testTree :: ResultTree -> Tasty.TestTree
testTree (ResultTree name tree) =
  case tree of
    SingleTest outcome -> Tasty.singleTest name (MockTest outcome)
    TestGroup results  -> Tasty.testGroup name (map testTree results)

-- | Mock test which just returns the predetermined outcome. An
-- @'Outcome'@ can be treated like a Tasty test, as it encodes all
-- necessary information. Usually, calling @'run'@ would trigger the
-- execution of the test, but in this case, the test has already been
-- run when the Lua script was executed.
newtype MockTest = MockTest Outcome

instance Tasty.IsTest MockTest where
  run _ (MockTest outcome) _ = return $ case outcome of
    Success     -> Tasty.testPassed ""
    Failure msg -> Tasty.testFailed msg

  testOptions = return []


