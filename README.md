<p align="center">
<br/>
<img src="https://i.imgur.com/H2ZZjU2.png" height=250 />
</p>

<h1 align="center">P L U T O N O M I C O N</h1>



The Plutonomicon is a developer-driven guide to the Plutus smart contract language _in practice_.

Since this ecosystem is moving at a breakneck speed, we ask that ANY information posted that is not confirmed to work on chain be labelled as `🔧 work in progress`.


For a brief introduction to the plutus language, see [The Fundamentals of Plutus](fundamentals.md).

For an overview of the Plutus number typeclass stack (and additional numeric tools in `plutus-extra`) see [Plutus Numeric Hierarchy](numeric.md).

## Concurrency:
Over a short series of papers, we will build to  a concurrent account-model representation applicable in some, but not all cases.
First, the [Distributed Map](DistributedMap.md) - a naive implementation with some performance bottlenecks
Second, [Consistency of a Distributed Map](consistency.md) - explaining some ways of performing operations with this structure
Third, a more concurrent pattern to replicate account-style maps, [On-Chain Association List With Constant Time Insert-Removal](assoc.md).

two other relevant patterns are [Come and Go Proof Tokens](cngproof.md) and [State Thread Token Pattern](statethread.md)

For efficient order books, [Stick-Breaking Sets](stick-breaking.md) may help you.

## Design Patterns:
the first main design pattern in Plutus is the [Forwarding Minting Policy](forwarding1.md), also described [here](forwarding2.md).  Caution is required though, as you may not wish to directly reference a script in order to obtain a hash used to identify the two scripts.

### Script Optimization Techniques:
- [Reducing Plutus Script Sizes](scriptsize.md)
- [Optimizations to reduce CPU and Mem consumption](scriptmem.md)

## Plutus Vulnerabilities:
- [Common Plutus Vulnerabilities](vulnerabilities.md)
