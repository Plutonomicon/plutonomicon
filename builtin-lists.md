# Working with Builtin Lists
This document serves as a guide for working with Plutus Core builtin lists. It's primarily meant for Pluto users.

Plutarch **users** no longer need to know the information discussed here. Prefer [`PListLike` class methods](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md#plistlike) instead - which is implemented by [`PBuiltinList`](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md#pbuiltinlist). The information may, however, benefit Plutarch developers/contributors.

> Note: If you spot any mistakes/have any related questions that this guide lacks the answer to, please don't hesitate to raise an issue. The goal is to have high quality documentation for Pluto and Plutarch users!

- [Working with Builtin Lists](#working-with-builtin-lists)
  - [`HeadList`](#headlist)
    - [Pluto Usage](#pluto-usage)
    - [Plutarch Usage](#plutarch-usage)
  - [`TailList`](#taillist)
    - [Pluto Usage](#pluto-usage-1)
    - [Plutarch Usage](#plutarch-usage-1)
  - [`NullList`](#nulllist)
    - [Pluto Usage](#pluto-usage-2)
    - [Plutarch Usage](#plutarch-usage-2)
  - [`MkCons`](#mkcons)
    - [Pluto Usage](#pluto-usage-3)
    - [Plutarch Usage](#plutarch-usage-3)
  - [`ChooseList`](#chooselist)
    - [Pluto Usage](#pluto-usage-4)
    - [Plutarch Usage](#plutarch-usage-4)
  - [`MkNilData`](#mknildata)
    - [Pluto Usage](#pluto-usage-5)
    - [Plutarch Usage](#plutarch-usage-5)
  - [`MkNilPairData`](#mknilpairdata)
    - [Pluto Usage](#pluto-usage-6)
    - [Plutarch Usage](#plutarch-usage-6)
  - [Extra stuff - Building `nil`s](#extra-stuff---building-nils)
- [Important note on Plutus Core `nil`](#important-note-on-plutus-core-nil)
- [Useful Links](#useful-links)

For using and operating on builtin lists, all you need are a few builtin functions. These are discussed below.
## `HeadList`
Love it or hate it, here's the well known `head` synonym. A "synonym" in the sense that it shares all the perks and flaws of the `Prelude.head` we know and love (or hate)!

(I'm trying to hint at the fact that `HeadList` is indeed a partial function)

Its type looks like- `HeadList :: forall a. BuiltinList a -> a`. See that type variable? That means it takes *one* force. But [you already knew that](builtin-functions.md). You force it once, and pass in a builtin list, and you get the first element of the list (or a scary error if the list is empty). Simple!

### Pluto Usage
You can call `HeadList` as you would any other function, just make sure you force it!
```hs
! HeadList xs
```
Where `xs` is a builtin list.

### Plutarch Usage
Create a Plutarch a synonym to `HeadList` using `punsafeBuiltin`-
```hs
pheadBuiltin :: Term s (PBuiltinList a :--> a)
pheadBuiltin = phoistAcyclic $ pforce $ punsafeBuiltin PLC.HeadList
```

You would use it like any other Plutarch level function.
```hs
pheadBuiltin # xs
```
Where `xs` is of type `PBuiltinList a`.

## `TailList`
Here's `HeadList`'s twin, `TailList`. Its type looks like `TailList :: forall a. BuiltinList a -> BuiltinList a`. It also takes *one* force. You force it once, and pass in a builtin list, and you get its tail (or an error)!

### Pluto Usage
You can call `TailList` as you would any other function, just make sure you force it!
```hs
! TailList xs
```
Where `xs` is a builtin list.

### Plutarch Usage
Create a Plutarch a synonym to `TailList` using `punsafeBuiltin`-
```hs
ptailBuiltin :: Term s (PBuiltinList a :--> PBuiltinList a)
ptailBuiltin = phoistAcyclic $ pforce $ punsafeBuiltin PLC.TailList
```

You would use it like any other Plutarch level function.
```hs
ptailBuiltin # xs
```
Where `xs` is of type `PBuiltinList a`.

## `NullList`
This is synonymous to `null`. The function to check whether or not a list is empty. Its type looks like `NullList :: forall a. BuiltinList a -> BuiltinBool`. It takes *one* force, a builtin list argument, and returns `True` if the list is empty, `False` otherwise.

### Pluto Usage
You can call `NullList` as you would any other function, just make sure you force it!
```hs
! NullList xs
```
Where `xs` is a builtin list.

### Plutarch Usage
Create a Plutarch a synonym to `NullList` using `punsafeBuiltin`-
```hs
pnullBuiltin :: Term s (PBuiltinList a :--> PBool)
pnullBuiltin = phoistAcyclic $ pforce $ punsafeBuiltin PLC.NullList
```

You would use it like any other Plutarch level function.
```hs
pnullBuiltin # xs
```
Where `xs` is of type `PBuiltinList a`.

## `MkCons`
You probably expected this one from a mile (or kilometer) away. It's `:`, cons!

Its type looks like `MkCons :: forall a. a -> BuiltinList a -> BuiltinList a`. It takes *one* force, an element, and a builtin list that contains elements of **the same type**, and returns a new list with the element prepended to the old list.

### Pluto Usage
You can call `MkCons` as you would any other function, just make sure you force it!
```hs
! MkCons x xs
```
Where `x` is of type `a`, and `xs` is a builtin list of elements of type `a`.

### Plutarch Usage
Create a Plutarch a synonym to `MkCons` using `punsafeBuiltin`-
```hs
pconsBuiltin :: Term s (a -> PBuiltinList a :--> PBuiltinList a)
pconsBuiltin = phoistAcyclic $ pforce $ punsafeBuiltin PLC.MkCons
```

You would use it like any other Plutarch level function.
```hs
pconsBuiltin # x # xs
```
Where `x` is of type `a`, and `xs` is of type `PBuiltinList a`.

## `ChooseList`
Catamorphisms! Everyone loves those right? If you wrote this function in Haskell, it would look like-
```hs
chooseList :: [a] -> b -> b -> b
chooseList []    x _ = x
chooseList (_:_) _ y = y
```
It takes *two* forces, a builtin list, and two branches (both strictly evaluated, as usual), and yields a branch corresponding to the builtin list representation. If the list is empty, it returns the first branch, otherwise, the second branch.

> Aside: Wanna know something cool? In Pluto, you actually don't have to make the two branches, `a` and `b`, the same type.

### Pluto Usage
You can call `ChooseList` as you would any other function, just make sure you force it!
```hs
! ! ChooseList xs a b
```
Where `xs` is a builtin list, and `a` and `b` are the two branches.

### Plutarch Usage
Create a Plutarch a synonym to `ChooseList` using `punsafeBuiltin`-
```hs
pchooseListBuiltin :: Term s (PBuiltinList a :--> b :--> b :--> b)
pchooseListBuiltin = phoistAcyclic $ pforce $ pforce $ punsafeBuiltin PLC.ChooseList
```

You would use it like any other Plutarch level function.
```hs
pchooseListBuiltin # xs # a # b
```
Where `xs` is of type `PBuiltinList a`, and `a` and `b` are the two branches of type `b`.

## `MkNilData`
You're probably wondering, "All those functions above take in builtin lists. That's cool, but where can I get me one of these builtin lists you speak of?". Good question! Here's the first of several ways to obtain a builtin list.

`MkNilData` takes in a `BuiltinUnit` and returns an empty list (`nil`) of [`BuiltinData`/`Data`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx.html#t:Data). So, its return type is like `BuiltinList Data`.

More often than not, you'll actually be working on builtin lists of `Data`. You rarely need to use builtin lists with elements of other type (except `BuiltinPair`). Convenient!

### Pluto Usage
You can call `MkNilData` as you would any other function.
```hs
MkNilData ()
```
It will give you a `nil` list of `Data` elements.

### Plutarch Usage
Create a Plutarch a synonym to `MkNilData` using `punsafeBuiltin`-
```hs
pnilDataBuiltin :: Term s (PBuiltinList PData)
pnilDataBuiltin = punsafeBuiltin PLC.MkNilData # pcon PUnit
```

I went ahead and applied the `()` (unit) onto the function. So it's just a `nil` (of `Data` elements) now. Instead of a function that returns `nil` (of `Data` elements).

## `MkNilPairData`
Here's the function to build a builtin list of `BuiltinPair Data Data` elements! This is the second most common element type for builtin lists you'll be using on chain. It works much like `MkNilData`, pass it a `BuiltinUnit`, and it will yield an empty list (`nil`) of `BuiltinPair Data Data`. So, its return type is like `BuiltinList (BuiltinPair Data Data)`.

### Pluto Usage
You can call `MkNilPairData` as you would any other function.
```hs
MkNilPairData ()
```
It will give you a `nil` list of `BuiltinPair Data Data` elements.

### Plutarch Usage
Create a Plutarch a synonym to `MkNilPairData` using `punsafeBuiltin`-
```hs
pnilPairDataBuiltin :: Term s (PBuiltinList (BuiltinPair PData PData))
pnilPairDataBuiltin = punsafeBuiltin PLC.MkNilPairData # pcon PUnit
```

I went ahead and applied the `()` (unit) onto the function. So it's just a `nil` (of `BuiltinPair Data Data` elements) now. Instead of a function that returns `nil` (of `BuiltinPair Data Data` elements).

## Extra stuff - Building `nil`s
Let me read your mind. You're thinking, "Wait, you didn't tell me how to build a list of integers/bytestrings/strings/other pairs/lists!". The truth is that you won't *really* need to build them most of the time. But you can! You just need to build a constant directly.

This is not currently possible in Pluto. But if you're using Plutarch, read [constant building](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md#constants) and [`PLift`](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md#plift).

Here's how to make the nil for builtin lists of integers in Plutarch-
```hs
pnilIntBuiltin :: Term s (PBuiltinList PInteger)
pnilIntBuiltin = pconstant []
```
You can also build a *somewhat* polymorphic `nil`-
```hs
pnilIntBuiltin :: PLC.Contains PLC.DefaultUni (PHaskellType a) => Term s (PBuiltinList a)
pnilIntBuiltin = pconstant []
```
It only works for `DefaultUni` element types, however (i.e built in).

# Important note on Plutus Core `nil`
There is no truly polymorphic `nil` in Plutus Core. When you create a `nil` constant - you **always** explicitly choose the element type (when using `punsafeConstant` - `pconstant` does this under the hood as well). A `nil` of `DefaultUniData` element type (built using `Some $ ValueOf (DefaultUniList DefaultUniData) []`) **WILL NOT** work with builtin lists of other element types. Don't ignore that `DefaultUniList DefaultUniData` - it is preserved in the runtime!

# Useful Links
* [Builtin pairs](builtin-pairs.md)
* [Builtin data](builtin-data.md)
* [Builtin functions](builtin-functions.md)
* [Pluto guide](https://github.com/Plutonomicon/pluto/blob/main/GUIDE.md)
* [Plutarch guide](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md)
* [Plutus builtin functions and types](https://staging.plutus.iohkdev.io/doc/haddock//plutus-tx/html/PlutusTx-Builtins-Internal.html)
* [Plutus Core builtin function identifiers, aka `DefaultFun`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultFun)
* [Plutus Core types, aka `DefaultUni`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultUni)
