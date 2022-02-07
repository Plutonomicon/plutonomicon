# The TxTP Architecture 

(credit Peter Dragos)

> &quot;Constraints liberate, liberties constrain.&quot; - Rúnar Bjarnason

The TxTP Architecture provides a specification and implementation model of smart contract protocols that views _transactions_ as the main architectural focus rather than validators and minting policies. 

This post will detail the basic techniques introduced by the architecutre. It assumes the reader is familiar with the transaction token pattern, and is a recommended pre-requisite to reading about protocol categories.

## The Protocol Model assumed by the Architecture

The TxTP architecture views a protocol as equivalent to the set of valid transactions  that the protocol supports. We refer to the complete set of valid transactions as the _protocol transaction set._ To formalize this notion, we will make use of the following definitions and concepts:

- The implementation of a protocol _introduces_ a finite set of validators and minting policies. 
- A protocol _supports_ a transaction _t_ if and only if:
    - _t_ validates, and
    - _t_ consumes UTxOs or forges a token guarded by any validator or minting policy introduced by the protocol.

Note that this notion of a protocol defines clear boundaries of what transactions are and are not in the protocol transaction set. To some readers, this definition may be much more expansive that previous notions: _any_ transaction using _any_ validator or minting policy introduced by the protocol is considered part of the protocol, even if a transaction makes use of additional validators and minting policies _not_ introduced by the protocol.

This concept is important, because it means that &quot;integrations&quot; with third-party validators and minting policies must be considered as part of the protocol itself. The set of validators and minting policies that are _used_ by the protocol and the set of validators and minting policies that are _introduced_ by the protocol need not be the same.

We use the term _protocol_ to refer to the ideal system being specified, and the term _application_ to refer to the actual implemented system. A protocol is _modeled_, while an application is _implemented_.

The above notions give rise to a natural concept of _equivalence_ for protocols. Protocol equivalence is (mathematical) set equivalence: two protocols are _equivalent_ if they both have the same protocol transaction set, regardless of if the specifications differ in approach or the applications implementing the protocol model are distinct. 

## Weak, Strong, and Strict Transaction Families 

The first step of modeling a protocol using the TxTP architecture is to partition the protocol transaction set into equivalence classes called the _families of transactions_ or simply _the partitioning_ of the protocol. The semantic intention of a given transaction (i.e., the answer to the question &quot;why should this transaction be considered valid?&quot;) determines its equivalence class. Note that multiple valid partitionings exist, and a protocol can be identified with any of its partitionings. Further note that for any partitioning, except the discrete partition and the trivial partition, we can always change the granularity of the partition to make the semantics more or less precise. We aim to choose a level of granularity that is sufficient for both specification and implementation.

Every transaction family is identified with a function, and these functions come in three flavors:

>We set the convention that if the term &quot;transaction familiy&quot; is used unqualified, we are referring implicitly to &quot;strict transaction families&quot;.


- _Weak_ transaction families may be described by taking a proposed transaction `t` and establishing a function `t → Bool` that says whether a transaction is or is not part of that family.
- _Strong_ transaction families are those which can be described by _computing_ the output UTxOs from the redeemer and `ScriptContext` (sans the `txInfoOutputs` field) passed to a [TxTMP](./transaction-token-pattern.md). This establishes the transaction family as a function with roughly the type signature `f : Redeemer -> ScriptContext -> [TxOut]`.
- _Strict_ transaction families are like strong transaction families, but require that the function computing the output from the input has a fixed signature in terms of the UTxOs consumed and produced. Thus, a transaction consuming UTxOs four UTxOs at validators `[V_1, V_2, V_3, V_2]` would be considered distinct from a transaction consuming UTxOs at validators `[V_1, V_2, V_3, V_4]`, even if a coherent semantic criteria could be applied to both.

Specifically, note that every strict transaction family trivially is also strong, and every strong transaction family trivially is also weak.

Put another way, there is always a _recombination_ of partition cells from a strict partitioning to a strong partitioning (and strong to weak). But it is important to note that there is _not necessarily_ a refinement of a partition that can make a weak partition strong or a strong partition strict.

The weak partitioning can permit either &quot;blacklist&quot; or &quot;whitelist&quot; semantics; a developer can take a &quot;default deny&quot; approach and allow only transactions that obey certain predicates to pass, or a &quot;default accept&quot; approach which only blocks transactions when a certain predicate holds and passes all others.

The strong and strict transaction families associate a valid output with every valid input. By doing so, strong and strict families have a tendency to be implemented much closer to a whitelist approach: the function itself is a constructive proof as to why a given transaction is semantically valid.

Note that this model is indeed sufficient to capture the behavior of any possible protocol. The discrete partition (one in which every transaction family includes only a single valid transaction) can associate a transaction family implementing the associated function as being exactly a from a single input to a single output. The trivial partition would be a weak transaction family that returns `True` for any valid transaction, and `False` otherwise. Of course, neither approach is very helpful in practice.

## Reifying Transactions Families via Contracts and TxTMPs

The protocol transaction families are the subject of theoretical focus under the TxTP architecture. The architecture has two goals. First, to first select a suitable semantic criteria on which to partition the protocol transactions. Second, to converge on a formalization of that partitioning in a manner that enables implementation of the following idealized components:

- _Contracts_: off-chain code that generates a specific set of transactions (called the _contract transactions_).
- _TxTMPs_ (or [_Transaction Token Minting Policies_](./transaction-token-pattern.md)): on-chain code to which otherwise &quot;dumb&quot; validators route UTxO validation. The set of transactions that are routed to a particular TxTMP are called the _TxTMP transactions_.

According to the architecture,  a given ideal contract or TxTMP must be in bijection with a single transaction family: for every transaction family `T`, there is a TxTMP that validates only transactions `t` such that `t \in T`; further, there is a contract that generates only `t \in T`.

The complete set of implemented TxTMPs and Contracts are called the _Application TxTMP Set_ and _Application Contract Set_, respectively. In an ideal implementation the application TxTMP set and the application contract set are in bijection with the protocol&#39;s transaction families. Thus, if we partition a protocol into 5 transaction families, the application will contain exactly 5 contracts and exactly 5 TxTMPs.

Upon successfully establishing the above bijections, a third bijection appears between contracts and TxTMPs. Once this occurs, every valid transaction may be generated by a particular contract and validated by a particular TxTMP. Further, these bijections mean that invalid transactions will neither generate nor validate.

Transaction families may require data to be passed in, such as in the case where the user must provide arguments that establish the intent of the transaction. This data passing can occur either by passing in a datum understood by the TxTMP or via a redeemer.

The mechanisms by which a given TxTMP/contract pair actually obtain and apply the application parameters, run-time arguments, and extraction of data via `ScriptContext` matching or querying/lookups can be made fairly generic across all such pairs.

## Transaction Flows and Components

The architecture makes use of the following additional concepts:

- _Transaction flows_ are a higher level of abstraction capturing the semantic meaning of multiple Transaction Families joined in series or in parallel. Thinking in terms of Transaction Flows can be more suitable for real-world implementation constraints (such as handling size limitations and order batching). Note that Transaction Flow may contain _many_ permissible combinations of transaction families, not just one. Transaction flows are not directly implemented by the transaction token pattern but can be enforced using techniques like escrow queues, which allow for treating serial transaction flows as &quot;black boxes&quot;.
- UTxOs contain _component data_ according to a well-defined Datum schema. The term &quot;`V` component&quot; may be used interchangeably with the phrase &quot;the component semantically represented by a UTxO locked at validator `V`&quot;.
- Further, _minting policies_ and _wallets_ used by the protocol are also considered components. A &quot;component validator&quot; is any non-TxTMP address that requires validation logic to obtain the effect of.

The TxTP architecture delineates _component data_, which is carried (primarily) in the Datum of a UTxO, from _application logic and parameters_, which are embedded in Transaction Token Minting Policies (TxTMPs). Redeemers passed to component validators or non-TxTMP minting policies only serve to provide flexibility to routing logic; redeemers to the TxTMP minting policy then centralize a means to pass transaction-relevant data.

In the TxTP architecture, component validators only implement a mechanism to route transaction validation to a set of authorized TxTMPs and provide a uniform schema to interface with the Datum and Redeemer types of that particular Validator. No application logic is present in the component validators themselves, besides that which is necessary to route validation to an authorized set of TxTMPs. Thus, there is no need to have application parameters (such as script hashes besides those of the TxTMPs, static protocol configuration data, or so forth) in the Datum of a Validator UTxO and this is in fact discouraged in order to remove cognitive and development burden.

From this perspective, a component validator&#39;s specification roughly includes:

- The Datum Type of the validator (applicable only to UTxO-locking components)
- The Redeemer Type of the component validator
- A semantic understanding of the Value(s) present in the UTxO(s) locked by the UTxO-locking and minting policy components
- The set of authorized TxTMPs to which it routes validation and the routing logic

The specification of a transaction family/TxTMP/contract roughly includes:

- A semantic understanding of _why_ transactions represented by this family are necessary to the protocol
- A function giving the transaction validation logic (with the requisite conditions met by the desired strength of the family)

## Modularity, Extensibility, and Security

The TxTP Architecture discourages dynamically configurable TxTMP scripts; that is, parameters of deployed scripts should be hard-coded, rather than read in according to a datum when possible. The reason for this is because the protocol transaction set then includes &quot;families of families of transactions&quot; (ostensibly one family for each set of parameters). The architecture prefers instead to think of each reparameterization as a distinct protocol with a correspondingly distinct set of protocol transactions. Of course, allowing modularity of the TxTMP references stored by component validators means that this essentially balloons the protocol transaction space to infinity. Architects are encouraged to draw suitable boundaries around their protocol, but are forewarned that the usual tradeoffs between security and convenience/modularity apply.

To update the protocol, the TxTMPs associated with a given validator can be swapped out. The logic to do so is out of the scope of the architecture itself, but will likely require &quot;pausing&quot; the protocol so that the swap can be atomic across all affected components. Similarly, the actual mechanism by which validation is routed to the appropriate TxTMP is out of the scope of the TxTP Architecture itself. The architecture assumes that each of these operations is implemented correctly. The actual implementation of these operations is delegated to frameworks.

## Conclusion

The TxTP Architecture is thought to be expressive enough to represent all possible protocols. However, as with any modeling frameworks, application of the architecture in both theory and practice may not be the best fit for every domain.

To make an analogy, relational databases focus on the relationship between data. A relational data model requires that data architects view their data in this way, and provides a mental and computational framework for making this process easier for many domains. However, there is still skill involved in modeling, and some domains may be faster in terms of implementation or performance is modeled using a NoSQL database instead. A similar analogy can be made between functional and object-oriented languages.

Readers are encouraged to make use of the architecture in whatever way they see fit. Just like a relational database can provide additional benefits at increase levels of [normalization](https://en.wikipedia.org/wiki/Database_normalization), the patterns presented by the architecture can be used in whole or in part, in weak or strong forms. The tradeoffs in doing so will be specific to the project and developers in question.
