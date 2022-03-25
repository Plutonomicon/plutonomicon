# How Stake Validators Actually Work

`🔧 work in progress`. - This is largely interpretative of the ledger specs, and has not been confirmed to work on a real node yet - since plutus-ledger-api's support of Stake Validators is pretty sparse at the moment.

Staking is an integral feature of Cardano that ought to play a part in how we design dApps. However, much of the exposition on Staking and how it works
is from the perspective of wallet users and stake pool operators.

How staking *actually* works, on the level of individual transactions is considerably *folklore*, buried in the tangled web of hfc-to-hfc specs.

**StakeValidators**, a concept arising from the composition of two distinct eras - *Shelley* and *Alonzo* are particularly neglected, and the documentation of Staking related functionality in plutus is pretty poor. What is [DCert][Plutus.V1.Ledger.DCert] even for!?.

Referring to the [ledger specs](https://github.com/input-output-hk/cardano-ledger), this document hopes to provide enough explanation for a dApp developer to be sure of the role *StakeValidators* .

## Staking Addresses

To start, let's consider how *Staking Addresses* work. 

An *Address*, attached to each UTXO, takes the form:

- network + credential + staking_credential? 

Let's ignore the network part, which is just a magic number identifying the network (testnet, mainnet, etc). 

We can see that this corresponds to the Plutus `Address` type, in [Plutus.V1.Ledger.Address] -

```haskell
data Address = 
  Address 
  { addressCredential :: Credential
  , addressStakingCredential :: Maybe StakingCredential 
  }
```

We are familiar with `Credential`, which may be a `PubKeyHash` or a `ValidatorHash`, allowing us to lock UTXOs to a wallet or a script.

Let's take a closer look at the optional `StakingCredential` field, in [Plutus.V1.Ledger.Credential] - 

```haskell
data StakingCredential
    = StakingHash Credential
    | StakingPtr Integer Integer Integer 
```

You may notice the `StakingHash` constructor also uses `Credential` - 
meaning that a *script* is a valid staking credential. This is our fabled *StakeValidator*. 

When we look at delegations and withdrawals, let's try to keep this in mind. 
In the same sense that we can guard spending of a UTXO behind a PubKeyHash or a ValidatorHash, we can also guard actions involving a StakingCredential.

This gives us a number of ways to construct an Address.
The [specs][Shelly] helpfully give names to the variants.

- **Base** -` addressStakingCredential = (Just (StakingHash _))`
  - Basically two `Credentials` glued together
- **Enterprise** - `addressStakingCredential = Nothing`
  - This is the form most dApps will end up using...
- **Pointer** - `addressStakingCredential = (Just (StakingPtr _ _ _))`
  - More on this later

**But what do Staking Addresses actually do/mean!?**

From the [shelly specs][Shelly], page 9 (emphasis mine):

>The staking credential controls the **delegation decision** for the Ada at this address (i.e. it is
used for rewards, staking, etc.).

Essentially , as we will see later, the StakingCredential on a *UTXO* determines the *rewards account* which it is considered to 'belong to' on the epoch snapshot. The staking *credential* itself is used to guard certain actions involving a rewards account.

To recap:

- The **Address** of a UTXO optionally includes a staking credential
- Staking credentials are regular **Credentials**, which can be either a **PubKeyHash** or a **ValidatorHash**.


## DCerts - Delegation Certificates

What is **StakingPtr**? How does Delegation work? What is *DCert*!? Let's take a look.

If a staking credential controls *delegation*, then how does delegation work?

Let's take a look at **TxInfo**, in [Plutus.V1.Ledger.Contexts] -

```haskell
data TxInfo = TxInfo
    { txInfoInputs      :: [TxInInfo] -- ^ Transaction inputs
    , txInfoOutputs     :: [TxOut] -- ^ Transaction outputs
    , txInfoFee         :: Value -- ^ The fee paid by this transaction.
    , txInfoMint        :: Value -- ^ The 'Value' minted by this transaction.
    , txInfoDCert       :: [DCert] -- ^ Digests of certificates included in this transaction
    , txInfoWdrl        :: [(StakingCredential, Integer)] -- ^ Withdrawals
    , txInfoValidRange  :: POSIXTimeRange -- ^ The valid range for the transaction.
    , txInfoSignatories :: [PubKeyHash] -- ^ Signatures provided with the transaction, attested that they all signed the tx
    , txInfoData        :: [(DatumHash, Datum)]
    , txInfoId          :: TxId
    -- ^ Hash of the pending transaction (excluding witnesses)
    } deriving stock (Generic, Haskell.Show, Haskell.Eq)
```

Notice the `txInfoDCert` field. Transactions submitted with *DCerts* include special operations on the ledger's *delegation state*.

Let's also take a look at **DCert**, from [Plutus.V1.Ledger.DCert] (with the irrelevant-to-us constructors omitted) -

```haskell
data DCert
  = DCertDelegRegKey StakingCredential
  | DCertDelegDeRegKey StakingCredential
  | DCertDelegDelegate
      StakingCredential
      -- ^ delegator
      PubKeyHash
      -- ^ delegatee
  | ...
```

So delegation is carried out by transactions containing a **DCert** with **DCertDelegDelegate**! But that's not the whole picture...

The comments here don't tell us very much... let's circle back to the [shelly spec][Shelly], page 29 -

>Stake credentials are registered (or deregistered) through the use of registration (or deregistration) certificates. Registered stake credentials are delegated through the use of delegation
certificates.

So **DCert** stands for **Delegation Certificate**. Good to know.

### Registration - Obtaining a StakingPtr

Let's investigate *registration*.  From the [shelly spec][Shelly], page 34 (emphasis mine):

>Stake credential delegation is handled by Equation (8). There is a precondition that the key has been registered

In other words, in order to submit a delegation to a Staking Pool with **DCertDelegDelegate**, the staking credential first has to be *registered* with **DCertDelegRegKey**.

Again from the [shelly spec][Shelly], page 34:

> Registration causes the following state transformation:
> * A reward account is created for this key, with a starting balance of zero.
> * The certificate pointer is mapped to the new stake credential.

So registration creates a new rewards account, and a **StakingPtr** which can be used to refer to it later! 
To understand a little more clearly, let's look at the definition of **Ptr** in the [shelly spec][Shelly], page 10:

> (s, t, c)∈Ptr = Slot × Ix × Ix 

It's not so obvious what this means. It refers to the cert at the *c*th index of a *txInfoDCert* field of the *t*th transaction in the block at slot *s*. Not unlike **TxOutRef**. 
This is pretty nifty, as it allows us to refer to staking credentials with 3 (variable length, but decently small) Integers, rather than a 28-bit hash.

### Staking Credentials and Rewards Accounts are One-to-One

An important thing to note is a staking credential may only be registered once - giving a 1-to-1 relation between rewards accounts and staking credentials. 
This is a little unfortunate, as it means splitting delegation between N pools requires N UTXOs, with N staking credentials.

From the [shelly specs][Shelly], page 34 -

>There is also a precondition on registration that the hashkey associated with the certificate
witness of the certificate is not already found in the current reward accounts (which is the
source of truth for which stake credentials are registered).

This wording is a little non-obvious in our context but the preconditions of the *DelegReg* rule on page 36 help to clarify - 

> c ∈ DCert<sub>regkey</sub>&nbsp;&nbsp;&nbsp;&nbsp;hk := regCred c &nbsp;&nbsp;&nbsp;&nbsp;hk /∈ dom reward

So the **Credential** in **DCertDelegRegKey** must not already have a reward account.

## Reward Withdrawals

Let's investigate how reward withdrawals work, returning to **TxInfo** from [Plutus.V1.Ledger.Contexts]. 

```haskell
data TxInfo = TxInfo
  { ...
    , txInfoWdrl        :: [(StakingCredential, Integer)] -- ^ Withdrawals
    ...
  }
```

What is the **Integer** here? ...The definition from [shelly spec][Shelly], page 15:

>wdrl ∈ Wdrl = Addr<sub>rwd</sub> 7 → Coin

*Coin*: in other words a quantity of **Lovelace**. 

So it seems like we can *withdraw* from a rewards account by making a transaction that sets a value in the *txInfoWdrl* field. What limits might this have?

*From the UTxO Transition rules in the [shelly spec][Shelly], page 21*

>wbalance ∈ Wdrl → Coin withdrawal balance <br />
wbalance ws = ∑<sub>(_→c)∈ws</sub> c

>consumed ∈ PParams → UTxO → TxBody → Coin value consumed<br />
consumed pp utxotx = <br />
&nbsp;&nbsp;ubalance (txins tx ◁ utxo) + wbalance (txwdrls tx)<br />
&nbsp;&nbsp;+ keyRefunds pp tx

We can see that the total value of withdrawals, sort of like an inverse of *fees*, can be used to balance the **Value** equation of a contract. This is pretty flexible, and can even be used to pay transaction fees!

A limitation to note is that a withdrawal must withdraw all of the rewards at once! So the *Integer* values in *txInfoWdrls* each have a single value that is valid.

*From the [shelly spec][Shelly], page 14*
>A mapping of reward account withdrawals. The type Wdrl is a finite map that maps a
reward address to the coin value to be withdrawn. The coin value must be equal to the full
value contained in the account.

## Stake Validators

Now that we have some priors on staking credentials, delegation and withdrawals, we are ready to put the pieces together and understand *Stake Validators*.

We've seen *txInfoDCert* and *txInfoWdrls* in **TxInfo**, but what does a Stake Validator look like to Plutus?

In [Ledger.Typed.Scripts.StakeValidators], we have -

```haskell
wrapStakeValidator
    :: UnsafeFromData r
    => (r -> Validation.ScriptContext -> Bool)
    -> WrappedStakeValidatorType
```

It's similar to *Minting Policies* - we get a **Redeemer**, and the **ScriptContext**. *Infact - the types are the same, so it's possible we could have a single script which can be used as a Minting Policy and a Stake Validator.*

Looking at [Plutus.V1.Ledger.Contexts] again, this time **ScriptPurpose** -

```haskell
data ScriptPurpose
    = Minting CurrencySymbol
    | Spending TxOutRef
    | Rewarding StakingCredential
    | Certifying DCert
```

So there are two relevant constructors for **StakeValidators**. 

- **Rewarding** which gives us the **StakingCredential** index of the *txInfoWdrls* field. 

- **Certifying**, which similarly gives us the relevant **DCert** from *txInfoDCert*.

Combining this with what we have learned about *withdrawals* and *delegation*, pattern matching on **ScriptPurpose**, there are 4 main actions which a stake validator authenticates -

```haskell
stakeValidator :: Redeemer -> ScriptContext -> Bool
stakeValidator r (ScriptContext _ purpose) =
  case purpose of
    (Rewarding ownCredential) 
      -> -- reward withdrawals
    (Certifying (DCertDelegRegKey ownCredential)) 
      -> -- credential registration
    (Certifying (DCertDelegDelegate ownCredential poolId) 
      -> -- staking pool delegation
    (Certifying (DCertDeRegKey ownCredential)) 
      -> -- credential de-registration
    _ -> -- etc
```

The rewards withdrawals, registration and delegation cases are always necessary for a Stake Validator to be useful. Withdrawal is obviously required, which necessitates registration and delegation as a pre-requisite.

De-registration is optional, but probably good form to include anyway - it can be used to de-activate existing **StakingPtr**s.

## Use-Cases of Stake Validators

We know what they are, and how they work? But what uses do Stake Validators have? Let's speculate a little -

### DAO Use-Case

An obvious case to consider is a DAO which owns a significant treasury of ADA - it would make sense for such a DAO to stake their ADA to collect staking rewards. Stake Validators allow them to manage delegation and rewards withdrawals on-chain, integrating it with their Treasury's management.

Stake Validators allow a DAO to define:

- The delegation of their ADA, via `Certifying (DCertDelegDelegate ...)`
  - For example, delegation could be determined by an on-chain witness of the result of a DAO vote.
- How staking rewards must be spent, via `Rewarding ...`
  - Simply withdrawing rewards to the DAO treasury

### Other Use-Cases

There's a lot of potentially use-cases, really any protocol which locks any significant amount of ADA ought to make use of stake validators in some capacity.

- Withdrawing to strengthen an ADA-backed stablecoin
- Compounding an ADA-based yield for a lending protocol
- Withdrawing to provide ADA liquidity of AMM pairs
- Additional yield for LP providers in ADA pairs
- Additional incentive component for *any* kind of yield, so long as the protocol locks ADA.

[Shelly]: https://hydra.iohk.io/job/Cardano/cardano-ledger-specs/shelleyLedgerSpec/latest/download-by-type/doc-pdf/ledger-spec

[Plutus.V1.Ledger.DCert]: https://github.com/input-output-hk/plutus/blob/3619837601af8288f79b211d053c0d2dead7cfc0/plutus-ledger-api/src/Plutus/V1/Ledger/DCert.hs
[Plutus.V1.Ledger.Address]: https://github.com/input-output-hk/plutus/blob/3619837601af8288f79b211d053c0d2dead7cfc0/plutus-ledger-api/src/Plutus/V1/Ledger/Address.hs
[Plutus.V1.Ledger.Credential]: https://github.com/input-output-hk/plutus/blob/3619837601af8288f79b211d053c0d2dead7cfc0/plutus-ledger-api/src/Plutus/V1/Ledger/Credential.hs
[Plutus.V1.Ledger.Contexts]: https://github.com/input-output-hk/plutus/blob/3619837601af8288f79b211d053c0d2dead7cfc0/plutus-ledger-api/src/Plutus/V1/Ledger/Contexts.hs
[Ledger.Typed.Scripts.StakeValidators]: https://github.com/input-output-hk/plutus-apps/blob/e4d852ffcf6622e0c8359b73170a28b6e5cefc46/plutus-ledger/src/Ledger/Typed/Scripts/StakeValidators.hs

<hr />

Author: [Tilde Rose](https://github.com/t1lde/)
