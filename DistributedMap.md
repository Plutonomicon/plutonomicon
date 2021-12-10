# Distributed Map

Credit: Marcin Bugaj

Update: [On-Chain Association List With Constant Time Insert/Removal](assoc.md)  provides more efficient implementation of distributed map with all on-chain guarantees discussed below.

## Rationale

One cannot store standard haskell map on datum of a utxo. The size of datum is limited by the maximum transaction size. Since the map may have an arbitrary number of elements we may hit maximum transaction size limits. We can leverage eutxo model to implement a distributed map. That is a map where each entry of a map is stored on a different utxo.

## Overview

To implement such a map we will need:

- a utxo that stores global state of a map, from now on called 'global utxo'
- a utxo per each key-value pair, from now on called 'entry utxo'
- three minting policies

The distributed map has a few notable properties:

- Entries cannot be removed from the map.
- Once a key is added it cannot be removed any more. One can mitigate the limitation by having `Maybe Value` as map value instead of just `Value`. So removing an entry boils down to storing `Nothing`
- The 'global utxo' is used only when adding a new key to the map.
- That means that throughput of adding new keys to the map is limited. Reading and modifying existing entries does not require 'global utxo' and has high throughput (good parallelization).
- It's a real map in a sense that there cannot be key duplicates.
- The cost of adding new keys to the map increases with the number of elements in the map.
- It's provable **on-chain** that ALL entries have been visited when a map is traversed.
- It's provable **on-chain** that a given key is not present in a map. Such proof is a utxo that can be consumed in an arbitrary transaction.

## Main idea

The main idea in the distributed map design is that 'global utxo' keeps track of total number of entries stored in the map and that each 'entry utxo' is indexed/labelled with an integer in the range [0, total number of entries - 1]. Since the keys cannot be removed, each entry is labelled with a unique integer that falls within that range. That makes it possible to prove exhaustiveness of traversal and to prove nonexistence of a key in a map.

We can think of the total number of entries in 'global utxo' as a version number of a map. In that context a version number changes if a new key is added to the map. Such 'version number' does not care about change of values mapped to keys.

## Datums and Redeemers

Following datums and redeemers are used in the map:

```haskell
data Entry = Entry Key (Maybe Value)
type Id = Integer
type TotalElements = Integer
type NFT = CurrencySymbol

data Datum =
    GlobalDatum TotalElements
  | ProofDatum NFT TotalElements Key
  | EntryDatum NFT Id Entry

data Redeemer =
    Update (Maybe Value)
  | CreateProof TotalElements Key
  | AddKey Key
  | UseProof
  | UseEntry
```

**Datums:**

- `GlobalDatum` is present only on 'global utxo'.

That utxo is unique for a map instance. It holds the total number of entries in a map. The 'global utxo' carries an NFT token that uniquely identifies map instance.

- `ProofDatum` is present only on dedicated 'proof utxos'.

Utxo that carries datum constructed with `ProofDatum nft totalElements key` is a proof that a map identified by (the `nft` currency symbol && `totalElements` perceived as a 'version number') does not contain key `key`.

- `EntryDatum` is present only on 'entry utxos'.

`Id` used in the constructor is the unique entry index/label/indentifier

In addition to 'global utxo' and 'entry utxo' a new type of utxo is introduced - 'proof utxo'. We'll see how it is used soon.

**Redeemers:**

- `CreateProof totalElements key` is used in a transaction to create a proof that a map versioned by/containing `totalElements` does NOT contain key `key`
- `AddKey key` is used in a transaction to add a new entry and use `Nothing` as a mapped value.
- `Update`, `UseProof`, `UseEntry` redeemers are self-explanatory.

Let's see how the corresponding transactions look like and what checks the validator is supposed to perform. Then the minting policies will be described.

## Transactions for Add/Update/Use & validator logic

Convention: values in different constructors with the same names are deemed equal. e.g in `ProofDatum nft n key1` and `ProofDatum nft n key2` the values `nft` and `n` in both expressions are the same.

### Adding key

- transaction input:
    - 'global utxo' `GlobalDatum n` consumed with `AddKey key` redeemer
    - 'proof utxo' `ProofDatum nft n key` consumed with `UseProof` redeemer
- transaction output:
    - 'global utxo' `GlobalDatum (n + 1)`
    - 'entry utxo' `EntryDatum nft n (Entry key Nothing)`
    - 'proof utxo' `ProofDatum nft n key`
- validation logic:
    - see the symbols and their relations above
    - input and output 'global utxos' carry one token of `nft` currency symbol

In plain english the validator says:

> Transaction is correct if
> - total number of entries was incremented by one
> - the proof was provided that the key in question is not yet in the map
> - Nothing initialized 'entry utxo' with correct Id was produced
> - 'proof utxo' is return and left intact

### Updating entry

- transaction input:
    - 'entry utxo' `EntryDatum nft id (Entry k _)` consumed with `Update maybeValue`
- transaction output:
    - 'entry utxo' `EntryDatum nft id (Entry k maybeValue)`
- validation logic:
    - see the symbols and their relations above

Validation logic is very simple and does not require neither 'global utxo' nor 'proof utxo'.

### Creating proof

- transaction input:
    - 'proof utxo' `ProofDatum nft (totalElements - 1) k` consumed with `CreateProof totalElements k` redeemer
    - 'entry utxo' `EntryDatum nft (totalElements) (Entry l _)`
- transaction output:
    - `ProofDatum nft totalElements k`
    - unchanged 'entry utxo' from the input
- validation logic:
    - see the symbols and their relations above
    - `k != l`

It's an inductive proof and in plain english it says:

> Transaction is correct if:
> - there is a proof that the map with (totalElements - 1) elements does not contain the given key
> - the (totalElement)th entry is not associated with the given key

### Using entry

- transaction input:
    - 'entry utxo' `EntryDatum nft id (Entry k v)` consumed with `UseEntry`
- transaction output:
    - 'entry utxo' `EntryDatum nft id (Entry k v)`
- validation logic:
    - see the symbols and their relations above

In plain english the validator says:

> 'entry utxo' must be returned and left intact

**Important note**

In addition it is assumed that:

- all input and output 'global utxo' carry the token of currency symbol `GlobalDatumValid nft`
- all input and output 'entry utxos' carry the token of currency symbol `EntryDatumValid nft`
- all input and output 'proof utxos' carry the token of currency symbol `ProofDatumValid nft`
- That should be checked in validators. Minting policies for those tokens are described in the next sections. Those tokens are to ensure that malicious datums are not injected.

## Minting policies

### (GlobalDatumValid nft) token

- validation logic:
    - there is exactly one utxo at the output that carries datum constructed with `GlobalDatum 0` and it carries one token of `nft` currency symbol
    - only one `GlobalDatumValid` token is minted
    - that token goes to `GlobalDatum` utxo that was already mentioned

In plain english the minting policy says:

> when a new distributed map is created the datum must be created with 0 `TotalElements`

### (ProofDatumValid nft) token

- validation logic:
    - there is exacly one utxo at the output that carries datum constructed with `ProofDatum nft 0 _`
    - only one `ProofDatumValid` token is minted
    - that token goes to `ProofDatum` utxo that was already mentioned

In plain english the minting policy says:

> any key is not contained in an empty map

### (EntryDatumValid nft) token

- validation logic:
    - the input contains utxo carrying datum constructed with `GlobalDatum n` and it carries token of `nft` currency symbol
    - the input contains utxo carrying datum constructed with `ProofDatum nft n k` and it carries `ProofDatumValid` token
    - the output contains 'entry utxo' constructed with `EntryDatum nft n (Entry k Nothing)`
    - only one `EntryDatumValid` token is minted
    - that token goes to `EntryDatum` utxo that was already mentioned

Caveat: EntryDatumValid must also be parametrized by currency symbol of ProofDatumValid

# Final notes

## On-chain guarantees

Since 'entry utxos' are indexed with continuous integers and the last index is known, the user may traverse the distributed map and be sure that all entries were visited and exactly once. That may come in handy when folding over entries of a distributed map.

The 'proof utxos' are utxos that hold a proof that a particular key is not contained in a map of a particular version. Those proofs are used when adding a new key to the map. Their use extends far beyond this. Sometimes one needs to know that a value is not present in a map to validate a transaction.

Let's image a voting system. Each user creates vote which is just a utxo with a datum carrying user pkh and its vote. There is also a distributed map that maps users to their voting weights. Also a user not eligible for voting can create own vote utxo. This vote should be ignored of course. For such user there no entry in weights map (it has never been created). But what is a malicious user wants to tricks us and, when counting votes, creates a transaction in which he claims that 'the vote should be ignored because its user is not in weights map'. For such a case an on-chain proof is needed that indeed the user is not in weights map. Otherwise there is a vulnerability where correct votes can be ignored.

## Proof creation optimization

Proof creation may be parallelized in a similar way merge sort works. Then the number of cardano blocks required to create a proof is logarithmic instead of linear on the number of elements in a map.
