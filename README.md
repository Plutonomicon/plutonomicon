<p align="center">
<br/>
<img src="https://i.imgur.com/H2ZZjU2.png" height=250 />
</p>

<h1 align="center">P L U T O N O M I C O N</h1>

[![Hercules-ci][Herc badge]][Herc link]
[![Cachix Cache][Cachix badge]][Cachix link]

[Herc badge]: https://img.shields.io/badge/ci--by--hercules-green.svg
[Herc link]: https://hercules-ci.com/github/Plutonomicon/plutonomicon
[Cachix badge]: https://img.shields.io/badge/cachix-public_plutonomicon-blue.svg
[Cachix link]: https://public-plutonomicon.cachix.org

## Introduction

The Plutonomicon is a developer-driven guide to the Plutus smart contract language _in practice_.

Since this ecosystem is moving at a breakneck speed, we ask that ANY information posted that is not confirmed to work on chain be labelled as `🔧 work in progress`.

## Available resources

We currently provide the following resources, broadly organized by topic.

### Fundamentals and explanations

* [The Fundamentals of Plutus](fundamentals.md), which gives a brief introduction to the Plutus language.
* [Plutus Numeric Hierarchy](numeric.md), which gives an overview of the Plutus numerical type class stack, as well as the extensions to it provided by [`plutus-numeric`](https://github.com/Liqwid-Labs/plutus-extra/tree/master/plutus-numeric).
* [User guide to `plutus-numeric`](user-guide-numeric.md), which gives a more 'example-driven' explanation for how to do certain common tasks using `plutus-numeric`.
* [How Stake Validators Actually Work](stake-scripts.md), which gives an explanation of 'Stake Validators'.

### Design patterns

* [Forward Minting Policy](forwarding1.md). Also described [in another  writeup](forwarding2.md). Some caution is required, as you may not wish to directly reference a script to obtain a hash used to identify the two scripts, as this method details.
* [Come and Go Proof Tokens](cngproof.md)
* [State Thread Token Pattern](statethread.md)
* [DistributedMap](DistributedMap.md), describing an on-chain implementation of key-value mappings. This is naive, and mostly designed for conceptual illustration.
* [Consistency of a Distributed Map](consistency.md), which explains some ways  of operating on a [distributed map](DistributedMap.md).
* [Stick Breaking Set](stick-breaking-set.md), describing an on-chain method of proving presence or absence in a set.
* [On-Chain Association List With Constant Time Insert-Removal](assoc.md), describing a pattern that can be used to replicate account-style maps without breaking transaction size limits. This is the optimized version of [the naive   version of that data structure](DistributedMap.md).
* _Transaction Tokens_ provide an method of deferring validation to minting policies for the purpose of validating entire transactions rather than the unlocking of individual UTxOs.
  * The [Transaction Token Pattern](./transaction-token-pattern.md) document introduces the pattern.
  * The [Transaction Token Protocol Architecture](./transaction-token-protocol.md) document introduces a conceptual and practical framework leveraging the pattern for specifying and implementing protocols.
  * The [Protocol Category Sketch](./protocol-category.md) document sketches a formalism to establish a formalism that places protocols described according the the Architecture into the language of symmetric monoidal categories, and works through some examples of how wiring diagrams and aid specification and implementation.
  

### Testing and optimization
* [Staying In Bounds](size-test.md), which describes the testing interface for Plutus on-chain size provided by [`plutus-size-check`](https://github.com/Liqwid-Labs/plutus-extra/tree/master/plutus-size-check).

#### Script Optimization Techniques:
* [Reducing Plutus Script Sizes](optimisations.md)
* [Optimizations to reduce CPU and Mem consumption](scriptmem.md)
* [Shrinker](https://github.com/Plutonomicon/Shrinker) (shrinker is currently unmaintained)

### Plutus Vulnerabilities:
* [Common Plutus Vulnerabilities](vulnerabilities.md)

## Discussion 

To discuss the projects and the content under the Plutonomicon umbrella, join our Discord: https://discord.gg/722KnTC8jF

## Running the website

If you'd like to run a live version of the website locally:

```sh-session
nix run
```

As you edit[^ed] and save the Markdown files, the browser view should update instantly without requiring a manual refresh. Run `nix build` to build the statically generated website. See [Emanote guide](https://emanote.srid.ca/guide) for further information.

Please note the Markdown writing conventions:

- There must be zero or one level 1 heading (`# A heading`) as the first line.
  - If a level 1 heading is not specified, title will be derived from the filename.
- All other headings must be level 2 or greater.

[^ed]: Try [Obsidian](https://obsidian.md) or VSCode with [vscode-memo](https://github.com/svsool/vscode-memo) for editing.
