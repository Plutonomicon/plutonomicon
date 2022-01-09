# Script optimisations

## Script size optimisations

Scripts are currently stored in the transaction in which they are needed. This means that your scripts must be extremely small, given that the limit on transaction sizes is 16 KiB.

To give some reference, an **empty** script using `wrapValidator` is currently 2541 bytes.

You must carefully consider the sizes of your scripts, as you will often have multiple
in the same transaction, e.g. one script for your validator and one for minting a token.

There are various workarounds, which I will explain here.

See [Plutus issue 4174](https://github.com/input-output-hk/plutus/issues/4174) for a summary of script size issues, and ideas for optimizing them at the compiler level.

### Avoid referencing unnecessary data types

Referenced data types cause PlutusTx to generate constructors and destructors
for the data type using some lambda encoding (likely Scott encoding).
Because of this, you want to avoid referencing unnecessary data types.

See https://github.com/input-output-hk/plutus/issues/4147

In addition, `newtype`s also increase code bloat, so avoid `newtype` on-chain.
The reason for this is unclear.

[Spooky](https://gitlab.com/fresheyeball/plutus-tx-spooky) is one technique that
can be used to avoid referencing the ScriptContext, and avoid parsing it as well.
careful use of `Spooky` types will allow you to only parse the fields you need,
while maintaining the minimal typed footprint necessary for your smart contract.
This has been observed to save 2k of the script's initial overhead (by abandoning
the `TypedValidator` abstraction and instead using `Spooky` in the untyped validator script).

### Avoid using complex functionality from the Plutus libraries

The use of non-trivial functionality from Plutus tend to generate bigger scripts. In particular, avoid using these:

- [StateMachine](https://github.com/input-output-hk/plutus-apps/issues/11)
- Anything using `TxConstraints` (they are okay in offchain code)

### Use Plutarch or Pluto

PlutusTx doesn't generate optimal code currently, but will in any case never be the optimal
tool for the job. We need a way of precisely specifying the code that goes on-chain.

There are essentially two solutions to this:
- [Pluto](https://github.com/Plutonomicon/pluto): An assembler for raw UPLC.

  [Guide on Pluto](https://github.com/Plutonomicon/pluto/blob/main/GUIDE.md)
- [Plutarch](https://github.com/Plutonomicon/plutarch): A typed eDSL for generating UPLC.

  [Guide on Plutarch](https://github.com/Plutonomicon/plutarch/blob/master/docs/GUIDE.md)

I (@L-as) would personally recommend that you go for Plutarch, as it is much more ergonomic
in my opinion, but I am biased as I am the author of Plutarch.

### Use untyped validator

Avoid `TypedValidator` and use `mkValidatorScript`. Use a "wrapping" validator that decodes the arguments before calling the actual validator with typed arguments:

```haskell
validatorUntyped :: BuiltinData -> BuiltinData -> BuiltinData -> ()
validatorUntyped datum redeemer ctx =
   check $ validator (unsafeFromBuiltinData datum) (unsafeFromBuiltinData redeemer) (unsafeFromBuiltinData ctx)
```

Offchain code using `submitTxConstraints` requires a `TypedValidator`, but you can create one from the untyped validator using:

```haskell
typedValidator :: TypedValidator Any
typedValidator =
  unsafeMkTypedValidator validator
```

### Use your own `FromData`

`wrapValidator` essentially wraps the arguments of your validator in `unsafeFromBuiltinData`.

Here is a more general version of it:

```haskell
{-# INLINABLE myWrapValidator #-}
myWrapValidator
    :: forall d r p
    . (UnsafeFromData d, UnsafeFromData r, UnsafeFromData p)
    => (d -> r -> p -> Bool)
    -> BuiltinData
    -> BuiltinData
    -> BuiltinData
    -> ()
myWrapValidator f d r p = check (f (unsafeFromBuiltinData d) (unsafeFromBuiltinData r) (unsafeFromBuiltinData p))
```

A general trick that can save you 2 KiB, is using your own alternative to `ScriptContext`. `ScriptContext` is a complex data type, that references many other data types. Since you often won't access most of it, replacing it with a data type that decodes in the same way can save you a lot of space. This trick can also be applied to your datums and redeemers, although to a lesser extent.

The trick is to do something like this:

```haskell
data AScriptPurpose = ...

PlutusTx.makeIsDataIndexed ''AScriptPurpose [...]

data AScriptContext = AScriptContext
  { aScriptContextTxInfo :: BuiltinData
  , scriptContextPurpose :: AScriptPurpose
  }

PlutusTx.makeIsDataIndexed ''AScriptContext [('AScriptContext,0)]
```

Care must be taken in order to make sure that the call to `makeIsDataIndexed` matches the one for the original data type.

### Don't mint multiple tokens of different minting policies in the same transaction

Each minting policy will increase the size of your transaction considerably. If possible, do it in multiple transactions.

The same applies to inputs locked by validators, although it is more rare to depend on multiple inputs locked by different validators.

### Use partial functions

Error handling, while good programming practice, is unfortunately not something we can afford.
Rather than using `Maybe`, `Either`, any other kind of functionality for handling incorrect cases,
just call `error` or similar. Use incomplete matches.

E.g. go from:
```haskell
f x >>= \y -> g y
```
to:
```haskell
g (f x)
```
Where you make `f` and `g` partial.

### Strip out traces

Traces occupy a lot of space in the generated code. You can strip out all traces
optionally as described here: https://github.com/input-output-hk/plutus/pull/4219

See all PlutusTx options here: https://github.com/input-output-hk/plutus/blob/ef3fa70d76f6be8cc9f211a34ca5e069212d485e/plutus-tx-plugin/src/PlutusTx/Plugin.hs#L64

### Use tokens for cross-transaction predicates.

It is in many situations possible to "outsource" a predicate
to another transaction, that then creates a token as proof of the validation.
You can for example associate the validated data with the token by storing
the hash of the data in the token.

### Remove overlapping checks from scripts

If you have any overlapping checks in scripts that are present
in the same transaction, you can put that functionality into a minting
policy, then in the scripts simply assert that this token has been minted.
This allows both scripts to share code for equivalent predicates.

### Merge scripts that are always used together

Scripts that are always used together will collectively
take up less space if they are merged, as there will be less overhead
dedicated to shared constructs, such as rationals.

### Merkelise your scripts

This is a simple and effective transformation.

If in your scripts you have branches, where potentially only one of them will be executed,
you can put that functionality into a minting policy, then in your branches
replace the predicate with a check for the burning or the minting of a token
with the minting policy.

The actual token is of no use, since only its minting and burning has any significance.

## CPU and memory optimisations

*Main article*: [[scriptmem]]

In addition to tight size limits, there are also tight per-block and
per-transaction CPU and memory limits. If you're not doing batching,
you want to optimise this to make sure you can get in as many transactions
in per block as possible.

### Be aware of strictness

Though Haskell is lazy, function calls in Plutus are strict.
This means that e.g. `&&` evaluates **both** arguments before
doing any boolean operation.

In addition, albeit "laziness" is supported in UPLC, forcing the same thunk
twice will duplicate the work, unlike Haskell.

### The If-Then-Else Trick
- Since Plutus Boolean operations do not short-circuit, you can use If-Then-Else to create short-circuits.
- This PR shows the patterns, as well as hoping to merge tools directly into plutus to help with this https://github.com/input-output-hk/plutus/pull/4191
