# Fundamentals of Plutus

_Our goal is to write "decentralized apps" (dapps) that work on Cardano, but what is such an app in the first place?_

There are two big parts to Cardano: The consensus algorithm and ledger model. When we are writing dapps, we do not care about the consensus algorithm, we only assume it to be perfect, i.e. that there is a global ledger which everybody agrees on.

## Resources

NB: We are currently in Alonzo.

1. [https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V2-Ledger-Contexts.html#t:TxInfo](https://staging.plutus.iohkdev.io/doc/haddock/plutus-ledger-api/html/Plutus-V2-Ledger-Contexts.html#t:TxInfo)
1. [https://iohk.io/en/research/library/papers/native-custom-tokens-in-the-extended-utxo-model/](https://iohk.io/en/research/library/papers/native-custom-tokens-in-the-extended-utxo-model/)
1. [https://github.com/input-output-hk/cardano-ledger/tree/master/eras/alonzo/test-suite/cddl-files](https://github.com/input-output-hk/cardano-ledger/tree/master/eras/alonzo/test-suite/cddl-files)
1. [https://hydra.iohk.io/job/Cardano/cardano-ledger-specs/specs.alonzo-ledger/latest/download-by-type/doc-pdf/alonzo-changes](https://hydra.iohk.io/job/Cardano/cardano-ledger-specs/specs.alonzo-ledger/latest/download-by-type/doc-pdf/alonzo-changes)
1. [https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/index.html](https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/index.html)
1. [https://plutus-apps.readthedocs.io/en/latest/](https://plutus-apps.readthedocs.io/en/latest/)
1. [https://github.com/input-output-hk/plutus/blob/master/plutus-core/cost-model/CostModelGeneration.md](https://github.com/input-output-hk/plutus/blob/master/plutus-core/cost-model/CostModelGeneration.md)
1. [https://github.com/input-output-hk/plutus/blob/master/plutus-core/cost-model/data/builtinCostModel.json](https://github.com/input-output-hk/plutus/blob/master/plutus-core/cost-model/data/builtinCostModel.json)
1. [https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-Builtins-Internal.html](https://staging.plutus.iohkdev.io/doc/haddock/plutus-tx/html/PlutusTx-Builtins-Internal.html)

## Overview

Essentially, the ledger is a list of blocks, where each block is a list of transactions. Transactions have inputs, outputs, and some associated metadata. Outputs can only be consumed once, and only by transactions in a future block. Therefore we refer to unconsumed outputs (available outputs) as UTXOs. The transactions form a directed acyclic graph, with a vertex for each transaction, and an edge from each output to its corresponding input.

## Scripts

Scripts in Cardano can either fail or succeed, and can not cause any side effects. Concretely, it is essentially strictly evaluated untyped lambda calculus, with some extra built-in functions for handling on-chain data types (such as integers), and a built-in function for aborting the evaluation, `error`.

The functionality you want is then expressed through what kind of transactions you allow consuming the UTXO.

### Script sizes

You should be very careful with how big you make your scripts. Scripts are currently stored in every transaction that consumes them, meaning that they will quickly cause you to go past the (current) transaction size 16 KiB limit. It depends on the structure of transaction but keep in mind that beside scripts there are other items (datums, redeemers, signature, etc) on Tx and we need to have space for that.



Note that we need to have some headroom on size because number of inputs is unpredictable and we should have some space for extra inputs and change that user pays back to own wallet.

### Execution limits

In addition to transaction sizes, scripts are also bounded by the amount of time and space they can use. The current limits (accessible in resource 5) are 10,000,000 `exUnitsMem` and 10,000,000,000 `exUnitsSteps`.

The exact meaning of these are defined via cost model for Plutus scripts. The current costs for various parts of Plutus can be found in resources 8.

### Script references

Scripts are content-addressed, and referenced by their SHA2-256 hash.

Therefore, you can not have two scripts that reference each other.

A script can always access its own hash at execution time.

### Boolean return

While scripts may be "boolean" in nature, they do not actually return a Scott-encoded boolean. Scripts wrapped with `wrapValidator` and similar, are simply wrapped with a function `check` that calls `error` is the returned value is `False`.

### Available built-ins

A list of built-in functions is available in resource 9.

### `BuiltinData`

Any data that scripts read from the outside world, e.g. datums and redeemers, is represented as `BuiltinData` within the script.
This is essentially a sum type of the various available built-in types in UPLC (except e.g. functions and unicode strings).

(NB: `Data` is the off-chain equivalent to `BuiltinData`. They are morally the same thing.)

The Plutus Haskell libraries make use of the `UnsafeFromData` typeclass for converting on-chain data to "PlutusTx-native"
data types.
PlutusTx represents data types using Scott encoding, meaning that a value of a data type is transformed into a function
with n parameters for n constructors, and calls the m'th argument with the arguments given to the m'th constructor.
This is also true of `ScriptContext`, and the type you use to represent your datum and redeemer.
`unsafeFromBuiltinData :: UnsafeFromData a => BuiltinData -> a` will convert a value encoded as a `BuiltinData` into its
Scott encoding. In the case of failure, `error` will be called, and the transaction will fail.

As for how data types as encoded as `BuiltinData`, each constructor is represented as the `Constr` case of `Data`.
You can use `unsafeDataAsConstr :: BuiltinData -> BuiltinPair BuiltinInteger (BuiltinList BuiltinData)` to manually
decode it. The integer will generally correspond to the index of the constructor, defined in the call to
`PlutusTx.IsData.makeIsDataIndexed`. The arguments passed to the constructor are contained in the list.

## UTXOs (unconsumed transaction outputs)

There are rules for whether a transaction can consume a UTXO.

Each UTXO is associated with either a script (validator) or a public key hash.

If it's a public key hash, then a transaction can only consume the UTXO if it contains a signature by the public key in question.

If it is a validator, then the validator will be run with three arguments, in the following order:

- The datum, the **hash** of which is attached to the UTXO.
- The redeemer, which is attached to the **consuming** transaction.
- The script context, which contains the consuming transaction itself in addition to some auxiliary information.

Through this functionality, you can simulate a state machine, where each transaction corresponds to one transition of the state machine from one state to another.

This is done by checking the consuming transaction's outputs, and asserting that there is exactly one output **locked** with the same validator (referenced by its hash), and that its associated datum and value is correct.

### Minimum Ada limit

Each UTXO must have a specific minimum amount of Ada contained, dependent on the size of the UTXO. Currently, it is generally above 1 Ada.

## Values

Each UTXO can contain _value_, which are collections of tokens. Each token has a quantity, a name, and is associated with a minting policy hash (a script hash).

Ada has an empty name, and the minting policy hash it is associated with is _empty_.

Values, like UTXOs, can not be duplicated in general.

### Minting policies

Minting policies control whether you can mint or burn a token. They are scripts that are called with the following two arguments in order:

- The redeemer
- The script context

Both of these are the same as in the case of validators. A minting policy is called on a transaction, when that transaction either tries to mint or burn a token associated with the hash of the minting policy. The minting policy must succeed for the transaction to be accepted.

Minting 0 of a token is not possible using the standard Plutus libraries, though it is unknown to me whether you can make such a transaction manually.

## Fees

Fees are consumed as part of each transaction. Fees depend on the size of the transaction and the cost of the scripts run, as explained further above.

The fees necessary for a transaction are known **ahead of time**. Fees will be collected from the inputs of the transaction, so you must make sure that your script allows having extra inputs with Ada to pay the fees.

### Transaction failure

You might be wondering what happens if a transaction fails. It is after all very common for a transaction to fail. If we model some global state on the ledger through a global "state machine", then there can not be two transactions that consume this UTXO in the same block. In such a case, one of the transactions will be rejected and fail.

Transaction failure in Cardano is split up into 2 parts, general failure and script failure.

Script failure is when the scripts fail (i.e. they call `error`), and in such a case, the **collateral** will be paid as fees.

The collateral fee is higher than the standard fee, and exists in order to prevent DoSing the blockchain through submitting failing scripts that consume a lot of time and space (relatively).

If the transaction fails due to other reasons, for example input unavailability, then no collateral fee nor standard fee will be paid, ensuring that you lose nothing due to UTXO contention.

## Datums and datum hashes

UTXOs do **not** contain the datum itself. They only contain the hash. This distinction is very important, as a transaction may not actually contain the datum that corresponds to that hash. A transaction contains a mapping from input and output datum hashes to datums in `txInfoData`. Though the name says "data", AFAIK, it is restricted to the hashes of the datums in the inputs and outputs of a transaction unfortunately.

The datums for the inputs are always contained in `txInfoData`. Anything else may not be present. If you in your script depend on the datum for an output being available, you must make sure when submitting the transaction that you include the datum in `txInfoData`. If it isn't included, the worst thing that can happen is that the transaction fails, so it is not a huge worry.

### Calculating hashes on-chain

This is currently infeasible, as there is no built-in function to do so. You must manually serialize the datum into CBOR as a `BuiltinByteString`, then hash that using `sha2_256`. In the future, there will be a way to hash data on chain:

- [https://github.com/input-output-hk/plutus/issues/4167](https://github.com/input-output-hk/plutus/issues/4167)
