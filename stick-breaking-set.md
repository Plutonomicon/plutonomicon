# Stick Breaking Set

So you want on chain proof of presence/absence in a set? This structure lets you do that for fixed length Bytestring keys.

This is based on ideas from [Radix Tree,Patricia Tree,Trie].

```Haskell
datum = Node { prefix :: BuiltinByteString, leaves :: [BuiltinByteString], branches :: BuiltinByteString]}
```

For each leaf (prefix <> leaf) is a member of the set
For each branch there exists a NodeDatum with prefix == (prefix <> branch).

Proof that a ByteString is contained in the set involves witnessing a node containing a leaf such that (prefix <> leaf) == ByteString.

Proof that a ByteString is not contained in the set involves witnessing a node such that insertion of the ByteString would involve breaking a leaf or breaking a branch prefix.

Define breaking: when the longest common prefix of the ByteString to be inserted and a leaf/branch is longer than the prefix of the node and in the case of branches shorter than the branch.

Insertion involves either

- Adding a ByteString to a node's leaves - this can be done if and only if the longest common prefix of the ByteString with all of the leaves and branches is exactly the prefix of the Node.
- Breaking a leaf - this involves proving that the longest common prefix of the ByteString and some leaf is longer than the prefix of the node. The leaf is deleted, the overlap is added to the branches and a new node is created with prefix==(prefix <> overlap) that is referenced from the original node. The new node contains the broken leaf and the inserted ByteString.
- Breaking a branch - this involves proving that the longest common prefix of the ByteString and a branch is longer than the prefix of the node and shorter than (prefix <> branch). If this is the case we can create a new node with prefix==(prefix <> overlap) and replace the broken branch with a reference to this new node. The new node contains the inserted ByteString as a single leaf and the broken branch as a singleton branch.


The largest Node that can be created is the one where the prefix is the empty ByteString and there is a leaf for each unique single byte prefix. For 32bit fixed length ByteStrings this should be around 8Kb plus some overhead for constructors. At this point if another Bytestring is inserted it will break a Leaf at some point and the shared prefix will become a branch - reducing the size.

Here is a mock demonstrating that this structure does have the properties of a set. It uses String and splits on Char but the mechanism of insertion is the same.

```Haskell
import Control.Monad (foldM, join)
import Data.Kind (Type)
import Data.List (isPrefixOf)
import Data.Map qualified as M
import Data.Set qualified as S
import Hedgehog (
  Group (..),
  MonadGen,
  Property,
  footnoteShow,
  forAll,
  property,
  (===),
 )
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Safe (maximumMay)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (fromGroup)
import Prelude

mockStickBreakingSetTests :: TestTree
mockStickBreakingSetTests = testGroup "StickBreakingSet" [fromGroup $ Group "tests" [("is a set", mockSetIsASet)]]

-- this will be in a datum of a UTXO
data Node = Node
  { prefix :: String
  , leafs :: [String]
  , branches :: [String]
  }
  deriving (Show)

newtype MockSet = MockSet (M.Map String Node)
  deriving (Show)

mockEmpty :: MockSet
mockEmpty = MockSet (M.singleton "" (Node "" [] []))


mockContains :: MockSet -> String -> Either String Bool
mockContains (MockSet m) s =
  let longestSharedPrefix = longest $ filter (`elem` M.keys m) ((s %) <$> M.keys m)
   in case M.lookup longestSharedPrefix m of
        Nothing -> Left "malformed set"
        Just so -> Right $ drop (length (prefix so)) s `elem` leafs so

mockInsert :: MockSet -> String -> Either String MockSet
mockInsert ms s | Right True == mockContains ms s = Right ms
mockInsert (MockSet m) s =
  let longestSharedPrefix = longest $ filter (`elem` M.keys m) ((s %) <$> M.keys m)
   in case M.lookup longestSharedPrefix m of
        Nothing -> Left "malformed set"
        Just so ->
          let wop = drop (length (prefix so)) s
           in case longest ((wop %) <$> leafs so) of
                "" ->
                  case longest ((wop %) <$> branches so) of
                    -- The case where the insert goes into an existing node
                    "" -> Right $ MockSet (M.insert longestSharedPrefix (so {leafs = drop (length longestSharedPrefix) s : leafs so}) m)
                    e ->
                      -- The case where a branch is broken
                      --  - it is replaced with base of the branch containing the inserted node and the tip of the branch
                      let rmd = M.insert longestSharedPrefix (so {branches = e : filter (not . isPrefixOf e) (branches so)}) m
                          np = longestSharedPrefix <> e
                          w = head $ filter (isPrefixOf e) (branches so)
                       in Right $ MockSet (M.insert np (Node np [drop (length np) s] [drop (length e) w]) rmd)
                e ->
                  -- The case where a leaf is broken
                  -- - it is deleted and the common prefix with the inserted element becomes a branch containing
                  --   the broken leaf and the inserted element
                  let rmd = M.insert longestSharedPrefix (so {leafs = filter (not . isPrefixOf e) (leafs so), branches = e : branches so}) m
                      np = longestSharedPrefix <> e
                      w = head $ filter (isPrefixOf e) (leafs so)
                   in Right $ MockSet (M.insert np (Node np [drop (length e) w, drop (length np) s] []) rmd)

mockAsList :: MockSet -> [String]
mockAsList (MockSet m) = join [(p <>) <$> ls | Node p ls _ <- snd <$> M.toList m]

mockFromSet :: S.Set String -> Either String MockSet
mockFromSet s = foldM mockInsert mockEmpty $ S.toList s

genSetOfStrings ::
  forall (m :: Type -> Type).
  MonadGen m =>
  m (S.Set String)
genSetOfStrings = do
  l <- Gen.list (Range.linear 0 100) (Gen.string (Range.singleton 32) Gen.alphaNum)
  pure $ S.fromList l

mockSetIsASet :: Property
mockSetIsASet =
  property $ do
    s <- forAll genSetOfStrings
    let mock = mockFromSet s
    footnoteShow mock
    Right s === (S.fromList . mockAsList <$> mock)

-- shared prefix of a String e.g.  "apple" % "apply" = "appl"
(%) :: String -> String -> String
(c : x) % (d : y) | c == d = c : x % y; _ % _ = ""

longest :: [String] -> String
longest xss = maybe "" snd (maximumMay [(length xs, xs) | xs <- xss])


```
