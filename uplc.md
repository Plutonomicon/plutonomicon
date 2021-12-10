# Untyped Plutus Core

Plutus smart contracts are written in Haskell, and are ultimately[^il] compiled to a language known as **Untyped Plutus Core** (UPLC). Unlike Haskell, UPLC is a low-level and untyped language. It supports only a handful of builtin types and functions, that are then strung together in lambda applications (see [lambda calculus](https://en.wikipedia.org/wiki/Lambda_calculus)).

Here is a simple example of a UPLC program that is equivalent to the Haskell `id` function:

```lisp
Program
  ()
  (Version () 1 0 0)
  (LamAbs
     ()
     (DeBruijn {dbnIndex = 0})
     (Var () (DeBruijn {dbnIndex = 1})))
```

## Pluto

As you might have noticed it is not practical to write UPLC by hand. [Pluto](https://github.com/Plutonomicon/pluto) is a simple programming language that assembles directly to UPLC; that is to say, it 'maps' directly (more or less) to the AST of UPLC. Understanding Pluto facilitates an understanding of UPLC. Here's the equivalent Pluto program for the above UPLC example:

```haskell
(\x -> x)
```

Pluto retains the structure of UPLC, and enables you to write UPLC "by hand" (as it were) but in a more ergonomic way.

## UPLC Representation

Plutus represents a UPLC program using the following Haskell type:

```haskell
data Program name uni fun ann = 
  Program ann (TPLC.Version ann) (Term name uni fun ann)
```

The part we are interested in is `Term name uni fun ann`. A UPLC is just a `Term` defined recursively in terms of itself, similar to languages like Lisp. The `Term` type is defined as follows:

```haskell
data Term name uni fun ann
    = Var !ann !name
    | LamAbs !ann !name !(Term name uni fun ann)
    | Apply !ann !(Term name uni fun ann) !(Term name uni fun ann)
    | Force !ann !(Term name uni fun ann)
    | Delay !ann !(Term name uni fun ann)
    | Constant !ann !(Some (ValueOf uni))
    | Builtin !ann !fun
    | Error !ann
```

`Term` is parametrized over two type variables of particular interest to us.

1. `fun` is the list of *builtin functions* supported by `Term` or `Program` (see UPLC builtins below), and 
2. `uni` is the kind of *value types* supported by `Term` or `Program`. 

They are normally instantiated to `DefaultFun` and `DefaultUni` respectively, and Pluto uses exactly these.

## UPLC builtins

The *builtin functions* supported by UPLC are specified by the `DefaultFun` type. The Plutus evaluator (which all cardano nodes in the blockchain use to execute script validators) provides the implementation for them, and they are available in the same module (`PlutusCore.Default.Builtins`).  Here is a subset of those builtins:

```haskell
data DefaultFun
    = AddInteger
    | SubtractInteger
    ...
    | AppendByteString
    | ConsByteString    
    ...
    | Sha2_256
    | VerifySignature
    ...
    | IfThenElse
    ...
```

Bear in mind that UPLC is untyped, therefore these builtin functions will fail to evaluate if their types don't match what they expect.

## UPLC values

The *values* supported by UPLC are specified by the `DefaultUni` type.

```haskell
data DefaultUni a where
    DefaultUniInteger    :: DefaultUni (Esc Integer)
    DefaultUniByteString :: DefaultUni (Esc BS.ByteString)
    DefaultUniString     :: DefaultUni (Esc Text.Text)
    DefaultUniUnit       :: DefaultUni (Esc ())
    DefaultUniBool       :: DefaultUni (Esc Bool)
    DefaultUniProtoList  :: DefaultUni (Esc [])
    DefaultUniProtoPair  :: DefaultUni (Esc (,))
    DefaultUniApply      :: !(DefaultUni (Esc f)) -> !(DefaultUni (Esc a)) -> DefaultUni (Esc (f a))
    DefaultUniData       :: DefaultUni (Esc Data)
```

A primitive value is one of integer, bytestring, string, unit (`()`), boolean, or a pair of values. Or they can be a list of values. Lambdas are first-class values, and therefore a lambda application is represented as a value as well. 

Finally, Plutus provides a special value called `Data` - which acts as an intermediate representation for Haskell values, allowing easy encoding and decoding of them. To access and build values of type `Data` you would be using Plutus-provided builtins.

## Working with Plutus `Data`

`Data` is defined simply as:

```haskell
data Data =
      Constr Integer [Data]
    | Map [(Data, Data)]
    | List [Data]
    | I Integer
    | B BS.ByteString
```

### `List` of `Data` 

To begin with understanding how to operate on a Plutus `Data` value, let's look at the builtin functions operating on lists. The specific functions from `DefaultFun` we need are:

- `MkCons` -- constructs a list from a head and tail
- `HeadList` -- returns the head of a list
- `TailList` -- returns the tail of a list

But first, how do we know that a given `Data` is a `List [Data]`? There is `ChooseData` for this, but for now - let's assume that it is indeed a list. The following builtin then provides the `[Data]` argument of the `List` constructor:

```haskell
UnListData :: Data -> [Data]
```

Here's an example in Pluto that uses some of the above builtins:

```haskell
let 
  x = data [1, 2, 3]
in 
  ! HeadList (UnListData x)
```

Running this program will produce `1` as the result:

```bash
$ pluto run lists.pluto
Constant () (Some (ValueOf data (I 1)))
```

What you just saw here is the `Show` value of `Term`. Specifically its `Constant` constructor (see section *UPLC Representation* above). Inside of it we have a `Data` value that was built using the `I` constructor, corresponding to the integer `1`.  If you want to pull out that integer, you would be using `UnIData` builtin.

```haskell
let 
  x = data [1, 2, 3]
in 
  UnIData (! HeadList (UnListData x))
```

(Note: Pluto's `!` maps to UPLC's `Force` builtin, which eliminates polymorphic types; more on this in a section below.)

Running:

```bash
$ pluto run lists.pluto
Constant () (Some (ValueOf integer 1))
```

This value, an "integer", maps to the `DefaultUniInteger` type above. Incidentally, the above Pluto program compiles to the following UPLC program:

```lisp
Program
  ()
  (Version () 1 0 0)
  (Apply
     ()
     (LamAbs
        ()
        (DeBruijn {dbnIndex = 0})
        (Apply
           ()
           (Builtin () UnIData)
           (Apply
              ()
              (Force () (Builtin () HeadList))
              (Apply
                 ()
                 (Builtin () UnListData)
                 (Var () (DeBruijn {dbnIndex = 1}))))))
     (Constant
        () (Some (ValueOf data (List [I 1, I 2, I 3])))))
```

### `Constr` 

TODO

## Force & Delay

TODO

## De Bruijn index

TODO

## Script Validator

TODO (A `Script` is a `Program` that evalutes to a lambda that takes three arguments -- datum, redeemer, scriptcontext, and returns `()` or fails).

## Evaluating UPLC in Haskell

TODO

[^il]: In fact, the Plutus compiler goes through two intermediate languages (Plutus IR and Typed Plutus Core) before compiling to UPLC. See [this Michael Peyton Jones's blog post](https://iohk.io/en/blog/posts/2021/02/02/plutus-tx-compiling-haskell-into-plutus-core/) for details.