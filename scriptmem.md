# Optimizations to reduce CPU and Mem consumption

In order to have an insight of which parts of the plutus script that are responsible for significant memory and cpu consumption, it is recommended to use the profiling tool made available in the plutus repository. Note that the profiling tool requires compiling plutus scripts to insert profiling instructions necessary for assessing performance. The profiling tool also requires the plutus script to be fully applied, which means that all the arguments to the plutus script (i.e. datum, redeemer and script context) shall also be produced. The profiling documentation can be found at [Profiling Scripts](https://plutus.readthedocs.io/en/latest/plutus/howtos/profiling-scripts.html).

The various workarounds and optimizations that can help in reducing the plutus script size as well as the execution steps and memory execution units are described in the subsequent sections.

## Avoiding higher-order functions and closures
The use of higher-order functions is a common programming paradigm to facilitate code reuse. Higher-order functions are widely used in the plutus library but may have a significant impact on cpu and memory consumption especially when functions passed as arguments contain closures. It is therefore recommended to rewrite specialized versions to avoid closures as far as possible. For instance, the plutus function `findOwnInput` makes use of the higher order function `find`  to search for the current script input.

```haskell
findOwnInput :: ScriptContext -> Maybe TxInInfo
findOwnInput ScriptContext{scriptContextTxInfo=TxInfo{txInfoInputs},                   
                           scriptContextPurpose=Spending txOutRef} =
    find (\TxInInfo{txInInfoOutRef} -> txInInfoOutRef == txOutRef) txInfoInputs
findOwnInput _ = Nothing
```

As can be seen, the reference to `txOutRef`, within the function’s body passed as argument to find, introduces a closure. This can increase cpu and memory consumption especially when list `txInfoInputs` contains several elements. If only the `TxOut` script input is required, `findOwnInput` can be rewritten as follows to avoid closures and to save on `Maybe` constructs.

```haskell
{-# inlinable ownInput #-}
ownInput :: ScriptContext -> TxOut
ownInput (ScriptContext t_info (Spending o_ref)) = getScriptInput (txInfoInputs t_info) o_ref
ownInput _ = traceError "script input not found !!!"

{-# inlinable getScriptInput #-}
getScriptInput :: [TxInInfo] -> TxOutRef -> TxOut
getScriptInput [] _ = traceError "script input not found !!!"
getScriptInput ((TxInInfo tref ot) : tl) o_ref
  | tref == o_ref = ot
  | otherwise = getScriptInput tl o_ref
```

## Adding strictness on accumulators in recursive functions
When the definition of recursive functions is necessary (e.g., to avoid closures in higher-order functions or for computation), a tail recursive style should be favoured as far as possible with the use of accumulators (whenever required). Strictness should also be specified for accumulators passed as parameters. For instance, the `length` function on list can be defined as follows:

```haskell
length :: [a] -> Integer
length l = go 0 l
  where
    go acc []  = acc
    go !acc (_: tl) = go (acc + 1) tl
```

## Common expression elimination
When several instances of identical expressions exist within a function’s body, it’s worth replacing them with a single strict variable to hold the computed value. In the following code excerpt,

```haskell
let a’ = a `divide` n * c
    b’ = b * (n * c)
    C’ = c + (n * c)
in 
  foo a’ b’ c’ n
```

the cost of storing and retrieving n * c in a single variable is significantly less than recomputing it several times.
 
```haskell
let !t_mul = n * c
    a’ = a `divide` t_mul
    b’ = b * t_mul
    C’ = c + t_mul
in 
  foo a’ b’ c’ n
```


## Avoid monad do notation to handle pattern match failure
The monadic do notation should be avoided as far as possible as extra computations are implicitly introduced to handle pattern match failures.
 
