<p align="center">
<br/>
<img src="https://i.imgur.com/H2ZZjU2.png" height=250 />
</p>

<h1 align="center">P L U T O N O M I C O N</h1>

# Introduction

The Plutonomicon is a developer-driven guide to the Plutus smart contract language _in practice_.

Since this ecosystem is moving at a breakneck speed, 
we ask that ANY information posted that is not confirmed to work on chain be labelled as `🔧 work in progress`.

# Available resources

We currently provide the following articles:

* [The Fundamentals of Plutus](fundamentals.md), which gives a brief
  introduction to the Plutus language.
* [Plutus Numeric Hierarchy](numeric.md), which gives an overview of the Plutus
  numerical type class stack, as well as the extensions to it provided by
  [`plutus-numeric`](https://github.com/Liqwid-Labs/plutus-extra/tree/master/plutus-numeric).
* [On-Chain Association List With Constant Time Insert-Removal](assoc.md),
  describing a pattern that can be used to replicate account-style maps without
  breaking transaction size limits.
* [Staying In Bounds](size-test.md), which describes the testing interface for
  Plutus on-chain size provided by
  [`plutus-size-check`](https://github.com/Liqwid-Labs/plutus-extra/tree/master/plutus-size-check).
* [Stick Breaking Set](stick-breaking-set.md), describing an on-chain method of
  proving presence or absence in a set.
