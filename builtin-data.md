# What is Data/BuiltinData?
This document serves as a guide for understanding and working with [`BuiltinData`/`Data`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx.html#t:Data). It's primarily meant for Pluto users and Plutarch developers/contributors.

> Note: If you spot any mistakes/have any related questions that this guide lacks the answer to, please don't hesitate to raise an issue. The goal is to have high quality documentation for Pluto and Plutarch users!

- [What is Data/BuiltinData?](#what-is-databuiltindata)
  - [What is `Constr`?](#what-is-constr)
  - [Working with `Constr`](#working-with-constr)
    - [Pluto Usage](#pluto-usage)
    - [Plutarch Usage](#plutarch-usage)
  - [Building `Constr` data](#building-constr-data)
    - [Pluto](#pluto)
    - [Plutarch](#plutarch)
  - [What is `Map`?](#what-is-map)
  - [Working with `Map`](#working-with-map)
    - [Pluto Usage](#pluto-usage-1)
    - [Plutarch Usage](#plutarch-usage-1)
  - [Building `Map` data](#building-map-data)
    - [Pluto](#pluto-1)
    - [Plutarch](#plutarch-1)
  - [What is `List`?](#what-is-list)
  - [Working with `List`](#working-with-list)
    - [Pluto Usage](#pluto-usage-2)
    - [Plutarch Usage](#plutarch-usage-2)
  - [Building `List` data](#building-list-data)
    - [Pluto](#pluto-2)
    - [Plutarch](#plutarch-2)
  - [What is `I`?](#what-is-i)
  - [Working with `I`](#working-with-i)
    - [Pluto Usage](#pluto-usage-3)
    - [Plutarch Usage](#plutarch-usage-3)
  - [Building `I` data](#building-i-data)
    - [Pluto](#pluto-3)
    - [Plutarch](#plutarch-3)
  - [What is `B`?](#what-is-b)
  - [Working with `B`](#working-with-b)
    - [Pluto Usage](#pluto-usage-4)
    - [Plutarch Usage](#plutarch-usage-4)
  - [Building `B` data](#building-b-data)
    - [Pluto](#pluto-4)
    - [Plutarch](#plutarch-4)
  - [Wild Card!](#wild-card)
    - [Pluto Usage](#pluto-usage-5)
    - [Plutarch Usage](#plutarch-usage-5)
- [Useful Links](#useful-links)

> Friendly Reminder: For general Plutarch usage, you won't *need* to use **ANY** of the methods here. There are safer interfaces provided to do that (see: [`PIsDataRepr`](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md#pisdatarepr--pdatalist), [`PAsData`](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md#pasdata)).

This is what BuiltinData looks like-
```hs
data Data
  = Constr Integer [Data]
  | Map [(Data, Data)]
  | List [Data]
  | I Integer
  | B ByteString
```

> Aside: The *direct* Plutarch synonym to `BuiltinData`/`Data` is `PData`. However, you should prefer `PAsData` as it also preserves type information. The functions you need to manually work with these are exported from `Plutarch.Builtin`.

We discuss each of these constructors, and how to work with them, in the following sections.

> Common Plutarch imports: `Plutarch`, `Plutarch.Builtin`, `qualified PlutusCore as PLC`

## What is `Constr`?
`Constr` is responsible for representing most Haskell ADTs. It's a sum of products representation. `Constr 0 []` - designates the 0th constructor with no fields. Each field is represented as a `Data` value.

For example, when you implement `IsData` for your Haskell ADT using-
```hs
import PlutusTx

data Foo = Bar Integer | Baz ByteString

PlutusTx.makeIsDataIndexed
  ''Foo
  [ ('Bar, 0),
    ('Baz, 1)
  ]
```
It essentially means that `PlutusTx.toData (Bar 42)` translates to `Constr 0 [PlutusTx.toData 42]`. Whereas `PlutusTx.toData (Baz "A")` translates to `Constr 1 [PlutusTx.toData "A"]`.

> Aside: The integer literal, list literal, and (byte-)string literals you see in that Haskell code are the Plutus Tx builtin types.

Let's look at the `IsData` implementation for the `Maybe` type-
```hs
import PlutusTx

PlutusTx.makeIsDataIndexed ''Maybe [('Just,0),('Nothing,1)]
```

This means that `PlutusTx.toData Nothing` translates to `Constr 1 []` - and `PlutusTx.toData (Just x)` translates to `Constr 0 [PlutusTx.toData x]`.

> **IMPORTANT**: newtype constructors (generally) don't persist when you do toData. Their inner value's toData result is yielded instead.

## Working with `Constr`
Now, when you receive a `BuiltinData`/`Data` inside your function - if you are sure what you have received is a `Constr` - you can work with it accordingly.

The builtin function used to take apart a `Constr` data value, is `UnConstrData`.

### Pluto Usage
```hs
-- test.pluto
UnConstrData (data sigma0.[1, 0x4d])
```
This will yield a pair, the first member of which, is an integer representing the constructor id. The second member is a list of fields associated with the constructor.
```sh
> pluto run test.pluto
Constant () (Some (ValueOf pair (integer) (list (data)) (0,[I 1,B "M"])))
```
You can extract the constructor id using `FstPair`, you must force it *twice* first-
```hs
-- test.pluto
let
  x = UnConstrData (data sigma0.[1, 0x4d])
in ! ! FstPair x
```
```sh
> pluto run test.pluto
Constant () (Some (ValueOf integer 0))
```

As you would expect, retrieving the fields is similar. All you need is `SndPair`, which also needs *two* forces.
```hs
-- test.pluto
let
  x = UnConstrData (data sigma0.[1, 0x4d])
in ! ! SndPair x
```
```sh
> pluto run test.pluto
Constant () (Some (ValueOf list (data) [I 1,B "M"]))
```
It results in a builtin list of `Data` elements. See [Working with Builtin Lists](builtin-lists.md).

How about we load it up in Haskell? Let's make a Pluto function that returns the constructor id of the given ADT!
```hs
-- test.pluto
\x -> ! ! FstPair (UnConstrData x)
```
Load it up and bind it to a variable!
```hs
plutoSc :: Script
```
```hs
> [PlutusTx.toData (Nothing :: Maybe Integer)] `evalWithArgs` plutoSc
Right (ExBudget {exBudgetCPU = ExCPU 597830, exBudgetMemory = ExMemory 1164},[],Constant () (Some (ValueOf integer 1)))
> [PlutusTx.toData (Just 1 :: Maybe Integer)] `evalWithArgs` plutoSc
Right (ExBudget {exBudgetCPU = ExCPU 597830, exBudgetMemory = ExMemory 1164},[],Constant () (Some (ValueOf integer 0)))
```

### Plutarch Usage
In Plutarch, `pasConstr` is the synonym to `UnConstrData`-
```haskell
pasConstr :: Term s (PData :--> PBuiltinPair PInteger (PBuiltinList PData))
pasConstr = punsafeBuiltin PLC.UnConstrData
```

This will yield a pair, the first member of which, is the constructor id. You can extract the constructor id using `pfstBuiltin`, which is a synonym to `FstPair`-

```haskell
pfstBuiltin :: Term s (PBuiltinPair a b :--> a)
pfstBuiltin = phoistAcyclic $ pforce . pforce . punsafeBuiltin $ PLC.FstPair
```

> Aside: Recall that `FstPair` requires 2 forces.

Here's a Plutarch function that takes in a `BuiltinData/Data`, assumes it's a `Constr`, and returns its constructor id-

```haskell
import Plutarch.Builtin
import Plutarch.Integer
import Plutarch.Prelude

constructorIdOf :: Term s (PData :--> PInteger)
constructorIdOf = plam $ \x -> pfstBuiltin #$ pasConstr # x
```

As you would expect, retrieving the fields is also trivial once you're armed with the above knowledge-

```haskell
fieldsOf :: Term s (PData :--> PBuiltinList PData)
fieldsOf = plam $ \x -> psndBuiltin #$ pasConstr # x
```

Let's test those functions!

```haskell
> constructorIdOf `evalWithArgsT` [PlutusTx.toData (Nothing :: Maybe ())]
Right (Program () (Version () 1 0 0) (Constant () (Some (ValueOf integer 1))))
```

> Aside: You can find the definition of `evalWithArgsT` above - [Compiling and Running](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md#compiling-and-running).

That's a roundabout way of saying "1". But you get the idea. In this case, the constructor id of `Nothing`, is indeed 1.

```haskell
> fieldsOf `evalWithArgsT` [PlutusTx.toData (Nothing :: Maybe ())]
Right (Program () (Version () 1 0 0) (Constant () (Some (ValueOf list (data) []))))
```

And that's another roundabout way of saying `[]`! That is, no fields associated with the constructor.

Extracting fields from values they would actually be present in, is also straight-forward now-

```haskell
> fieldsOf `evalWithArgsT` [PlutusTx.toData (Just 1 :: Maybe Integer)]
Right (Program () (Version () 1 0 0) (Constant () (Some (ValueOf list (data) [I 1]))))
```

There we go! `[I 1]` - We'll discuss the  `I` constructor in its own section below. But it's just a `BuiltinData`/`Data` value. It's not `Constr` though! It's `I`.

## Building `Constr` data
### Pluto
You can create `Constr` data values using [`sigma` literals](https://github.com/Plutonomicon/pluto/blob/main/GUIDE.md#sigma).

You can also use the `ConstrData` builtin function to create `Constr` data values. It takes 2 arguments - the constructor id, and its fields as a list of `Data` elements.
```hs
ConstrData 0 (MkNilData ())
```
is the same as `data sigma0.[]`.

> Aside: What's that `MkNilData ()`? That's how you create a `nil` list of `Data` elements! `MkNilData` takes in a unit and returns a `nil` list of `Data`. You can add more `Data` elements to it using `MkCons`. See [Working with Builtin Lists](builtin-lists.md).

### Plutarch
You can manually build `Constr` data values using the `ConstrData` builtin like above-
```hs
pconstrData :: Term s (PInteger :--> PBuiltinList PData :--> PData)
pconstrData = punsafeBuiltin PLC.ConstrData
```

Or, you can avoid a builtin function call and build the `PData` directly using `pconstant`-
```hs
import PlutusTx (Data (Constr))

> pconstant @PData (Constr 0 [])
```

## What is `Map`?
The `Map` constructor is for """Haskell maps""". In the Plutus world, maps are apparently just assoc lists. You've seen assoc lists already; they're just a list of pairs. These pairs consist of two `Data` values.

The common example of this is [`Value`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Value.html#t:Value). But anytime you see [Plutus Assoc Maps](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-AssocMap.html#t:Map) - you can be sure that it's actually going to end up as a `Map` data.

## Working with `Map`
You can unwrap the `Map` data value to obtain the inner builtin list of builtin pairs with the `UnMapData` builtin function. You can then work with the resulting builtin lists. It contains pairs of `Data`. See [Working with Builtin Lists](builtin-lists.md).

### Pluto Usage
```hs
-- test.pluto
UnMapData (data { 1 = 0xfe })
```
```sh
> pluto run test.pluto
Constant () (Some (ValueOf list (pair (data) (data)) [(I 1,B "\254")]))
```

### Plutarch Usage
In Plutarch, `pasMap` is the synonym to `UnMapData`-
```haskell
pasMap :: Term s (PData :--> PBuiltinList (PBuiltinPair PData PData))
pasMap = punsafeBuiltin PLC.UnMapData
```

## Building `Map` data
### Pluto
You can build `Map` data values using [map literals](https://github.com/Plutonomicon/pluto/blob/main/GUIDE.md#map-of-data-literal-keys-to-data-literal-values----1--0x42-0xfe--42-).

You can also use the `MapData` builtin function to create `Map` data values. It takes in a builtin list of builtin pairs of `Data`.
```hs
MapData (MkNilPairData ())
```
This is the same as `data {}`.

> Aside: What's that `MkNilPairData ()`? Similar to `MkNilData`. This one is for creating a `nil` list of `Data` pairs. You can add more `Data` pairs to it using `MkCons`. See [Working with Builtin Lists](builtin-lists.md).

### Plutarch
Much like above, and in the case of `Constr`, you can use the `MapData` builtin. Or you can use `pconstant`.
```hs
import PlutusTx (Data (Map, I, B))

> pconstant @PData (Map [(I 1, B "x")])
```

## What is `List`?
The List constructor is a wrapper around a builtin list of `Data`. Notice that it is specifically a monomorphic list. Its elements are of type `Data`. `PlutusTx.toData [1, 2, 3]` translates to `List [I 1, I 2, I 3]`. Those elements are `I` data values.

One interesting thing to note here is that when you convert a Haskell list to a `Data` value, and it ends up as a `List` data value, all the elements within the builtin list will be *the same "species" of `Data`*. What does that mean? Well, Haskell lists are homogenous, e.g- `[Int]`, turning `[Int]` into a `Data` consists of two steps-
* Map `PlutusTx.toData` over all elements of the list.
* Wrap the list into a `List` data value.

`PlutusTx.toData` on an `Int` value will just yield an `I` data value. Due to the fact that lists are homogenous, *all* of those `Int` elements will just be `I` data value, so in the end - the `Data` representation of `[1, 2, 3]` looks like - `List [I 1, I 2, I 3]`. The data values have the same "species"! It is totally and completely valid to create a `List [I 1, B "f", Constr 0 []]` in Plutus Core - but you're not going to get that botched version from a Haskell list (and therefore, most of your data types)!

## Working with `List`
You can unwrap the `List` data value to obtain the inner builtin list using the `UnListData` builtin function. Then, you can use the resultant builtin list with the builtin functions that work on lists. See [Working with Builtin Lists](builtin-lists.md).

### Pluto Usage
```hs
-- test.pluto
UnListData (data [1, 0xab, { 42 = [1, 2] }])
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf list (data) [I 1,B "\171",Map [(I 42,List [I 1,I 2])]]))
```

### Plutarch Usage
In Plutarch, `pasList` is the synonym to `UnListData`.
```haskell
pasList :: Term s (PData :--> PBuiltinList PData)
pasList = punsafeBuiltin PLC.UnListData
```

## Building `List` data
### Pluto
You can build `List` data values using [list literals](https://github.com/Plutonomicon/pluto/blob/main/GUIDE.md#list-of-data-literals---1-2-3).

You can also use the `ListData` builtin function to create `List` data values. It takes in a builtin list of `Data` elements.
```hs
ListData (MkNilData ())
```
This is the same as `data []`.

### Plutarch
Much like before, you can use the `ListData` builtin. Or you can use `pconstant`.
```hs
import PlutusTx (Data (List, I))

> pconstant @PData (List [I 1, I 2])
```

## What is `I`?
The `I` constructor wraps a builtin integer to create a `Data` value. When you do `PlutusTx.toData 123` - you obtain an `I` data.

## Working with `I`
You can unwrap an `I` data value to obtain the inner builtin integer using the `UnIData` builtin function.

### Pluto Usage
```hs
-- test.pluto
UnIData (data 42)
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf integer 1))
```

### Plutarch Usage
In Plutarch, `pasInt` is the synonym to `UnIData`.
```haskell
pasInt :: Term s (PData :--> PInteger)
pasInt = punsafeBuiltin PLC.UnIData
```

## Building `I` data
### Pluto
You can build `I` data values using [integer literals preceded by `data`](https://github.com/Plutonomicon/pluto/blob/main/GUIDE.md#integer-constant---42).

You can also use the `IData` builtin function to create `I` data values. It takes in a builtin integer.
```hs
IData 42
```
This is the same as `data 42`.

### Plutarch
Much like before, you can use the `IData` builtin. Or you can use `pconstant`.
```hs
import PlutusTx (Data (I))

> pconstant @PData (I 42)
```

## What is `B`?
Similar to `I`, the `B` constructor wraps a builtin bytestring to create a `Data` value.

## Working with `B`
You can unwrap a `B` data value to obtain the inner builtin bytestring using the `UnBData` builtin function.

### Pluto Usage
```hs
-- test.pluto
UnBData (data 0x4f)
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf bytestring "O"))
```

### Plutarch Usage
In Plutarch, `pasByteStr` is the synonym to `UnBData`.
```haskell
pasByteStr :: Term s (PData :--> PByteString)
pasByteStr = punsafeBuiltin PLC.UnBData
```

## Building `B` data
### Pluto
You can build `B` data values using [integer literals preceded by `data`](https://github.com/Plutonomicon/pluto/blob/main/GUIDE.md#bytestring-constant---0x41).

You can also use the `BData` builtin function to create `B` data values. It takes in a builtin integer.
```hs
BData 0x42
```
This is the same as `data 0x42`.

### Plutarch
Much like before, you can use the `BData` builtin. Or you can use `pconstant`.
```hs
import PlutusTx (Data (B))

> pconstant @PData (B 42)
```

## Wild Card!
What happens when you don't know what kind of `Data` you have? In many cases, you know the exact structure of the `Data` you receive (e.g `ScriptContext` structure is known). But if you have no way to know whether the `Data` is a `Constr`, or `Map`, or `List`, and so on - you can use the `ChooseData` builtin function. It takes *one* force!

### Pluto Usage
```hs
-- test.pluto
! ChooseData (data 42) 0 1 2 3 4
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf integer 3))
```
Each argument corresponds to a branch. Details are discussed at [Plutus Core builtin functions reference](builtin-functions.md).

In this case, the `Data` value had an `I` constructor (`data 42` creates an `I` data). That corresponds to the 5th argument, which was `3`.

> Aside: As is the case for all other function calls, all those arguments will be evaluated strictly. You should use *delay* to avoid this.

### Plutarch Usage
Here's how you could implement a `chooseData` synonym-
```hs
pchooseData :: Term s (PBuiltinData -> a -> a -> a -> a -> a -> a)
pchooseData = phoistAcyclic $ pforce $ punsafeBuiltin PLC.ChooseData
```
It works all the same as above!

# Useful Links
* [Builtin lists](builtin-lists.md)
* [Builtin pairs](builtin-pairs.md)
* [Builtin functions](builtin-functions.md)
* [Pluto guide](https://github.com/Plutonomicon/pluto/blob/main/GUIDE.md)
* [Plutarch guide](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md)
* [Plutus builtin functions and types](https://staging.plutus.iohkdev.io/doc/haddock//plutus-tx/html/PlutusTx-Builtins-Internal.html)
* [Plutus Core builtin function identifiers, aka `DefaultFun`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultFun)
* [Plutus Core types, aka `DefaultUni`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultUni)