# Staying In Bounds

## Introduction

Plutus imposes [severe size limits](fundamentals.md#Script-sizes) on objects
that exist on-chain, whether these are functions, values, or combinations of the
two. Additionally, due to the way the Plutus compiler works, _everything_ ends
up being inlined, further increasing the potential sizes of everything.
Therefore, it is important to be aware of how large your on-chain entities are,
and ensure that they don't grow too large; this is _especially_ true for library
functions, or any functionality that will be used in many places.

Finding out the exact on-chain size of any given thing is doable, but a bit
awkward. To make this easier, we have
[`plutus-size-check`](https://github.com/Liqwid-Labs/plutus-extra/tree/master/plutus-size-check),
which is a [`tasty`](https://hackage.haskell.org/package/tasty)-based support
library for testing on-chain entities for their size. It provides the ability to
test whether an entity would fit on-chain at all, or within a user-provided
size; together with
[`tasty-expected-failure`](https://hackage.haskell.org/package/tasty-expected-failure),
it can be used to discover and document sizes without requiring them to fit.

This tutorial describes how to use `plutus-size-check`, using a running example.
We also talk about several caveats of its use, allowing you to avoid common
issues that would be hard to diagnose otherwise.

## Worked example

Suppose we have the following module, defining a useful function to compute the
sum of squares:

```haskell
{-# OPTIONS_GHC -fno-specialize #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Foo (sumOfSquares) where

import Data.Kind (Type)
import PlutusTx.Prelude

{-# INLINEABLE sumOfSquares #-}
sumOfSquares :: forall (a :: Type) . 
  (MultiplicativeSemigroup a, AdditiveSemigroup a) =>
  a -> a -> a
sumOfSquares = ... -- super secret implementation
```

Since we expect this function to be used frequently, we want to know the size of
its on-chain representation. We will use `plutus-size-check` to do this.

To use `plutus-size-check` for this purpose, we need to do the following steps:

1. Compile `sumOfSquares` using the Plutus compiler to produce a `CompiledCode`.
1. Wrap the resulting `CompiledCode` into a `Script`.
1. Pass it to
   [`fitsOnChain`](https://github.com/Liqwid-Labs/plutus-extra/blob/master/plutus-size-check/src/Test/Tasty/Plutus/Size.hs#L157)
   or
   [`fitsInto`](https://github.com/Liqwid-Labs/plutus-extra/blob/master/plutus-size-check/src/Test/Tasty/Plutus/Size.hs#L177)
   to make a `TestTree`.
1. Put the resulting `TestTree` into a `tasty` runner.

To do this, you will need to create a test suite which includes the following
dependencies:

* `plutus-size-check`
* `tasty`
* `plutus-ledger-api`
* `plutus-tx`
* `plutus-tx-plugin`

You may need other Plutus libraries as well, depending on what you're testing,
but the list above is the minimum necessary. Throughout, we'll be working in a
test module, which initially starts off like so:

```haskell
module Main (main) where

main :: IO ()
main = _
```

### Compiling `sumOfSquares`

We use the `compile` quasi-quoter from `PlutusTx.TH` for this purpose. As this
produces a [typed splice][typed-splice], we need to
enable several extensions. Here is our first attempt:

```haskell
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}

module Main (main) where

import Data.Kind (Type)
import Foo (sumOfSquares)
import PlutusTx.Code (CompiledCode)
import PlutusTx.TH (compile)

main :: IO ()
main = _

-- Helpers

compiledSumOfSquares :: forall (a :: Type) . CompiledCode (a -> a -> a)
compiledSumOfSquares = $$(compile [|| sumOfSquares ||])
```

This already raises two caveats to be careful of. Firstly, the [TH staging
restriction][limitations-of-th] means
that we cannot use `compile` on a definition in the same module. This doesn't
trip us up here, but anything you want to `compile` _must_ be defined in a
different module to the one you use `compile` in. The second is more subtle: we
cannot compile the definition as-is, as it relies on a polymorphic type
variable, which will produce an error about `a` not being inlined. To avoid
this, we need to instantiate `a` to a concrete type: in our case, `Integer` will
do fine. This gives us the following revised definition:

```haskell
{-# LANGUAGE TemplateHaskell #-}

module Main (main) where

import Foo (sumOfSquares)
import PlutusTx.Code (CompiledCode)
import PlutusTx.TH (compile)

main :: IO ()
main = _

-- Helpers

compiledSumOfSquares :: CompiledCode (Integer -> Integer -> Integer)
compiledSumOfSquares = $$(compile [|| sumOfSquares ||])
```

For reasons of consistency, we should choose these 'concretifications'
carefully: picking them without some kind of system in place will definitely
create problems when comparing sizes of functions. We recommend using `Integer`
for 'concretifying' type variables where necessary.

### Wrapping into a `Script`

The next step is to produce a `Script`, which can be used by
`plutus-size-check`. For this, we use `fromCompiledCode`, which is in
`Plutus.V1.Ledger.Scripts`:

```haskell
{-# LANGUAGE TemplateHaskell #-}

module Main (main) where

import Foo (sumOfSquares)
import Plutus.V1.Ledger.Scripts (fromCompiledCode)
import PlutusTx.Code (CompiledCode)
import PlutusTx.TH (compile)

main :: IO ()
main = _

-- Helpers

compiledSumOfSquares :: CompiledCode (Integer -> Integer -> Integer)
compiledSumOfSquares = $$(compile [|| sumOfSquares ||])

testingScript :: Script
testingScript = fromCompiledCode compiledSumOfSquares
```

The term `Script` is slightly misleading in this case, as it can wrap _any_
`CompiledCode`, which doesn't necessarily have to be a 'script' in the Plutus
sense of the term.

### Making a `TestTree` and running

We can now finish the module and produce something runnable. As we don't
(currently) have any knowledge of how large `sumOfSquares` is on-chain, we'll
use `fitsOnChain` from `Test.Tasty.Plutus.Size`, which will check if it will fit
into the 16KiB limit as such.

```haskell
{-# LANGUAGE TemplateHaskell #-}

module Main (main) where

import Foo (sumOfSquares)
import Plutus.V1.Ledger.Scripts (fromCompiledCode)
import PlutusTx.Code (CompiledCode)
import PlutusTx.TH (compile)
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.Plutus.Size (fitsOnChain)

main :: IO ()
main = defaultMain . testGroup "On-chain size" $ [
  fitsOnChain "sumOfSquares" testingScript
  ]

-- Helpers

compiledSumOfSquares :: CompiledCode (Integer -> Integer -> Integer)
compiledSumOfSquares = $$(compile [|| sumOfSquares ||])

testingScript :: Script
testingScript = fromCompiledCode compiledSumOfSquares
```

To save some space, we can inline `testingScript` as well:

```haskell
{-# LANGUAGE TemplateHaskell #-}

module Main (main) where

import Foo (sumOfSquares)
import Plutus.V1.Ledger.Scripts (fromCompiledCode)
import PlutusTx.Code (CompiledCode)
import PlutusTx.TH (compile)
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.Plutus.Size (fitsOnChain)

main :: IO ()
main = defaultMain . testGroup "On-chain size" $ [
  fitsOnChain "sumOfSquares" . fromCompiledCode $ compiledSumOfSquares
  ]

-- Helpers

compiledSumOfSquares :: CompiledCode (Integer -> Integer -> Integer)
compiledSumOfSquares = $$(compile [|| sumOfSquares ||])
```

We now have a runnable test suite. This will produce output similar to what's
below, except for the size (which is fictionalized):

```
On-chain size
  sumOfSquares fits on-chain:                     OK
    Size: 1001B (~1KiB)
```

Now that we have a measurement, we can 'pin it in place' to avoid size
regressions, using `fitsInto`:

```haskell
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

module Main (main) where

import Foo (sumOfSquares)
import Plutus.V1.Ledger.Scripts (fromCompiledCode)
import PlutusTx.Code (CompiledCode)
import PlutusTx.TH (compile)
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.Plutus.Size (fitsInto, bytes)

main :: IO ()
main = defaultMain . testGroup "On-chain size" $ [
  fitsInto "sumOfSquares" [bytes| 1001 |] . fromCompiledCode $ compiledSumOfSquares
  ]

-- Helpers

compiledSumOfSquares :: CompiledCode (Integer -> Integer -> Integer)
compiledSumOfSquares = $$(compile [|| sumOfSquares ||])
```

Now, if we refactor or modify `sumOfSquares` in a way that exceeds this size,
our tests will fail, indicating the current size in the process.

## Common caveats, issues and solutions

### TH staging restriction

This is a limitation of the Plutus compiler and GHC both; the former relies on
[typed splices][typed-splice], and the latter has the [staging
restriction][limitations-of-th]. What this means in practice is that code such
as the following will _not_ compile:

```haskell
foo :: Integer -> Integer
foo = ... -- some definition

compiledFoo :: CompiledCode (Integer -> Integer)
compiledFoo = $$(compile [|| foo ||])
```

To solve this, place `foo` in a separate module to `compiledFoo`.

### Polymorphic compiles

This is also a limitation of the Plutus compiler. Consider the code below:

```haskell
-- This won't work
compiledBar :: CompiledCode (a -> a -> a)
compiledBar = $$(compile [|| someThing ||])
```

This code will fail to get through the Plutus compiler, complaining about `a`
not being inlined. To avoid this problem, ensure that you 'concretify' your type
variables like so:

```haskell
-- Fixed
compiledBar :: CompiledCode (Integer -> Integer -> Integer)
compiledBar = $$(compile [|| someThing ||])
```

If you plan to compare function sizes amongst each other, be consistent with
your choice of 'concretification' type. We recommend using `Integer` if you have
no better choice available.

### Applying arguments to compiled functions

Some tests require 'compositional' data, where functions need to have 'baked in'
arguments provided by non-constants. This is common when testing
validators or minting policies that take arguments beyond their datum and/or
redeemer. The 'obvious' way of doing this can yield compilation problems:

```haskell
-- Assume bar :: Integer -> Integer -> Integer and baz :: Integer
-- Both of these are defined out-of-module
compiledFoo :: CompiledCode (Integer -> Integer)
compiledFoo = $$(compile [|| bar baz ||]) -- This will likely not compile
```

If this is the case, you need to use `applyCode` from `PlutusTx.Code`:

```haskell
compiledBaz :: CompiledCode Integer
compiledBaz = $$(compile [|| baz ||])

compiledBar :: CompiledCode (Integer -> Integer -> Integer)
compiledBar = $$(compile [|| bar ||])

compiledFoo :: CompiledCode (Integer -> Integer)
compiledFoo = compiledBar `applyCode` compiledBaz
```

This is a limitation of the Plutus compiler, as well as a requirement of the
size-measuring interface provided by Plutus (which must be given
`CompiledCode`).

### Expected failures

Sometimes, you may have on-chain entities whose sizes are too large to fit
on-chain, or into a specific limit, but you want to track their sizes in a
testable way. Usually, this is needed for future-proofing or simply to find out
what the size actually is at the moment. The easiest way to do this is to use
`tasty-expected-failure`:

```haskell
import Test.Tasty.ExpectedFailure (expectFail)

myBrokenSizeTests :: TestTree
myBrokenSizeTests = testGroup "Some of these break" [
  expectFail . fitsOnChain "Too big" . fromCompiledCode $ something,
  fitsOnChain "But this is OK" . fromCompiledCode $ somethingElse,
  ...
```

## Conclusion

Using `plutus-size-check`, we can ensure that our on-chain entities will fit
into the limits imposed by Plutus, and protect against regressions in the size
of functionality. This is particularly critical when defining functionality that
will be used in many places, due to Plutus' prolific inlining requirements.
While this is not without its limitations, this guide specifies how to avoid
them, while still getting the ability to test script size with confidence.

## Further reading

* Mark Karpov's [Template Haskell
  tutorial](https://markkarpov.com/tutorial/th.htm)
* [Fundamentals of Plutus](fundamentals.md)
* [Techniques](optimisations.md) for script size reduction

[typed-splice]: https://markkarpov.com/tutorial/th.html#typed-expressions
[limitations-of-th]: https://markkarpov.com/tutorial/th.html#limitations-of-th
