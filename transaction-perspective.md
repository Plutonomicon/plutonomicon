# Plutus from a Transaction Perspective

This post explains the process a transaction undergoes on the Cardano blockchain, the different ways of enforcing behaviors using scripts,  the trade-offs between them, and techniques used to circumvent limitations.

## Anatomy of a transaction

A transaction performs an action on the Cardano blockchain. All changes to the ledger are performed by transactions. Changes do not occur without a transaction being submitted.

A transaction can contain any number of &#39;commands&#39; of the following kinds:

- Consume (spend) outputs (representing value) of other transactions
- Declare and assign value to outputs that can be consumed by other transactions. A single output can contain value in several currencies.
- The transaction associates each output with an _address,_ which can be a user&#39;s wallet (public key) or a script. The controller of the address, either a user holding the private key in the case of a wallet, or a script&#39;s internal logic, controls how that output can be spent, as will be explained. It can be said that the output is &#39;held&#39; by the wallet or script respectively.
- Mint or burn value of any currency other than ADA

Technically burning is the same as minting - minting a negative quantity. They will be considered distinct in this post, for simplicity.

- _Other things to do with staking that I have no idea about_

The actions a transaction may perform are restricted, both by the blockchain&#39;s design and by scripts, as will be explained. The entire transaction either succeeds or fails.

Note: The size of a transaction is limited, currently to 16 KB. This is even more limiting than it seems, because in practice scripts must be submitted as part of the transaction. This detail is ignored for the rest of this document.

## Transaction rules

### Single-spend

A transaction output can only be consumed by a transaction if it is &#39;unspent&#39; - has not previously been consumed. For this reason, outputs are often known as &#39;UTxOs&#39; - &#39;Unspent Transaction Outputs.&#39;

### Balanced

The value handled by transactions must conform to the following rule:

> _value of inputs + value minted == value of outputs + value burned + fees_

When you submit a transaction using the Plutus off-chain API, the library balances the transaction by adding funds from the user&#39;s wallet to make up any shortfall, or alternatively paying any change into the wallet.

### Valid

The transaction must meet the validity criteria for each of its inputs. These criteria depend on the address assigned to the UTxO at each input, and the currencies being minted or burned.

- For each input held by a _wallet,_ The transaction must be signed with a key matching the wallet&#39;s.

> Signing a transaction essentially means - I authorise this transaction to do  what it says with any UTxOs addressed to (&#39;stored in&#39;) my wallet.

- For each input held by a  _validator script,_ the script is executed. If the script fails, the transaction is invalid and is not submitted to the chain.
- An important point is that a script validates how value assigned to it is _consumed_ - it has no way of preventing any value being paid _into_ it. If value is paid to a script address that has no logic to release it, it will be locked there forever. 

Note: A validator script is the only kind of script that can consume and output value, so in such contexts is often just called a &#39;script&#39;.

> Sending value to a script means - I want this value to be spendable by any transaction that can meet the conditions set by the validator.

- Whenever any value is minted or burned, a script corresponding to the currency symbol, known as a _minting policy_, is executed. Again, if this fails, the transaction is invalid. Minting policies cannot consume value. A minting policy for a given currency is invoked at most once per transaction.

## Purpose of scripts

So to flip that around, these are the types of scripts and why you would write them:

### Validators

You write a validator to define a mutually-agreed contract between parties concerning pre-existing value. Value is paid into the script, and can then be spent in accordance with the script&#39;s logic.

### Minting policies

You write a minting policy to create a new type of token. This could be a new cryptocurrency, an NFT, or merely a token witnessing a certain event, which could be used as a proof in a later transaction. The minting policy can decide whether and under what conditions tokens can be burned.

## Data

In order for scripts to make decisions, they need some information about the context of the transaction. For this purpose, Cardano allows pieces of data to be added to transactions and sent to the various scripts. Using the Plutus toolchain and API, scripts can be written to accept data in arbitrary Haskell types. If ill-formed data is submitted, validation automatically fails.

- An object known as a _redeemer_ can be attached to each transaction input that is held by a validator, and is passed to the script attached to the output that the input is attempting to spend. Based on the redeemer, the validator can cause the transaction to fail.
- An object called a _datum_ can be attached to each transaction output that is addressed to a validator. When a transaction subsequently attempts to spend the output, the script can use the datum to decide whether to validate that transaction. Note that the script is not invoked when the output is created and addressed to it, hence a (validator) datum can never cause the transaction containing it to fail. Paying value into a validator always succeeds.
- An object, also known as a _redeemer,_ can be attached to each minting command, and is passed to the minting policy. Based on the redeemer, the minting policy can cause the transaction to fail.

Every script (whether validator or minting policy) is also given an object describing the transaction it is validating. This is known as a _script context_.

The context contains the following information about the transaction:

- The transaction&#39;s inputs, _including_ the originating transactions, as well as the address it is held at and the value and datum it contains.
- A script can thus access the datums being sent to _all_ the scripts that are invoked to validate this transaction.
- The transaction&#39;s outputs - the address it is being sent to, the value it contains, and the datum if it is being sent to a script.
- The fee that this transaction will pay
- The value being minted (or burned, if negative)
- The public keys of the wallets that have signed the transaction
- The hash of the transaction itself

In addition, scripts are supplied with a tag that determines which command in the transaction caused the script to be run. This is called the _purpose_ and is different depending on the type of the script.

-  Validators are provided with the `TxOutRef` of the output.
- Minting policies are provided with the `CurrencySymbol` of the currency. 
- Although a minting policy is only invoked upon mint of the currency it defines, the symbol, which is a hash of the script, is not know at the time of the script is written.

## On-chain and off-chain

As you may have gathered, on Cardano, code on the blockchain cannot actually perform any actions. Transactions, which describe actions, are submitted to the blockchain, and scripts validate them.

Obviously, a smart contract should perform an action. Users cannot be expected to correctly assemble transactions by hand. For this purpose, Cardano wallets can execute another form of program. This runs in the context of the wallet, and is able to pay value into and out of the wallet to balance transactions. A smart contract is typically made up of two components:

- Code to assemble and submit valid transactions. This runs in the user wallet. This is known as the _off-chain_ component.
- Code to determine that actions the user wants to perform (specifically, minting certain tokens or spending value out of contract-controlled addresses) are valid. This runs on the blockchain and is know as _on-chain_ code_._

This way, expensive on-chain computation is kept to a minimum.

Although it is expected that transactions will be performed by off-chain code, and on-chain code does not need to guarantee correct behavior for hand-assembled transactions, all security checks do need to be performed on-chain, to prevent malicious actors from submitting unsafe transactions. For example, you don&#39;t need to prevent an unexpected transaction from locking value away - that&#39;s the submitter&#39;s own problem - but you do need to stop them from inappropriately spending value.

An analogy for this is the way secure web apps are constructed. Most validation checks are performed by JavaScript in the browser, to reduce load on the server and round-trip latency. However, all security-sensitive checks must be performed again by the server, since a malicious actor can make requests directly to the server&#39;s API. Even so, the server-side application is not designed to serve arbitrary requests in normal use.
