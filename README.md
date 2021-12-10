<p align="center">
<br/>
<img src="https://i.imgur.com/H2ZZjU2.png" height=250 />
</p>

<h1 align="center">P L U T O N O M I C O N</h1>

# Introduction

The Plutonomicon is a developer-driven guide to the Plutus smart contract language _in practice_.

Since this ecosystem is moving at a breakneck speed, we ask that ANY information posted that is not confirmed to work on chain be labelled as `🔧 work in progress`.

# Available resources

We currently provide the following resources, broadly organized by topic.

## Fundamentals and explanations

* [The Fundamentals of Plutus](fundamentals.md), which gives a brief introduction to the Plutus language.
* [Plutus Numeric Hierarchy](numeric.md), which gives an overview of the Plutus numerical type class stack, as well as the extensions to it provided by [`plutus-numeric`](https://github.com/Liqwid-Labs/plutus-extra/tree/master/plutus-numeric).
* [User guide to `plutus-numeric`](user-guide-numeric.md), which gives a more 'example-driven' explanation for how to do certain common tasks using `plutus-numeric`.

## Design patterns

* [Forward Minting Policy](forwarding1.md). Also described [in another  writeup](forwarding2.md). Some caution is required, as you may not wish to directly reference a script to obtain a hash used to identify the two scripts, as this method details.
* [Come and Go Proof Tokens](cngproof.md)
* [State Thread Token Pattern](statethread.md)
* [DistributedMap](DistributedMap.md), describing an on-chain implementation of key-value mappings. This is naive, and mostly designed for conceptual illustration.
* [Consistency of a Distributed Map](consistency.md), which explains some ways  of operating on a [distributed map](DistributedMap.md).
* [Stick Breaking Set](stick-breaking-set.md), describing an on-chain method of proving presence or absence in a set.
* [On-Chain Association List With Constant Time Insert-Removal](assoc.md), describing a pattern that can be used to replicate account-style maps without breaking transaction size limits. This is the optimized version of [the naive   version of that data structure](DistributedMap.md).

## Testing and optimization
* [Staying In Bounds](size-test.md), which describes the testing interface for Plutus on-chain size provided by [`plutus-size-check`](https://github.com/Liqwid-Labs/plutus-extra/tree/master/plutus-size-check).

### Script Optimization Techniques:
* [Reducing Plutus Script Sizes](scriptsize.md)
* [Optimizations to reduce CPU and Mem consumption](scriptmem.md)

## Plutus Vulnerabilities:
* [Common Plutus Vulnerabilities](vulnerabilities.md)
