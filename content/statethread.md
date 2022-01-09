# State Thread Token Pattern

In the EUTXO model as in Plutus, validator scripts carry the role of validating transactions which spend _inputs_ locked to a script address.

## A simple example



![](https://static.slab.com/prod/uploads/pigzq8jp/posts/images/H7u0BsduHLFO-3YoFRN2AH2e.svg)



In the above example, the validator can correctly validate the spending of an EUTXO locking currency amounts, with a Datum representing an accounting model.

We can confirm the validity of any UTXO at the script address **if and only if** the transaction which created it spends an input from the script address, running the validator.

## Datum Spam

The problem with the above example is that the validator only checks transactions which spend from the script address.

So a transaction can bypass the validator and submit spam Datums to the script address:

![](https://static.slab.com/prod/uploads/pigzq8jp/posts/images/xd6LhwB5sZ9rITBaRHMBcYjd.svg)



In essence, validators control the _input_ but not the _output_ of transactions.

## State-Thread Tokens

To validate the output of transactions, we have a trick up our sleeves -

Native token Minting Policies will check any transaction which _mints_ their associated token, so we can create a token which we attach to an initial Datum output at the script address.

Other policies may be used, such as deferring to a "parent" validator (such as governance) but the simplest way to do this is with a 'one-shot' minting policy which uses a unique TxOut to mint an _NFT_-like token which may only be minted oncce.

If desired, the policy can also be used to validate the initial value of the Datum output.

This token can then be used to represent a unique _state-thread_ which the validator can ensure never leaves the script.

```haskell
stateThreadPolicy :: TxOutRef -> () -> ScriptContext -> Bool
stateThreadPolicy spend _ ctx@ScriptContext {scriptContextTxInfo = txInfo@TxInfo { txInfoInputs } } =
  (fmap txInInfoOutRef txInfoInputs) == [spend]
    && ... -- check initial datum
```



![](https://static.slab.com/prod/uploads/pigzq8jp/posts/images/A4SRD7Rfi4fpcZEbPtk1UNEB.svg)



Now, the validator ensures that the state-thread token remains attached to a valid datum at the script address.



![](https://static.slab.com/prod/uploads/pigzq8jp/posts/images/uv6R7nvu479ruFzPjVHNxYsj.svg)
