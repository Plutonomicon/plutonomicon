# User guide for `plutus-numeric`

## Introduction

We give examples of common uses of the types and functions defined in `plutus-numeric`, as well as some explanations for how to do 'typical' tasks. In particular, we cover use of:

* `Natural` (from `PlutusTx.Natural`)
* `NatRatio` (from `PlutusTx.NatRatio`)

## Construction

### Compile-time constants

To create values known at compile-time, use the quasi-quoters provided in `PlutusTx.Natural` and `PlutusTx.NatRatio`. For `Natural`, there is one quasi-quoter:

```haskell
{-# LANGUAGE QuasiQuotes #-}

module Example.Natural where

import PlutusTx.Natural (Natural, nat)

lifeTheUniverseAndEverything :: Natural
lifeTheUniverseAndEverything = [nat | 42 |]

-- You can use underscore as a separator
billion :: Natural
billion = [nat| 1_000_000_000 |]
```

For `NatRatio`, there are two quasi-quoters:

```haskell
{-# LANGUAGE QuasiQuotes #-}

module Example.NatRatio where

import PlutusTx.NatRatio (NatRatio, dec, frac)

-- frac uses a numerator-denominator pair
oneHalf :: NatRatio
oneHalf = [frac| (1, 2) |]

-- dec uses a decimal
oneHundredth :: NatRatio
oneHundredth = [dec| 0.01 |]
```

Lastly, both ``Natural`` and ``NatRatio`` are instances of both ``AdditiveMonoid`` and ``MultiplicativeMonoid``; thus, `zero` and `one` will work for both of them, in the expected manner.

### Runtime values

For values only known at runtime, you can convert from `Integer` or `Rational`; see the 'Conversion' section for how to do this. For `NatRatio` specifically, there is also a way of construction using two `Natural`s:

```haskell
module NatRatio.Example where

import PlutusTx.NatRatio (NatRatio, natRatio)
import PlutusTx.Natural (Natural)

numerator :: Natural
numerator = -- something

denominator :: Natural
denominator = -- something else

myRatio :: Maybe NatRatio
myRatio = natRatio numerator denominator -- will be Nothing if denominator is zero
```

## Conversion

As both `Natural` and `NatRatio` are instances of `IntegralDomain`, there is a range of ways that conversions to, and from, base Plutus types, available. 

```haskell
{-# LANGUAGE QuasiQuotes #-}

module Conversions.Example where

import PlutusTx.Natural (Natural, nat)
import PlutusTx.NatRatio (NatRatio, dec)
import PlutusTx.Numeric (addExtend, projectAbs, restrictMay)
import PlutusTx.Ratio (Ratio)
import qualified PlutusTx.Ratio as Ratio

-- Most general method, returns in a Maybe.

outOfInteger :: Maybe Natural
outOfInteger = restrictMay 1234 -- will give a Just

outOfNegativeInteger :: Maybe Natural
outOfNegativeInteger = restrictMay (-1234) -- will give Nothing

outOfRational :: Maybe NatRatio
outOfRational = restrictMay (1 Ratio.% 2) -- will give a Just

outOfNegativeRational :: Maybe NatRatio
outOfNegativeRational = restrictMay ((-1) Ratio.% 2) -- will give Nothing

-- 'Clamping' method, producing the absolute value of what it's given.

outOfIntegerAbs :: Natural
outOfIntegerAbs = projectAbs 1234 -- will give the same as [nat| 1234 |]

outOfNegativeIntegerAbs :: Natural
outOfNegativeIntegerAbs = projectAbs (-1234) -- will also give the same as [nat| 1234 |]

outOfRationalAbs :: NatRatio
outOfRationalAbs = projectAbs (1 Ratio.% 2) -- will give the same as [dec| 0.5 |]

outOfNegativeRationalAbs :: NatRatio
outOfNegativeRationalAbs = projectAbs ((-1) Ratio.% 2) -- will also give the same as [dec| 0.5 |]

-- 'Relaxes' a positive-only type into the same value in its possibly-negative counterpart

relaxNatural :: Integer
relaxNatural = addExtend [nat | 1234 |] -- same as 1234

relaxNatRatio :: Rational
relaxNatRatio = addExtend [dec | 0.2 |] -- same as 2 Ratio.% 10

```

## Operations

As both `Natural` and `NatRatio` are instances of both `AdditiveSemigroup` and `MultiplicativeSemigroup`, `+` and `*` will work as expected. Subtraction, however, can't be defined on either type: instead, we provide a _monus_ operation, which works similarly. For both `Natural` and `NatRatio`, monus (written `^-`) is a 'difference or zero' operator:

```haskell
{-# LANGUAGE QuasiQuotes #-}

module Monus.Example where

import Plutus.Numeric.Extra ((^-))
import Plutus.Natural (Natural, nat)
import Plutus.NatRatio (NatRatio, dec)

thisWillBeZero :: Natural
thisWillBeZero = [nat| 1 |] ^- [nat| 15 |]

thisWillNotBeZero :: Natural
thisWillNotBeZero = [nat| 15 |] ^- [nat| 1 |] -- will be the same as [nat| 14 |]

thisWillAlsoBeZero :: NatRatio
thisWillAlsoBeZero = [dec| 0.5 |] ^- [dec| 1.5 |]

butThisWillNot :: NatRatio
butThisWillNot = [dec| 1.5 |] ^- [dec| 0.5 |] -- will be the same as [dec| 0.5 |]
```

The laws that the monus operation follows are slightly different to those that subtraction would: check the documentation for the `AdditiveHemigroup` type class in `PlutusTx.Numeric.Extra` for details.
