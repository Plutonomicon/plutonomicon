# Common Plutus Vulnerabilities

This is a space to add/discuss known vulnerabilities in Plutus that can lead to various kinds of attacks AND their mitigations (if known)



## UTXO Value size spam AKA Token Dust attack

_the UTXO of too many tokens_  (or a single AssetClass with a large amount of tokens) - where a single utxo carries hundreds of unique tokens with different CurrencySymbols and/or TokenNames until it's representation approaches the 16kb limit,  this is then placed in a Validator in such a way that one or more Redeemers will need to consume this utxo,   blocking transactions on that Redeemer/Validator.

Also see: [Min-Ada-Value Requirement](https://cardano-ledger.readthedocs.io/en/latest/explanations/min-utxo.html) - a minimum ada value is required on all UTXOs, which scales with UTXO size. This may mitigate protocol tx sizes somewhat. A similar calculation could be used on-chain to produce a size heuristic.

### Solution

Don't allow arbitrary value to be put in trusted places.

## Large Datum size

_the Datum of too much size_ - similarly, Datum on a UTXO which is of an inappropriately large size which _needs_ to be consumed for a transaction on a critical redeemer to succeed.

### Solution

Make sure not to use infinitely sized data types,
or take and infinitely sized one and limit it in some way.

## Double Satisfaction

If a spending contract only looks at the outputs for its input, it could lead to
allowing multiple UTxOs to be spent in a single transaction, as long as at least
one of them produces the expected outputs.

As an example, if a trade contract validates the sale of an NFT by only checking
that its seller is receiving the asked price in the minimum, a transaction can
be built such that multiple NFTs of this particular seller are spent, but seller
only gets the asked price for the most expensive of the spent NFTs.

### Solution

The simplest solution is to validate that only a single UTxO is spent from the
contract's address. Meaning the contract has to filter the inputs based on their
addresses, and make sure that a single input remains such that its address is
the same as the UTxO currently getting spent.

Another solution that allows for multiple UTxOs to be spent in a single
transaction, is to uniquely "tag" the outputs for their corresponding inputs.
For example, the contract can expect the output to carry the transaction ID of
its associated input in the datum, and therefore ensure only one UTxO has been
spent for it.

## Lack of staking control

Protocols must ensure that staking is determined by the protocol for
funds held by the protocol.
For example, a Uniswap-style DEX must not allow users to arbitrarily
change the staking address of the pool.

## EUTXO Concurrency DoS

Blocking EUTXOs could be repeatedly spent with a trivial transaction, potentially locking out a whole protocol. Even scalable solutions could be vulnerable to this in a distributed manner.

Mitigations:

- Extra fees/other disincentives to discourage attacks/make them disproportionately expensive/make them benefit the protocol
- 'freezing' periods to allow protocol functions (keepers) to execute
    - Validators can check Tx time range to have 'cold' periods in which only keeper functions can execute, or whole protocol can prevent progress until a keeper action is allowed to progress and update a timestamp. i.e. every x seconds, there are n seconds where only keeper transactions will validate. Or, every x seconds, the protocol cannot progress until a keeper function has been run.
    - (can only be done if there's a server — and won't work for custom transactions. Probably needs to be implemented on the Cardano side)

## PAB denial of service

This covers known exploits of the plutus application backend that may result in successful DoS attacks

- Plutus relies on `aeson`, which has a known DoS exploit listed here: [https://github.com/haskell/aeson/issues/864](https://github.com/haskell/aeson/issues/864)  

## Unauthorized Data modification

This often comes from missing a signature or transaction validation in onchain code,    mitigation is to keep a test suite where each actor fails to validate the transaction, such that this code cannot be missing.

## Oracle Attacks

## Offchain Oracle Data chain-of-information Attacks

This deals more with an offchain server, some mitigations

- building production data integrations that connect with IP (mitigating DNS attacks)
- using Trusted Private Modules for transaction signatures (keeps private keys entirely within a single cpu core,  helps prevent data leakage)

## Oracle PK Attack

Cryptographic keys used by an oracle system may become a valuable point of attack

Some potential mitigations:

- On-chain system allowing key revoking/expiry/updating (perhaps a script which issues a single-use permission-token)
- multi-sig (hard to automate this)
- A more robust oracle ecosystem (as of yet non-existent on Cardano)

## Oracle Price Manipulation

See [article](https://decrypt.co/49657/oracle-exploit-sees-100-million-liquidated-on-compound) for an instance of this with Compound. An attacker was able to manipulate Coinbases oracle to report a price which caused liquidations in Compound.

Mitigations:

- Time weighted averages
- Max/Min reportable price change (can be useful for stablecoins, may be less useful for generic price information for e.g. lending platforms)
- Consuming price information from many oracle sources - Coinbase, Binance, Coingecko, DEXes, etc. 
- Chainlink or similar (Compound now uses chainlink since the oracle attack)

## Infinite Mint

This is an attack vector where an attacker finds unexpected ways to mint all kinds of tokens without the correct authorization. Below describes just one potential attack:

1) We have a forwarding minting policy which requires `MyState` datum/token from the `MyValidator` Validator in order to perform a mint. This policy mints `$TOK` - this can be any fungible token/ token with a consistent currencysymbol.

2) We _Intend_ for users to mint using the `MintTOK` Redeemer in `MyValidator`, however, for other integrations we have a `WitnessMyState` Redeemer, which lets you consume `MyState` for any arbitrary purpose so long as you don't change it.

3) If `WitnessMyState` does not check for minting actions, then we can mint infinite `$TOK`, inflating its value and potentially other catastrophic ruin-your-day kinds of exploits.

## Parameterization

This isn't a vulnerability, but is more so an oversight that can lead to vulnerabilities that *should* be obvious.
On-chain, it is **highly non-trivial** (module crypto magic) to check that a script is an instantiation of some
parameterized script.
Off-chain, this is less true, but even then, you have to be careful that you instantiate the script manually
using the `Apply` constructor of UPLC.
That way, you can off-chain match on that, and check that the LHS is the parameterized script,
then the RHS is the parameter itself.

### Solution

Use technique described above (i.e. manually constructing the term) for off-chain purposes.
If you need to witness it on-chain, use a ZKP or don't parameterize your script.

Another solution is to store the "parameters" of your contract in an
authenticated (and potentially unique) UTxO. However, note that this approach
leads to identical addresses for different parameters.

In general, keep in mind that _assuming_ a contract is instantiated properly, is
equivalent to supporting arbitrary contracts, since this kind of validation is
not yet possible.
