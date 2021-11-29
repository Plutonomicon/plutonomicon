Scripts are currently stored in the transaction in which they are needed. This means that your scripts must be extremely small, given that the limit on transaction sizes is 16 KiB.

To give some reference, an **empty** script using `wrapValidator` is currently 2541 bytes.

Scripts should optimally not be any bigger than 5 KiB, since multiple scripts may be needed in the same transaction.

There are various workarounds, which I will explain here.

See  [Plutus issue #4174](https://github.com/input-output-hk/plutus/issues/4174) for a summary of script size issues, and ideas for optimizing them at the compiler level.

## Avoid referencing code

PlutusTx doesn&#39;t do any dead code elimination, which means the entire transitive closure of your script will be included on-chain.

## Avoid referencing data types

Referenced data types cause PlutusTx to generate constructors and destructors for the data type using some lambda encoding (likely Scott encoding).

Because of this, you want to avoid referencing unnecessary data types.

In addition, `newtype`s also increase code bloat, so avoid `newtype` on-chain.

[Spooky](https://gitlab.com/fresheyeball/plutus-tx-spooky) is one technique that can be used to avoid referencing the ScriptContext, and avoid parsing it as well.
careful use of `Spooky` types will allow you to only parse the fields you need, while maintaining the minimal typed footprint necessary for your smart contract. this has been observed to save 2k of the script's initial overhead (by abandoning the Typed Validator abstraction and instead using `Spooky` in the untyped validator script).

## Avoid using complex functionality from Plutus

Certain non-trivial functionality from Plutus general bigger scripts. In particular, avoid using these:

- [StateMachine](https://github.com/input-output-hk/plutus-apps/issues/11)
- Anything using `TxConstraints` (they are okay in offchain code)

## Use your own `FromData`

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

A general trick that can save you 2 KiB, is using your own alternative to `ScriptContext`. `ScriptContext` is a complex data type, that references many other data types. Since you often won&#39;t access most of it, replacing it with a data type that decodes in the same way can save you a lot of space. This trick can also be applied to your datums and redeemers, although to a lesser extent.

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

## Don&#39;t mint multiple tokens of different minting policies in the same transaction

Each minting policy will increase the size of your transaction considerably. If possible, do it in multiple transactions.

The same applies to inputs locked by validators, although it is more rare to depend on multiple inputs locked by different validators.

## Do not pass error codes / Use partial functions

Textual error codes are a big cause of code bloat. While you can use sum types to save space, they are still completely unnecessary.

Rather than explicitly handling errors as is common practice in the off-chain world,

use partial functions as much as possible. This means using `error` to handle bad cases.

## Use conditional traceIfFalse

It&#39;s nice to have readable messages to be able to trace the cause of the problem in the script. But messages also occupy space in script. To resolve that we can define custom function to report errors and switch it to identity in production code:

```haskell
{-# INLINEABLE debug #-}
debug :: BuiltinString -> Bool -> Bool
debug = const id -- traceIfFalse
```

## Use patterns that break to save on alternatives

Often we need to read unique `TxOut` and we know that in inputs and outputs there is only one `TxOut`  with given properties. If there are many of them it means that script is wrong. So instead of writing code for both of the cases:

```haskell
case unqueElement (getContinuingOutputs ctx) of
  Just x  -> condition x
  Nothing -> False
```

We can rely on breaking of the script inside the pattern as a `False`-condition and save space on it:

```haskell
let [!x] = getContinuingOutputs ctx
in  condition x
```

The same for Maybe (for example in parsing datums) and other branching types. If we expect certain alternative we can omit other cases. Validator will break on them and be invalid.

Also instead of chain of maybes:

```haskell
maybe False id $ do
  out <- getTxOut ctx
  dat <- getDatum ctx out
  x <- parseDatum dat
  pure (x == expected)
```

We can just write

```haskell
let Just !out = getTxOut ctx
    Just !dat = getDatum ctx out
    Just !x = parseDatum dat
in  x == expectd
```

If we know that `TxOut` has to be there with certain type of datum.

## Simplify logic

If nothing helps and script is still too big think on ways to simplify the logic:

-  Maybe we can assume that some users are trusted and they are going to build TX in a good way and we can skip some checks. 
- Sometimes we can duplicate checks across several scripts that are packed in single TX. To simplify checks we can check that certain NFT is present or certain redeemer is used on spending and place all checks into one script. Watchout for checks in neighbor contracts that are used in the single TX that duplicate each other.
- We can forward checks in mints to make them lightweight and delegate checks to the other contract.
- Maybe we can split the logic of single contract across several contracts. For example if state of the contract is sum of A and B and A expects different set of the redeemers than the B we can split it to two separate contracts that turn one state to to another.
- Sometimes it helps to join two contracts into one bigger one. It does not help with script size but if they always are included in the same TX the size of two scripts that sit in separate UTXOs is a little bit bigger than if it has single UTXO dedicated to it. Beware that at the end it is the size of whole TX that matters most.
- 

## The If-Then-Else Trick (mem/cpu optimization)
- Since Plutus Boolean operations do not short-circuit, you can use If-Then-Else to create short-circuits.
- this PR shows the patterns, as well as hoping to merge tools directly into plutus to help with this https://github.com/input-output-hk/plutus/pull/4191
