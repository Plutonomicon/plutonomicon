This guide should get you started with everything you need for rewriting your Plutus Tx validators in Pluto, from scratch. No prerequisites are required – other than sufficient familiarity with Haskell and Plutus. Of course, you should know what Pluto *is*. Having a go through the syntax description also helps, but is not necessary.

<details>
<summary> Table of Contents </summary>

- [Preamble: Why Pluto?](#preamble-why-pluto)
- [Running & Testing Pluto](#running--testing-pluto)
- [Syntax & Usage](#syntax--usage)
  - [Lambda](#lambda)
  - [Constants](#constants)
    - [Boolean](#boolean)
    - [Integer](#integer)
    - [ByteString](#bytestring)
    - [Text/String](#textstring)
    - [Unit](#unit)
    - [Data](#data)
    - [Data Literals](#data-literals)
      - [Integer constant - `42`](#integer-constant---42)
      - [ByteString constant - `0x41`](#bytestring-constant---0x41)
      - [List of data literals - `[1, 2, 3]`](#list-of-data-literals---1-2-3)
      - [Map of data literal keys, to data literal values - `{ 1 = 0x42, 0xfe = 42 }`](#map-of-data-literal-keys-to-data-literal-values----1--0x42-0xfe--42-)
      - [Sigma](#sigma)
  - [Variables](#variables)
  - [Plutus Core Builtin functions](#plutus-core-builtin-functions)
  - [Infix Application](#infix-application)
  - [If-then-else](#if-then-else)
  - [Let bindings](#let-bindings)
  - [Delay and Force](#delay-and-force)
- [Recursion](#recursion)
- [Analyzing basic examples](#analyzing-basic-examples)
  - [Echo](#echo)
  - [Hello](#hello)
- [Intermission: Loading Pluto into Haskell](#intermission-loading-pluto-into-haskell)
- [Using Pluto within Haskell](#using-pluto-within-haskell)
- [Working with Builtin Lists](#working-with-builtin-lists)
- [Working with Builtin Pairs](#working-with-builtin-pairs)
- [Intermission: What is Data/BuiltinData?](#intermission-what-is-databuiltindata)
- [Intermission: UPLC is strict](#intermission-uplc-is-strict)
- [Writing a real Validator](#writing-a-real-validator)
  - [Pre-requisites](#pre-requisites)
  - [Plutus Tx](#plutus-tx)
  - [Pluto](#pluto)
  - [Testing and Benchmarks](#testing-and-benchmarks)
- [Thumb rules for auditing/understanding/writing Pluto](#thumb-rules-for-auditingunderstandingwriting-pluto)
- [Common Issues](#common-issues)
  - [Using operators without explicit parens causes weird behavior](#using-operators-without-explicit-parens-causes-weird-behavior)
  - [Unexpected `\` near a lambda](#unexpected--near-a-lambda)
  - [Unexpected `in`](#unexpected-in)
  - [Unexpected `=` within `let` binding](#unexpected--within-let-binding)
  - [`UnexpectedBuiltinTermArgumentMachineError` - A builtin received a term argument when something else was expected](#unexpectedbuiltintermargumentmachineerror---a-builtin-received-a-term-argument-when-something-else-was-expected)
- [Extra: Useful Links](#extra-useful-links)
</details>

# Preamble: Why Pluto?
Performance and Efficiency. Script size, CPU units, Memory units – everything can be **magnitudes** more efficient compared to Plutus Tx. In short, at MLabs team ViewPatterns, we've seen *at least* 60% decrease in CPU and Memory, and *at least* 80% decrease in script size, compared to Plutus Tx, in our testing so far.

Later in this guide, we [rewrite a Plutus Tx validator in Pluto](#writing-a-real-validator) and compare their performance metrics. You can also find more benchmarks and metrics at [pluton](https://github.com/Plutonomicon/pluton).

# Running & Testing Pluto
Once you have the `pluto` binary built and installed from this repo. You can *evaluate* a Pluto program with `pluto run path/to/pluto/file`. Evaluating a Pluto program yields the Plutus Core representation of it.
```hs
-- test.pluto
1
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf integer 1))
```
What happens when your program is a function? Let's test it out with the familiar [`id`](https://hackage.haskell.org/package/base-4.16.0.0/docs/Prelude.html#v:id) function!
```hs
-- test.pluto
\x -> x
```
```sh
$ pluto run test.pluto
LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 0}}) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 0}}))
```
It evaluates to a lambda! You can ignore the gory details in that lambda here. You can actually pass arguments to this function with `pluto run test.pluto arg1` - where `arg1` is a [*Pluto data literal*](#data-literals), representing a Plutus Core [`BuiltinData`/`Data`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx.html#t:Data) value.

We'll discuss data literals soon. For now, know that if you passed `1` as `arg1` - it'd represent an [`I`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx.html#t:Data) data with the value `1`.
```sh
$ pluto run test.pluto 1
Constant () (Some (ValueOf data (I 1)))
```
We applied the Pluto `id` function to an `I` data value of `1` and got our argument back! That's how Plutus Core represents `I` data values.

If your pluto program is a `let` binding and you have a specific top level binding that you want to evaluate - you can use `pluto eval`
```hs
-- test.pluto
let
  x = 1
in 42
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf integer 42))
$ pluto eval test.pluto x
Constant () (Some (ValueOf integer 1))
```

If the binding you want to evaluate is a function, and you want to pass arguments to it - you can do that with `pluto eval` as well. However, unlike in the case of `pluto run`, where the arguments were [*Pluto data literals*](#data-literals) - arguments to be fed to a binding, using `pluto eval`, are supposed to be Pluto expressions.
```hs
-- test.pluto
let
  id = (\x -> x)
in 42
```
```sh
$ pluto eval test.pluto id 1
Constant () (Some (ValueOf integer 1))
```
The Pluto expression `1` corresponds to a Plutus Core builtin integer. Feeding it to the `id` function gives us back the same thing. That's how Plutus Core represents builtin integers! Notice the contrast to `I` data value representation above.

# Syntax & Usage
Every Pluto program is a “term”, an expression. The syntax is very similar to Haskell. An expression may be any of the following:-

## Lambda
It wouldn't be a Haskell-like language without lambdas now, would it?

A Pluto lambda shares similar syntax to Haskell-
```hs
\x -> x
```
This is a "top level lambda" - hence it doesn't have parentheses around it. You can still put parentheses around it just the same.
```hs
(\x -> x)
```

As we will discuss later, when putting lambdas inside other terms - you **must** put the lambda inside parentheses.

You apply functions the same way you would in Haskell-
```hs
(\x -> x) 1
```
Or,
```hs
let
  f = (\x -> x)
in f 1
```

It's just whitespace!

> Aside: Unlike in Haskell, function application is **strict**. The arguments are evaluated before the function is called. If you don't want this behavior, see: [Delay and Force](#delay-and-force)

## Constants
There are 5 categories of constants in Pluto - Booleans, Integers, ByteStrings, Text/Strings, and Data values.
### Boolean
Pluto booleans correspond to Plutus [builtin booleans](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-Builtins-Internal.html#t:BuiltinBool). Pluto boolean constants are `True` and `False` - just like Haskell.
```hs
True
```
```hs
False
```
### Integer
Pluto integers correspond to Plutus [builtin integers](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-Builtins-Internal.html#t:BuiltinInteger). These are just integer literals, optionally preceded by a `-`.
```hs
42
```
```hs
-2
```
### ByteString
Pluto bytestrings correspond to Plutus [builtin bytestrings](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-Builtins-Internal.html#t:BuiltinByteString). These are written as hex literals in Pluto.
```hs
0x41
```
corresponds to the bytestring `"A"` (i.e `[65]`).
### Text/String
Pluto text/strings corresponds to Plutus [builtin strings](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-Builtins-Internal.html#t:BuiltinString). These are written as string literals.
```hs
"foobar"
```
### Unit
This corresponds to Plutus [builtin unit](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-Builtins-Internal.html#t:BuiltinUnit). Just like in Haskell, Unit is represented by `()`.
```hs
()
```
### Data
`Data` corresponds to Plutus [`BuiltinData` or `Data`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx.html#t:Data).

This is Plutus's way of representing most Haskell data types. Which is done using the `Constr` constructor, that represents sum of products. `Data` can also represent some other builtin types such as `Map`, `List`, `I` (integer), and `B` (bytestring). All values that are passed on to your validator scripts, minting policies etc., are of type `Data`. `FromData` and `IsData` facilitate working with Haskell ADTs in Plutus.

We discuss more about `Data` [later in the guide](#intermission-what-is-databuiltindata).

In Pluto, you create `Data` values by writing the keyword `data`, followed by a "data literal".

### Data Literals
A data literal can be any of the following:-

#### Integer constant - `42`
```hs
-- test.pluto
data 42
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf data (I 42)))
```
This constructs an `I` data value.
#### ByteString constant - `0x41`
```hs
-- test.pluto
data 0x41
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf data (B "A")))
```
This constructs a `B` data value.

> Aside: Remember that the length of a hex literal is always even! You need a hex digit pair to represent a byte. If you get this wrong, you'll get a Pluto parsing error - but it's quite misleading right now. Just remember to write your hex literals correctly!

> Ed note: The parsing errors could be made significantly better by reducing backtracking.
#### List of data literals - `[1, 2, 3]`
```hs
-- test.pluto
data [1, 2, 3]
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf data (B "A")))
```
This constructs a `List` data value where each element is of type `Data` (hence the data literal).

Lists in Plutus are homogenous - but notice the expressiveness of `Data`. You can essentially represent any Haskell type using `Data`. This means that a list of `Data` is *practically* heterogenous.

Recall that you can create a different sort of `Data` value using different data literals. You can mix and match data literals inside that list literal. At the end of the day, all data literals create a `Data` value - and that's the correct element type here.
```hs
-- test.pluto
data [1, 0x41, [42], { 0xfe = 7 }]
-- valid!
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf data (List [I 1,B "A",List [I 42],Map [(B "\254",I 7)]])))
```
#### Map of data literal keys, to data literal values - `{ 1 = 0x42, 0xfe = 42 }`
```hs
-- test.pluto
data { 1 = 0x42, 0xfe = 42, [1, 2] = [3, 4], { 1 = 3 } = 4 }
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf data (Map [(I 1,B "B"),(B "\254",I 42),(List [I 1,I 2],List [I 3,I 4]),(Map [(I 1,I 3)],I 4)])))
```
This constructs a `Map` data value where each key and value is of type `Data` (hence the data literal). Maps in Plutus are actually just assoc lists. This is why the `Map` constructor in `Data` wraps around an assoc list.

Just like in the case of lists, you can mix and match the data literals however you want. At the end of the day, all of the data literals end up as a `Data` value.

> Aside: Have you seen `Map`s in Plutus before? A common example is [`Value`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Value.html#t:Value)! Despite the name, `Value` is a map from `CurrencySymbol` to another map (from `TokenName` to `Integer`). Whenever we are talking about maps in Plutus - feel free to mentally substitute the word "map" with "assoc list".

#### Sigma
```hs
-- test.pluto
data sigma0.[1, 0x41]
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf data (Constr 0 [I 1,B "A"])))
```
Here's the cool one! This is for representing sums of products. It corresponds to the `Constr` constructor in `Data`.

We'll discuss about `Constr` in depth at a later part of this guide. For now, you can read `Constr 0 []` (i.e `data sigma0.[]`) as-
> The 0th constructor of a data type with 0 fields.

In this example above, `data sigma0.[1, 0x41]` translates to `Constr 0 [I 1, B "A"]` - which reads as-
> The 0th constructor of a data type with 2 fields with values `I 1` and `B "A"` respectively.
How would you represent `Constr 1 []`? With `data sigma1.[]` of course!

Now you know how to represent Haskell ADTs in Pluto!

> Aside: Recall that `I 1` is how you represent the integer 1, as a value of type `Data`, and `B "A"` is how you represent the bytestring `"A"`, as a value of type `Data`.

> **IMPORTANT**: Remember that the "data literal" is what appears *after* the `data` keyword. It **DOES NOT** include the `data` keyword itself.

## Variables
Variable names in Pluto must begin with a lower case letter and can consist of any alphanumeric characters, as well as `_`.

> Aside: `'` is not allowed in variable names!

## Plutus Core Builtin functions
When writing Pluto, you'll primarily be calling builtin functions. All of your functions and program functionalities will merely be wrappers around these builtin functions. Here's a list of all builtin functions, aka [`DefaultFun`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultFun)-

* `AddInteger`
* `SubtractInteger`
* `MultiplyInteger`
* `DivideInteger`
* `QuotientInteger`
* `RemainderInteger`
* `ModInteger`
* `EqualsInteger`
* `LessThanInteger`
* `LessThanEqualsInteger`
* `AppendByteString`
* `ConsByteString`
* `SliceByteString`
* `LengthOfByteString` (actually called `LengthByteString` in Pluto)
* `IndexByteString`
* `EqualsByteString`
* `LessThanByteString`
* `LessThanEqualsByteString` (actually called `LessThanEqualByteString` in Pluto)
* `Sha2_256`
* `Sha3_256`
* `Blake2b_256`
* `VerifySignature`
* `AppendString`
* `EqualsString`
* `EncodeUtf8`
* `DecodeUtf8`
* `IfThenElse`
* `ChooseUnit`
* `Trace`
* `FstPair`
* `SndPair`
* `ChooseList`
* `MkCons`
* `HeadList`
* `TailList`
* `NullList`
* `ChooseData`
* `ConstrData`
* `MapData`
* `ListData`
* `IData`
* `BData`
* `UnConstrData`
* `UnMapData`
* `UnListData`
* `UnIData`
* `UnBData`
* `EqualsData`
* `MkPairData`
* `MkNilData`
* `MkNilPairData`

These are mostly quite simple to use. You'll be calling them as you would call any other function - `AddInteger 1 2` calls the builtin function `AddInteger` with the arguments `1` and `2`.

However, some of these functions have *type variables*, for parametric polymorphism. To use these functions, you need to *force* on them, using `!`, a certain number of times. The number of times you must force them depends on the number of **distinct** type variables the builtin function has. For example, `HeadList` has **one** type variable, so it needs to be forced once before you can apply it to your list- `! HeadList xs`.

Regardless, all you need to know to use these functions, is their description, their expected types, and the number of forces they take. Just like any other function in any other programming language - documentation!

Official documentation on these are sparse, and unsatisfying. That's why we have a [Builtin function reference](./builtin-functions.md)!

## Infix Application
You can surround a variable representing a function with backticks to use it as an infix function. Just like Haskell!
```hs
let
  const = (\x _ -> x)
in 1 `const` 2
```

Pluto also has many convenient operators included. These correspond to Plutus Core builtin functions.
* `+i` - Integer addition operator.

  Corresponds to `AddInteger`.

  Ex: `1 +i 1` evaluates to `2`.
* `-i` - Integer subtraction operator.

  Corresponds to `SubtractInteger`.

  Ex: `6 -i 4` evaluates to `2`.
* `*i` - Integer multiplication operator.

  Corresponds to `MultiplyInteger`.

  Ex: `3 *i 3` evaluates to `9`.
* `/i` - Integer division operator.

  Corresponds to `DivideInteger`.

  Ex: `9 /i 3` evaluates to `3`.
* `%i` - Integer modulo operator.

  Corresponds to `ModInteger`.

  Ex: `5 %i 2` evaluates to `1`.
* `==i` - Integer equality operator.

  Corresponds to `EqualsInteger`.

  Ex: `5 ==i 2` evaluates to `False`, `2 ==i 2` evaluates to `True`.
* `<i` - Integer comparison operator - LT (Less Than).

  Corresponds to `LessThanInteger`.

  Ex: `5 <i 2` evaluates to `False`, `2 <i 5` evaluates to `True`.
* `<=i` - Integer comparison operator - LTE (Less Than Equals).

  Corresponds to `LessThanEqualsInteger`.

  Ex: `5 <i 2` evaluates to `False`, `2 <=i 2` evaluates to `True`.
* `+b` - ByteString concatenation operator.

  Corresponds to `AppendByteString`.

  Ex: `0x41 +b 0x61` evaluates to `"Aa"`.
* `:b` - ByteString cons operator.

  Corresponds to `ConsByteString`.

  Ex: `65 :b 0x61` evaluates to `"Aa"`.
* `!b` - ByteString indexing operator.

  Corresponds to `IndexByteString`.

  Ex: `0x41615fde !b 1` evaluates to `97`.
* `==b` - ByteString equality operator.

  Corresponds to `EqualsByteString`.

  Ex: `0x41 ==b 0x61` evaluates to `False`, `0x41615fde ==b 0x41615fde` evaluates to `True`.
* `<b` - ByteString comparison operator - LT (Less Than).

  Corresponds to `LessThanByteString`. Performs a lexicographic comparison.

  Ex: `0x41 <b 0x61` evaluates to `True`.
* `<=b` - ByteString comparison operator - LTE (Less Than Equals).

  Corresponds to `LessThanEqualsByteString`. Performs a lexicographic comparison.

  Ex: `0x41 <=b 0x41` evaluates to `True`.
* `+s` - Text/String concatenation operator.

  Corresponds to `AppendString`.

  Ex: `"foo" +s "bar"` evaluates to `"foobar"`.
* `==s` - Text/String equality operator.

  Corresponds to `EqualsString`.

  Ex: `"foo" ==s "foo"` evaluates to `True`.
* `==d` - Data equality operator.

  Corresponds to `EqualsData`.

  Ex: `data 1 ==d data 1` evaluates to `True`.

## If-then-else
Conditionals also share syntax with Haskell-
```hs
if cond then expr1 else expr2
```

Here, `cond` may be any of the following-
* Boolean constant
* Variable representing a boolean
* Function application (infix or prefix) that yields a boolean
* `if` or `let` terms within parentheses that evaluate to a boolean
* Any of the above expressions, as a [delayed](#delay-and-force) term, preceded by a `!` (i.e [Forced](#delay-and-force))

`expr1` can be any of the following-
* Constant
* Lambda within parentheses
* Variable
* Builtin function
* Function application (infix or prefix) that yields a boolean
* `if` or `let` terms within parentheses
* The `Error` keyword
* Any of the above expressions, preceded by a `!` or `#`. i.e [Delayed or Forced](#delay-and-force).
  * `!` is only valid on a delayed expression.

`expr2` can be everything `expr1` can be, as well as `if` and `let` terms without parentheses. This allows you to have nice `else if`s-
```hs
if False then
  "foo"
else if False then
  "bar"
else
  "baz"
```

Although many things in Pluto are strict. `if-then-else` does not eagerly evaluate both its branches. It works as you would expect, only the branch to be taken, is evaluated.

> Aside: `if-then-else` is actually a wrapper around the `IfThenElse` builtin function. But wait - function application is strict, right? So applying the branches onto `IfThenElse` would strictly evaluate both branches. How come `if-then-else` manages to get around this? By using [delay and force](#delay-and-force)!

## Let bindings
Let bindings are *similar* to Haskell - but not exactly the same-
```hs
let <bindings> in <expr>
```
Now, `bindings` represents **one or more** bindings, each separated by a `;`. However, trailing semicolons are not allowed.
```hs
let x = 1; in x
-- INVALID!
```
Each binding is of the form `<var> = <expr>`. A `var` is simply a [variable](#variables). An `expr` can be any of the following-
* Constant
* Lambda within parentheses
* Variable
* Builtin function
* Function application (infix or prefix) that yields a boolean
* `if` or `let` terms within parentheses
* The `Error` keyword
* Any of the above expressions, preceded by a `!` or `#`. i.e [Delayed or Forced](#delay-and-force).
  * `!` is only valid on a delayed expression.

## Delay and Force
An expression can be preceded by a `#` to create a "delayed expression".
```hs
-- test.pluto
let
  f = (\x -> x);
  res = # (f 1)
in res
```
```sh
$ pluto run test.pluto
Delay () (Apply () (LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 2}}) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 2}}))) (Constant () (Some (ValueOf integer 1))))
```
The function application is "delayed". It will not be evaluated (and therefore computed) until it is *forced*.

Function application, let bindings, and similar cases are all strictly evaluated in Pluto (and Plutus).
All of your let bindings are computed **before** the expression after `in` is computed.
All of your function arguments are evaluated **before** the function is called.

This is often undesirable, and you want to create a delayed term instead that you want to force *only* when you need to compute it.

You can force a previously delayed expression using `!`-
```hs
-- test.pluto
let
  f = (\x -> x);
  res = # (f 1)
in ! res
```
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf integer 1))
```

You can do the same with function arguments-
```hs
-- test.pluto
let
  -- Wrap the `if-then-else` language construct into a function.
  -- This function will strictly evaluate `x` and `y` upon application, since function application is strict.
  iff = (\cond x y -> if cond then x else y);
in ! (iff (# 42) (# 7))
```
Peculiar, isn't it? Function application is strict - so wrapping `if-then-else` in a function and then applying it to both branches .....would evaluate both branches. But that's not what we want when using conditionals! So we use `#` to delay the expressions (in this case, the expressions are just integers - but use your imagniation to conjure up some super complex computation in their place!). This way, `iff` doesn't evaluate the *inner* expressions. Finally, since `iff` gives back one of the delayed expressions, we force it using `!` to **only** evaluate that branch.

Delay and Force will be one of your most useful tools while writing Pluto. Make sure you get a grip on them!

# Recursion
To emulate recursion in Pluto, you need to use the Y combinator - often called "fix". Be prepared to pop in this function in all your pluto programs-
```hs
fix = (\f -> (\x -> f (\v -> x x v)) (\x -> f (\v -> x x v)));
```
The first argument is "self", or the function you want to recurse with.
```hs
-- test.pluto
let
  fix = (\f -> (\x -> f (\v -> x x v)) (\x -> f (\v -> x x v)));
  fac = fix (\self n -> if n ==i 1 then n else n *i (self (n -i 1)))
  -- (ignore the existence of non positives :D)
in fac 4
```
There's the factorial function! Note how the function passed to `fix` takes in a self and just recurses on it. Let's run it!
```sh
$ pluto run test.pluto
Constant () (Some (ValueOf integer 24))
```
Perfect!

# Analyzing basic examples

Alright, that's our extended `leanxinyminutes` segment done with. Now, how about some real examples?

We'll go through some of the basic examples in [`pluto/examples`](./examples) one by one. Make sure you know [how to run your Pluto programs](#running--testing-pluto)!

## Echo
[source](./examples/echo.pluto)

```hs
-- Echos the first command line argument
(\x -> x)
```
Alright, so this is the familiar `id` function. It is practically the same as a Haskell lambda expression for `id`. But it also serves as a great way to see the Plutus Core representation of any argument you pass in!

```sh
$ pluto run echo.pluto "[1, 2, 3]"
Constant () (Some (ValueOf data (List [I 1,I 2,I 3])))
```

> Aside: Recall that [`pluto run` takes in](#command-line) [data literals](#data-literals) to pass into the pluto program. In this case that [data literal is `[1, 2, 3]`](#list-of-data-literals---1-2-3).

## Hello
[source](./examples/hello.pluto)

```hs
-- Hello world
let
  trace = (\s x -> ! Trace s x);
  defaultGreeting = "Hello";
  greet = (\greeting name ->
    (greeting +s ", ")
      +s (trace ("Name is: " `AppendString` name) name)
  )
in
  -- The argument is a Plutus Data value
  (\nameData ->
    greet defaultGreeting (DecodeUtf8 (UnBData nameData))
  )
```

There's something a bit juicier, but still simple! The entire program is a let binding that yields a function. This function takes in a `nameData`, which is actually a `B` data value. That is, a bytestring as a `Data` value.

Let's examine the let bindings first.

First we have `trace`-
```hs
trace = (\s x -> ! Trace s x);
```
This is actually *similar* to [`PlutusTx.Prelude.trace`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-Trace.html#v:trace). It uses the `Trace` builtin function. Which is really the only way to do "side effects" here. It will log the message (its first argument - must be Text/String) (when you run it using `Plutus.V1.Ledger.Scripts.evaluateScript` or similar) and return its second argument.

What's with that `!`? Why use forcing here? Well, you can think of the `Trace` builtin as having type `Trace :: forall a. Text -> a -> a`. It has one type variable - `a`. Many builtins have one or more type variables. To use these builtins, you must use *force* on them. How many times do you have to force it? It depends on the number of **distinct** type variables. In this case, there's only one - so we force once. So, `! Trace` "forces" the `Trace` builtin function to make it "usable", and then we apply `s` and `x` over it.

We discuss more about builtin functions and forcing [here](#plutus-core-builtin-functions). But I hope that brief description was enough to understand `trace` here. `trace "foo" 1` logs "foo" and returns `1`.

Next, we have `defaultGreeting`. Not much to see here, it's just a variable bound to the string `"Hello"`.

Next, we have the function `greet`-
```hs
greet = (\greeting name ->
    (greeting +s ", ")
      +s (trace ("Name is: " `AppendString` name) name)
  )
```
It takes in 2 arguments, `greeting` and `name` - both of which are *expected* to be strings. First, `greeting` is concatenated with the string - `", "`, `+s` is the Text/String concatenation operator. It was [discussed above](#infix-application). Then, the result of that is concatenated with-
```hs
trace ("Name is: " `AppendString` name) name
```

> Aside: Recall that `+s` is a synonym to `AppendString`. So you can replace that with `+s` and it'd be the same! However, this is also a good demonstration of infix application using backticks.

This calls `trace`. The name is appended to the string `"Name is: "` and logged. The entire expression just returns `name`, since `trace` returns its second argument.

And that's all `greet` does! It creates a greeting string with the given `greeting` and `name`. It also logs a message noting the `name` argument.

Finally, we have the "main" function that the program yields-
```hs
(\nameData ->
  greet defaultGreeting (DecodeUtf8 (UnBData nameData))
)
```

It applies the `greet` function we just saw over 2 arguments, `defaultGreeting` - which is just `"Hello"`, and-
```hs
DecodeUtf8 (UnBData nameData)
```
What does that mean? Recall that `nameData` is expected to be a `B` data value. That is, a bytestring wrapped as a `Data` value. `UnBData` is the builtin function that unwraps a `B` data value to extract the inner bytestring. So `UnBData nameData` yields a `ByteString`. What about `DecodeUtf8` - this builtin function decodes a bytestring using UTF-8. It returns a `Text` (string). Of course, `greet` expects two `Text`s!

If `greet` was called with `"Hello"` and `"World"` as its arguments, it'd yield `"Hello, World"`. What's the UTF8 encoded bytestring representation of `"World"`? `[87, 111, 114, 108, 100]`, or `0x576f726c64` in Pluto.
```sh
$ pluto run test.pluto 0x576f726c64
Constant () (Some (ValueOf string "Hello, World"))
```
Aha! There we have it. Not too difficult was it?

> Aside: Note how I called `PlutusTx.Prelude.trace` and `trace` similar, but they are not the same! The one from `PlutusTx.Prelude` traces *before* evaluating its second argument. But you have to be careful here since `trace` is a Pluto function and therefore, strict!

> Aside: This program structure is going to be a common pattern when you start writing Pluto. Usually, your programs will be let bindings that yield a function! Validating function, minting policy function etc.

# Intermission: Loading Pluto into Haskell

For the next segments of the guide, you'll want to load your Pluto script into Haskell itself. You can do that using `PlutusCore.Assembler.FFI.load` from the `pluto` package.
```hs
-- test.pluto
\x -> x
```
```hs
import PlutusCore.Assembler.Types.AST (Program)
import qualified PlutusCore.Assembler.FFI as FFI

plutoId :: Program ()
plutoId = $(FFI.load "test.pluto")
```

`plutoId` is now the Pluto program that evaluates to the identity function.

More often than not, you want to load a `Pluto` file as a `Script` (from `Plutus.V1.Ledger.Scripts`). These are the essential plutus scripts that are the core of validators, minting policies - you name it! Once you have a plutus script, you can use functions provided by the `Plutus.V1.Ledger.Api` and `Plutus.V1.Ledger.Scripts` modules to evaluate them, or wrap them into `Validator`s.

You can obtain a `Script` from a Pluto program using `PlutusCore.Assembler.Assemble.translate`-
```hs
import PlutusCore.Assembler.Types.ErrorMessage (ErrorMessage)
import qualified PlutusCore.Assembler.Assemble as Pluto
import qualified PlutusCore.Assembler.FFI as FFI

import Plutus.V1.Ledger.Scripts (Script)

plutoIdScript :: Either ErrorMessage Script
plutoIdScript = Pluto.translate $(FFI.load "test.pluto")
```
You can then run that script with [`evaluateScript`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Scripts.html#v:evaluateScript), [`runScript`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Scripts.html#v:evaluateScript) etc. Or, you can wrap it into a [`Validator`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Scripts.html#t:Validator).

# Using Pluto within Haskell

Once you have your Pluto script loaded, you can then use functions from [`Plutus.V1.Ledger.Scripts`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Scripts.html) to run them. Let's glance at a few of these useful functions-
```hs
-- Plutus.V1.Ledger.Scripts

evaluateScript :: forall m. MonadError ScriptError m => Script -> m (ExBudget, [Text])

applyArguments :: Script -> [Data] -> Script

runScript :: MonadError ScriptError m => Context -> Validator -> Datum -> Redeemer -> m (ExBudget, [Text])

runMintingPolicyScript :: MonadError ScriptError m => Context -> MintingPolicy -> Redeemer -> m (ExBudget, [Text])
```

These functions are great! But these only give you the execution budget (how much CPU and Memory your script needed), and the trace log. Often times, you also want to look at what the script evaluated to. Of course, on the chain - it doesn't matter what your script evaluates to. If the script doesn't error with the `PlutusTx.Prelude.error` function (`Error` keyword in Pluto), it's considered as "successful". But it's still useful to look at the return value during testing.

For that reason, you can use `PlutusCore.Assembler.Evaluate.eval` and `PlutusCore.Assembler.Evaluate.evalWithArgs` from the `pluto` package-
```hs
eval :: Script -> Either ScriptError (ExBudget, [Text], Term Name DefaultUni DefaultFun ())

evalWithArgs :: [Data] -> Script -> Either ScriptError (ExBudget, [Text], Term Name DefaultUni DefaultFun ())
```

Why don't we try it on good ol' `id`?
```hs
-- test.pluto
\x -> x
```
Load that up into Haskell and bind it to a variable!
```hs
plutoSc :: Script
```

Here comes the lightshow-
```hs
> eval plutoSc
Right (ExBudget {exBudgetCPU = ExCPU 29873, exBudgetMemory = ExMemory 200},[],LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 0}}) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 0}})))
```
Not bad. But that's just the lambda, we should feed it an argument-
```hs
> [PlutusTx.toData 1] `evalWithArgs` plutoSc
Right (ExBudget {exBudgetCPU = ExCPU 119192, exBudgetMemory = ExMemory 500},[],Constant () (Some (ValueOf data (I 1))))
```

Neat! Remember that [`hello.pluto`](#hello) example from earlier? Let's load that up and run it!
```hs
helloPluto :: Script
```

Ready or not, here it goes!
```hs
> eval helloPluto
Right (ExBudget {exBudgetCPU = ExCPU 297830, exBudgetMemory = ExMemory 1100},[],LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 3}}) (Apply () (Apply () (LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 4}}) (LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 5}}) (Apply () (Apply () (Builtin () AppendString) (Apply () (Apply () (Builtin () AppendString) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 4}}))) (Constant () (Some (ValueOf string ", "))))) (Apply () (Apply () (LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 6}}) (LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 7}}) (Apply () (Apply () (Force () (Builtin () Trace)) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 6}}))) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 7}}))))) (Apply () (Apply () (Builtin () AppendString) (Constant () (Some (ValueOf string "Name is: ")))) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 5}})))) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 5}})))))) (Constant () (Some (ValueOf string "Hello")))) (Apply () (Builtin () DecodeUtf8) (Apply () (Builtin () UnBData) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 3}}))))))
```
False hype, that's just a massive lambda! We should feed it a bytestring `Data` value first.
```hs
import PlutusTx.Builtins (BuiltinByteString, toBuiltin)
import qualified Data.ByteString as BS

name :: BuiltinByteString
name = toBuiltin $ BS.pack [0x41, 0x41, 0x41, 0x41, 0x41, 0x41]
```
```hs
> [PlutusTx.toData name] `evalWithArgs` helloPluto
Right (ExBudget {exBudgetCPU = ExCPU 2282658, exBudgetMemory = ExMemory 4784},["Name is: AAAAAA"],Constant () (Some (ValueOf string "Hello, AAAAAA")))
```
AAAAAA indeed, my friend. AAAAAA indeed.

> Aside: Notice that all arguments you will be passing to a `Script` from Haskell are of type [`Data`/`BuiltinData`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx.html#t:Data). Any arguments your `Script` receives on the chain will also be of type `Data`. This is why `Data` is such an integral type in Plutus Core!

# Working with Builtin Lists
Unsurprisingly, the Pluto programs you write will be operating on builtin lists *a lot*. Hey, that's just like Haskell!

Anyway, you can learn all about how to use them at [plutonomicon](./builtin-lists.md).

# Working with Builtin Pairs
Working with builtin pairs doesn't come up as often as builtin lists, but it does come up! Thankfully, more often than not - you'll be *taking pairs apart*, not building them.

You can learn all about builtin pairs and the builtin functions to operate on them at [plutonomicon](./builtin-pairs.md).

# Intermission: What is Data/BuiltinData?
Most of the time, you'll be working with [`BuiltinData`/`Data`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx.html#t:Data) - this is the type of the arguments that will be passed onto your script from the outside. This is the type of the datum, the redeemer and the script context. This is also the type of arguments you will be able to pass to a Script. This is Plutus Core's most flexible data type - capable of representing *any* Haskell ADT as a sum of products. It's also equipped to represent builtin lists, maps, bytestrings, and integers.

As such, you'll certainly need to know [everything about it](./builtin-data.md)!

# Intermission: UPLC is strict
Because UPLC (Untyped Plutus Core), the language Pluto wraps around, is strict - many of the behaviors you're accustomed to in Haskell, don't exist here. For starters, arguments to all functions, builtin or otherwise, are strictly evaluated before the function itself is called.

More importantly, `let` bindings in Pluto are also strict-
```hs
let
  x = <big computation>;
  y = <another big computation>
in x
```
`y` was never used - but it *will* be evaluated before returning `x`. You'll have to keep this mind when writing Pluto programs.

There are two ways to handle this- Manual thunking and [Delaying + Forcing](#delay-and-force).

The first method is the simpler of the too, instead of doing a computation, build a function holding said computation.
```hs
let
  fx = (\_ -> <big computation>);
  fy = (\_ -> <another big computation>)
in fx ()
```
The computation within `fy` was never needed - so it was never computed! We just needed the computation within `fx`, so we passed a dummy value into it (doesn't matter what value you pass), which executed the computation and yielded a value.

The second method is arguably more *natural* to the language-
```hs
let
  xr = # (<big computation>);
  yr = # (<another big computation>)
in ! xr
```
We delay both of the computations using `#`, and only force the one we need.

Which method you prefer is entirely dependent on you. There are trade offs to each. I think the second method is cleaner, but it tends to slightly increase CPU and Memory cost while (usually) decreasing script size.

# Writing a real Validator
Enough of that shimmy sham; how about we write a *real* validator?

## Pre-requisites
You definitely need to know about a few things before diving in here.
* [Syntax & Usage](#syntax--usage) (duh)
* [Recursion](#recursion)
* [Builtin data](#intermission-what-is-databuiltindata)
* [Builtin functions](#plutus-core-builtin-functions)
* [How many forces every builtin functions take](./builtin-functions.md)

It's also useful to know how to work with [builtin list](./builtin-lists.md) and [builtin pairs](./builtin-pairs.md).

## Plutus Tx
```hs
import qualified Prelude as Hask

import Plutus.V1.Ledger.Ada (adaToken, adaSymbol)
import Plutus.V1.Ledger.Contexts (ScriptContext (scriptContextTxInfo), pubKeyOutputsAt)
import Plutus.V1.Ledger.Crypto (PubKeyHash)
import Plutus.V1.Ledger.Value (Value)
import qualified Plutus.V1.Ledger.Value as Value
import PlutusTx (unsafeFromBuiltinData)
import PlutusTx.Prelude

integerToAdaValue :: Integer -> Value
integerToAdaValue = Value.singleton adaSymbol adaToken

validatePayment :: PubKeyHash -> BuiltinData -> BuiltinData -> BuiltinData -> ()
validatePayment pkh _ _ rawCtx =
  if totalValue `Value.gt` integerToAdaValue 1 && totalValue `Value.lt` integerToAdaValue 100
    then trace "Correct value!" ()
    else traceError "Invalid value."
  where
    ctx = unsafeFromBuiltinData @ScriptContext rawCtx

    txInfo = scriptContextTxInfo ctx
    values = pubKeyOutputsAt pkh txInfo

    totalValue = fold values
```
Ok, admittedly that's not a *real real* validator but hey, it's used in the [official tutorial](https://plutus-apps.readthedocs.io/en/latest/plutus/tutorials/basic-validators.html#using-the-validation-context)!

> Aside: In all serious ness, this validator shows some real juice. It takes apart script context, it folds on a list, believe it or not - this is enough to showcase *almost every single* Pluto concept! Talk about minimal yet exhaustive!

`validatePayment` basically just checks the script context's `txInfoOutputs` to find `Value`s matching the given public key (`pkh`). It then sums up all those values and asserts that the total value is within range (1, 100).

## Pluto
Want me to dump the Pluto version on you? Sorry I can't hear your response while writing this, so I'll dump it anyway-
```hs
let
  -- Bestow recursion unto pluto.
  fix = (\f -> (\x -> f (\v -> x x v)) (\x -> f (\v -> x x v)));

  -- List utilities.
  head = (\x -> ! HeadList x);
  second = (\x -> ! HeadList (! TailList x));
  tail = (\x -> ! TailList x);
  null = (\x -> ! NullList x);
  cons = (\x xs -> ! MkCons x xs);
  nilData = MkNilData ();

  -- Pair utilities.
  fst = (\x -> ! ! FstPair x);
  snd = (\x -> ! ! SndPair x);

  -- List HOFs.
  -- | fold :: (b -> a -> b) -> [a] -> b
  fold = (\f ->
    fix
      (\self acc xs ->
        if null xs then
          acc
        else
          self (f acc (head xs)) (tail xs)
      )
  );

  -- Utilities for working with 'Constr' (sum of products).
  fieldsOf = (\x -> ! ! SndPair (UnConstrData x));
  constructorOf = (\x -> ! ! FstPair (UnConstrData x));

  -- Tracing.
  trace = (\s a -> ! Trace s a);
  traceIfTrue = (\s a -> if a then ! Trace s a else a);
  traceIfFalse = (\s a -> if a then a else ! Trace s a);
  traceError = (\s -> ! (! Trace s (# Error)))
in (\pkh _ _ ctx ->
  let
    -- 'TxInfo', the first field in 'ScriptContext'.
    info = head (fieldsOf ctx);
    {- ['TxOut'], the second field in 'TxInfo' is a `List` data value.
    Use `UnListData` to get the builtin list. -}
    txOuts = UnListData (second (fieldsOf info));

    -- | valuesIn :: ['TxOut'] -> ['Value']
    valuesIn = fix (\self xs ->
      if null xs then
        nilData
      else
        let
          -- First element of 'xs', this is what we'll be operating on in this function.
          txOut = head xs;
          -- ['Address', 'Value', 'Maybe' 'DatumHash'] - the 3 fields within 'TxOut'.
          txOutFields = fieldsOf txOut;
          -- 'Address', the first field of 'TxOut'.
          outAddr = head txOutFields;
          -- 'Credential', first field of 'Address'.
          cred = UnConstrData (head (fieldsOf outAddr));
          -- Either 0 or 1, denoting the constructor for 'Credential'.
          constr = fst cred;
          -- The fields associated with the constructor. (delayed - may not be used)
          credData = # (snd cred);
          rest = tail xs
        in
          (if constr ==i 0 then
            -- 'PubKeyCredential' constructor. Has one field, a bytestring (not 'BuiltinByteString').
            (if head (! credData) ==d pkh
              -- Cons the 'Value' (second field of 'TxOut') and continue.
              then second txOutFields `cons` self rest
              else self rest)
          else if constr ==i 1 then
            -- 'ScriptCredential' constructor. Uninteresting.
            self rest
          else
            -- Absurd
            Error
          )
    );
    -- | totalAdaValueIn :: ['Value'] -> Integer
    totalAdaValueIn = (\vals -> fold
      (\acc val ->
        let
          {- Confusingly, 'Value' is a 'Map' of 'Map's. UnMap it.
          m is a builtin-list of builtin pairs. 2 builtin data in each pair.
          In this case, fst is a bytestring (not builtin), snd is another map -}
          -- m :: [(Data, Data)]
          --          ^     ^ Represents 'Map TokenName Integer'
          --          ^ Represents 'CurrencySymbol'
          m = UnMapData val
        in
          fold
            (\acc mpair ->
              let
                -- 'CurrencySymbol'. It's wrapped as a `B` data value - so unwrap it
                currSym = UnBData (fst mpair);
                -- The 'Map' 'TokenName' 'Integer'. It's wrapped as a `Map` data value - so unwrap it.
                -- (delayed - may not be used)
                tokMap = # (UnMapData (snd mpair))
              in
                (if currSym ==b 0x then
                  -- The ada currency symbol is an empty bytestring (i.e 0x).
                  fold
                    (\acc tokIntPair ->
                      let
                        -- 'TokenName'. It's wrapped as a `B` data value - so unwrap it.
                        tokName = UnBData (fst tokIntPair);
                        -- 'Integer'. It's wrapped as a `I` data value - so unwrap it. (delayed - may not be used)
                        intVal = # (UnIData (snd tokIntPair))
                      in
                        (if tokName ==b 0x then
                          -- The ada token name is an empty bytestring (i.e 0x).
                          acc +i (! intVal)
                        else
                          -- Not ada currency. Uninterested.
                          acc
                        )
                    )
                    acc
                    (! tokMap)
                else
                  -- Not ada currency. Uninterested.
                  acc
                )
            )
            acc
            m
      )
      0
      vals
    );

    totalAdaValue = totalAdaValueIn (valuesIn txOuts)
  in
    -- Total ada value should be in range (1, 100).
    (if totalAdaValue <i 1
      then traceError "Value is less than 1 :("
      else ! (trace "Value is greater than 1!"
        (# (if totalAdaValue <i 100
          then trace "Value is less than 100!" True
          else traceError "Value is greater than 100 :("))))
  )
```

Wooh, that's a lot to unfold. But you got this! Pull in the documentation on [`ScriptContext`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Contexts.html#t:ScriptContext), and [`Value`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Value.html#t:Value) and follow along!

The top level let bindings are pretty basic - it's a bunch of synonyms to builtin functions, all set up with the forces. These will be generally useful across all Pluto programs. Amongst them, is `fold`-
```hs
fold = (\f ->
  fix
    (\self acc xs ->
      if null xs then
        acc
      else
        self (f acc (first xs)) (rest xs)
    )
)
```
We're using our knowledge about [recursing with fixpoint combinators](#recursion) here! Notice that, in the case of folding, throughout the recursion steps, the folding function always stays constant. So we make a closure capturing `f` as a constant and recurse on that! Similar to how you would do-
```hs
fold f acc' l' = inner acc' l'
  where
    inner acc l = ...
```

What else is interesting amongst the top level bindings? Oh I know-
```hs
fieldsOf = (\x -> ! ! SndPair (UnConstrData x));
constructorOf = (\x -> ! ! FstPair (UnConstrData x));
```
Recall that `Constr` holds a constructor id alongside its fields. `UnConstrData` returns those 2 things in a pair! The first member is, of course, the constructor id. The second, is a builtin list of `Data`. All the fields are represented by `Data`!

In the rest of the program, we gradually take apart script context to get the `txInfoOutputs` (of type `[TxOut]`). Each `TxOut` contains a `Value`. We use `valuesIn` to extract those values out to get a `[Value]`. Finally, we fold on it to sum up all the ada, and boom - we have our total!

Along the way, we do a *lot* of `UnConstrData`, to unpack `Constr` data values, `UnListData`, to unpack `List` data values (when a field is a list in Haskell ADT), and `UnMapData` (when a field is a [`map`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-AssocMap.html#t:Map) in Haskell ADT).

> Aside: Remember that you can always try deconstructing a mock `ScriptContext` in Pluto to try and see what fields look like what. Build a mock `ScriptContext` in Haskell and just pass it in! `UnConstrData` on that argument as the first step (since `ScriptContext` is a `Constr` data), look at the returned value - then accordingly use other builtin functions to operate on the return value! You can even gradually remove some of the logic from the Pluto program above and return each field (e.g `txOuts`) to see their representation and proceed accordingly!

The final snippet of interest, is-
```hs
if totalAdaValueIn (valuesIn txOuts) <i 1
  then ! (trace "Value is less than 1 :(" (# Error))
  else ! (trace "Value is greater than 1!"
    (# (if totalAdaValue <i 100
      then trace "Value is less than 100!" True
      else ! (trace "Value is less than 100!" (# Error)))))
```

> Aside: You should ideally implement a function like `check` to implement something like the above in production. This is just for an example!

Woah, what's with all those delays and forces? Recall that function call is strict, so the second argument to `trace` will be evaluated *before* the trace message is logged!

This isn't always a super important detail. After all, you *want* to evaluate `trace`'s second argument sooner or later anyway. But notice what happens when you do-
```hs
-- test.pluto
let
  trace = (\s a -> ! Trace s a)
in trace "foo" (trace "bar" 42)
```
```sh
$ pluto run test.pluto
Traces
------
bar
foo

Result
------
Constant () (Some (ValueOf integer 42))
```
See the problem? `bar` got logged first! Sometimes, you *don't* want that. So you use [delay and force](#delay-and-force)!
```hs
-- test.pluto
let
  trace = (\s a -> ! Trace s a)
in ! (trace "foo" (# (trace "bar" 42)))
```
```sh
$ pluto run test.pluto
Traces
------
foo
bar

Result
------
Constant () (Some (ValueOf integer 42))
```
Much better! And that's basically all you see on that `if-then-else` chain. Nothing too special.

You'll also notice some usages of delays and forces in let bindings in the actual program logic above. This is to [avoid extra work](#intermission-uplc-is-strict). All of the bindings in a `let` are computed before the code in `in` is computed. Sometimes, you want to bind a bunch of stuff in `let` for clarity, some stuff that won't actually be used depending on the conditional branches taken inside your `in`. So I delay the bindings that *may not* be used, and force them as use site.

You should be *very* careful not force a delayed binding **more than once** though. Otherwise, you'll be duplicating work every time you force it! Force it once and bind it to a variable/argument!

## Testing and Benchmarks
It's finally time, we get to see all of that machinery in action! As usual, [load it up into Haskell](#intermission-loading-pluto-into-haskell) and bind it to a variable.
```hs
validatePaymentPluto :: Script
```

We also have the Plutus Tx version loaded-
```hs
plutusScript :: Script
plutusScript = fromCompiledCode
  ($$(PlutusTx.compile [|| validatePayment ||]) `PlutusTx.applyCode` PlutusTx.liftCode pubKeyHash)
```
We do need to feed in a `pubKeyHash :: PubKeyHash`. Let's feed that into the Pluto version as well-
```hs
import qualified Plutus.V1.Ledger.Scripts as PlScr

plutoScript :: Script
plutoScript = validatePaymentPluto `PlScr.applyArguments` [PlutusTx.toData pubKeyHash]
```

Now we're on even grounds! Let's pass in a mock script context and evaluate it using `evalWithArgs`. Here's a mock `ScriptContext`-
```hs
mockCtx :: ScriptContext
mockCtx =
  ScriptContext
    (TxInfo
      mempty
      [ TxOut (Address (PubKeyCredential pubKeyHash) Nothing) (integerToAdaValue 0) Nothing
      , TxOut (Address (PubKeyCredential "ab") Nothing) (integerToAdaValue 10) Nothing
      ]
      mempty
      mempty
      mempty
      mempty
      (interval (POSIXTime 1) (POSIXTime 2))
      ["abcd", "0123"]
      mempty
      ""
    )
    (Minting (CurrencySymbol ""))
```
It should fail since it doesn't have a valid amount of ada at `pubKeyHash`-
```hs
> evalWithArgs [toData (), toData (), toData mockCtx] plutusScript
Left (EvaluationError ["Invalid value."] "(CekEvaluationFailure,Nothing)")
> evalWithArgs [toData (), toData (), toData mockCtx] plutoScript
Left (EvaluationError ["Value is less than 1 :("] "(CekEvaluationFailure,Nothing)")
```
> Aside: We pass in unit as the datum and redeemer argument since we don't care about it. They are ignored anyway.

Great! How about a valid mock `ScriptContext`?
```hs
mockCtx :: ScriptContext
mockCtx =
  ScriptContext
    (TxInfo
      mempty
      [ TxOut (Address (PubKeyCredential pubKeyHash) Nothing) (integerToAdaValue 0) Nothing
      , TxOut (Address (PubKeyCredential pubKeyHash) Nothing) (integerToAdaValue 10) Nothing
      ]
      mempty
      mempty
      mempty
      mempty
      (interval (POSIXTime 1) (POSIXTime 2))
      ["abcd", "0123"]
      mempty
      ""
    )
    (Minting (CurrencySymbol ""))
```
10 ada is just fine!
```hs
> evalWithArgs [toData (), toData (), toData mockCtx] plutusScript
Right (ExBudget {exBudgetCPU = ExCPU 650403466, exBudgetMemory = ExMemory 1862224},["Correct value!"],Delay () (LamAbs () (Name {nameString = "i", nameUnique = Unique {unUnique = 625}}) (Var () (Name {nameString = "i", nameUnique = Unique {unUnique = 625}}))))
> evalWithArgs [toData (), toData (), toData mockCtx] plutoScript
Right (ExBudget {exBudgetCPU = ExCPU 48572016, exBudgetMemory = ExMemory 116858},["Value is greater than 1!","Value is less than 100!"],Constant () (Some (ValueOf bool True)))
```
Now we're in business. They both succeed correctly but look at that CPU and Memory consumption!
| Version  | CPU        | Memory   |
| -------- | ---------- | -------- |
| Plutus   | 650403466  | 1862224  |
| Pluto    | 48572016   | 116858   |

*Efficiency*, [as promised](#preamble-why-pluto).

# Thumb rules for auditing/understanding/writing Pluto

* Don't forget to handle laziness/strictness! [Pluto is strict](#intermission-uplc-is-strict), you need to know how to [delay and force](#delay-and-force) things! Don't do more work than necessary. Don't evaluate function arguments strictly if you need short circuting (e.g `IfThenElse`, `ChooseList`, `ChooseData` etc). Don't evaluate function arguments strictly if you need the function logic to happen before the argument computation.
* Remember to apply the [correct number of forces on the builtins](#plutus-core-builtin-functions) that need them! Otherwise, they just [won't work](#unexpectedbuiltintermargumentmachineerror---a-builtin-received-a-term-argument-when-something-else-was-expected).
* A possible source of confusion is the discrepancy between return values from Plutus Tx validators and Pluto validators. You may notice that, upon success, Plutus Tx validators return a **delayed lambda**. It's essentially a `# (\x -> x)` - the delayed id function. When you write validators in Pluto, you will most likely be returning `()`, i.e Unit.

  For whatever reason, Plutus Tx seems to compile `()` (unit) into a `# (\x -> x)`. You can totally match the Plutus Tx behavior in Pluto by returning a `# (\x -> x)` on success, instead of `()`. But you really don't have to. The return value doesn't matter. If the script doesn't `Error`, it means the validator/minting policy succeeded.
* Try to minimize the number of builtin function calls. Comparing `I` data values (when you know *for sure* both are `I` data, of course)? Don't bother unwrapping the integers with `UnIData` and finally using `EqualsInteger` (or `==i`) on them. Just use `EqualsData` (or `==d`)!
* Don't duplicate work! Unlike Haskell, where thunks never re-do their work if forced twice, forcing a delayed expression *will* evaluate it no matter what.

  ```hs
  let
    fd = # <big computation>
    func = (\x y -> <use x and y here>)
  in func (! fd) (! fd)
  -- ^ DUPLICATE WORK!
  ```

  `fd` here is a delayed expression. Forcing it twice *will evaluate it **twice***. You probably don't want this. Instead, compute once, bind it to some variable and use that instead.
* Don't assume the constructor id for `Constr` data values! Initially, I actually assumed that `PlutusTx.toData Nothing` translates to `Constr 0 []`. But it doesn't! It's actually `Constr 1 []`. The constructor id of `Nothing` is `1`, not `0` - as I initially assumed.

  To find out what id each constructor has, check the ADT's `makeIsDataIndexed` implementation! This is what the `Maybe` impl looks like-
  ```hs
  PlutusTx.makeIsDataIndexed ''Maybe [('Just, 0),('Nothing, 1)]
  ```
  See? `Nothing` is `1`, not `0`. Treating `Nothing` as `Just` and vice versa would be a silly bug to have!

# Common Issues
## Using operators without explicit parens causes weird behavior
This is a known issue - [#9](https://github.com/Plutonomicon/pluto/issues/9). For now, try to use parens to explicitly mark associativity-
```hs
(1 +i 1) +i 1
```

## Unexpected `\` near a lambda
Surround the lambda in parentheses!
```hs
let
  f = \x -> x
--     ^ INVALID!
in ...
```
Should be-
```hs
let
  f = (\x -> x)
in ...
```

## Unexpected `in`
You probably have a trailing semicolon in your let bindings. This is invalid-
```hs
let
  x = 1;
  y = 2;
--     ^ INVALID!
in x +i y
```
Should be-
```hs
let
  x = 1;
  y = 2
in x +i y
```
## Unexpected `=` within `let` binding
You probably forgot a semicolon in one of your let bindings!
```hs
let
  x = 1
-- INVALID!
  y = 2
in x +i y
```
Should be-
```hs
let
  x = 1;
  y = 2
in x +i y
```
## `UnexpectedBuiltinTermArgumentMachineError` - A builtin received a term argument when something else was expected
You probably did not apply enough forces to a builtin function. Check out [Builtin Functions](#plutus-core-builtin-functions)!

# Extra: Useful Links
* [Builtin lists](./builtin-lists.md)
* [Builtin pairs](./builtin-pairs.md)
* [Builtin functions](./builtin-functions.md)
* [Builtin data](./builtin-data.md)
* [Plutus builtin functions](https://staging.plutus.iohkdev.io/doc/haddock//plutus-tx/html/PlutusTx-Builtins-Internal.html)
* [Plutus Core builtin function identifiers, aka `DefaultFun`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultFun)
* [Plutus Core types, aka `DefaultUni`](https://staging.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultUni)