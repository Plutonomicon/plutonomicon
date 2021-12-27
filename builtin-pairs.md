# Working with Builtin Pairs
This document serves as a guide for working with Plutus Core builtin pairs. It's primarily meant for Pluto and Plutarch developers.

- [Working with Builtin Pairs](#working-with-builtin-pairs)
  - [`FstPair`](#fstpair)
    - [Pluto Usage](#pluto-usage)
    - [Plutarch Usage](#plutarch-usage)
  - [`SndPair`](#sndpair)
    - [Pluto Usage](#pluto-usage-1)
    - [Plutarch Usage](#plutarch-usage-1)
  - [`MkPairData`](#mkpairdata)
    - [Pluto Usage](#pluto-usage-2)
    - [Plutarch Usage](#plutarch-usage-2)
  - [Extra stuff](#extra-stuff)
- [Useful Links](#useful-links)

For using and operating on builtin pairs, all you need are a few builtin functions. These are discussed below.
## `FstPair`
Here's the synonym to Haskell's `fst`! Its type looks like- `FstPair :: forall a b. BuiltinPair a b -> a`. It takes *two* forces, which you may already have known from [Builtin Function Reference](./builtin-functions.md). You force it twice, and pass in a builtin pair, and you get the first element of the pair.

### Pluto Usage
You can call `FstPair` as you would any other function, just make sure you force it!
```hs
! ! FstPair p
```
Where `p` is a builtin pair.

### Plutarch Usage
Plutarch has a synonym to `FstPair`, `pfstBuiltin` (`Plutarch.Builtin`)-
```hs
pfstBuiltin :: Term s (PBuiltinPair a b :--> a)
pfstBuiltin = phoistAcyclic $ pforce $ pforce $ punsafeBuiltin PLC.FstPair
```

You would use it like any other Plutarch level function.
```hs
pfstBuiltin # p
```
Where `p` is of type `PBuiltinPair a b`.

## `SndPair`
We can't just have `FstPair` without `SndPair` now, can we? Its type looks like `SndPair :: forall a b. BuiltinPair a b -> b`. It also takes *two* forces. You force it twice, and pass in a builtin pair, and you get the second member.

### Pluto Usage
You can call `SndPair` as you would any other function, just make sure you force it!
```hs
! ! SndPair p
```
Where `p` is a builtin pair.

### Plutarch Usage
Plutarch has a synonym to `SndPair`, `psndBuiltin` (`Plutarch.Builtin`)-
```hs
psndBuiltin :: Term s (PBuiltinPair a b :--> b)
psndBuiltin = phoistAcyclic $ pforce $ pforce $ punsafeBuiltin PLC.SndPair
```

You would use it like any other Plutarch level function.
```hs
psndBuiltin # p
```
Where `p` is of type `PBuiltinPair a b`.

## `MkPairData`
Now we get to build a pair! A pair of `Data`.

Its type looks like `MkPairData :: Data -> Data -> BuiltinPair Data Data`. It takes two `Data` elements, and returns a pair of those elements.

### Pluto Usage
You can call `MkPairData` as you would any other function.
```hs
MkPairData x y
```
Where `x` and `y` are both `data` values.

### Plutarch Usage
Plutarch does not have a `MkPairData` synonym yet, here's how you would implement it-
```hs
import Plutarch (punsafeBuiltin)
import Plutarch.Builtin (PBuiltinList)
import Plutarch.Prelude
import qualified PlutusCore as PLC

ppairDataBuiltin :: Term s (PData :--> PData :--> PBuiltinPair PData PData)
ppairDataBuiltin = punsafeBuiltin PLC.MkCons
```

You would use it like any other Plutarch level function.
```hs
ppairDataBuiltin # x # y
```
Where `x` and `y` are both of type `PData`.

## Extra stuff
Wondering how to make pairs of elements other than `Data`. Well, you won't *really* need to do that most of the time. But you can! You just need to build a constant directly.

This is not currently possible in Pluto. But if you're using Plutarch, read [Plutus Core constants](TODO: LINK).

Here's how to make the pair of integer and bytestring in Plutarch-
```hs
pf :: Integer -> ByteString -> Term s (PBuiltinPair PInteger PByteString)
pf =
  punsafeConstant . PLC.Some .
    PLC.ValueOf (PLC.DefaultUniPair PLC.DefaultUniInteger PLC.DefaultUniByteString)
```

# Useful Links
* [Builtin lists](./builtin-lists.md)
* [Builtin data](./builtin-data.md)
* [Builtin functions](./builtin-functions.md)
* [Pluto guide](TODO: LINK)
* [Plutarch guide](TODO: LINK)
* [Plutus builtin functions and types](https://staging.plutus.iohkdev.io/doc/haddock//plutus-tx/html/PlutusTx-Builtins-Internal.html)
* [Plutus Core builtin function identifiers, aka `DefaultFun`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultFun)
* [Plutus Core types, aka `DefaultUni`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultUni)
