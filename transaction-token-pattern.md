# Transaction Token Pattern

(credit to Peter Dragos, with input from Las Safin, Jack Hodgkinson, Emily Martins, Tilde Rose, Neil Rutledge, and Koz Ross.)

> This post provides a [Heilmeier&#39;s Catechism](https://en.wikipedia.org/wiki/George_H._Heilmeier#Heilmeier's_Catechism) for a development pattern hypothesized in discussions between myself and others.

> See [Transaction Token Protocol](./transaction-token-protocol.md) Architecture and [Protocol Category Sketch](./protocol-category.md)  for an (opinionated) specification and implementation architecture derived from this pattern. Additionally, some stronger assumptions appear to make protocols defined in this way into a symmetric monoidal category (with a need for selecting and proving the appropriate formalisms). This enables protocols to be represented as wiring diagrams, which provide a graphical framework to reason about and prove properties of protocols that correspond directly to category-theoretic constructs, and should provide a straight-forward route to reification in Haskell/plutarch code.

## What are you trying to do? Articulate your objectives using absolutely no jargon.

This document proposes a different way of thinking about programming smart contract logic. At it&#39;s core, it aims to provide a new mental model for how _transactions_ are validated as a whole, rather than individual UTxOs. We call it the &quot;Transaction Token (or TxT) Pattern&quot;.

Using the TxT pattern requires viewing individual transactions as members of  well-defined &quot;families of transactions&quot;. A transaction family is a set of transactions that are all considered valid (N.B.: a &quot;transaction is valid&quot; when all the UTxOs that need to be unlocked and all the tokens that must be forged pass their individual validators/minting policies) for the same _semantic_ criteria. These criteria are established in _Transaction Token Minting Policies_ (or TxTMPs), each of which capture the reason why a particular transaction within a given transaction family is considered valid.

Transaction families come in three forms, each providing consecutively stronger guarantees about the transactions they validate.

- _Weak_ families of transactions are described according to _any_ TxTMP; any minting policy that is sufficient to mint a TxT, such as one that checks whether a given set of predicates hold, can be thought of as encoding a lax transaction family.
- _Strong_ families of transactions treat transactions as functions from their inputs (i.e., UTxOs + Redeemer + parts of `ScriptContext`) to output UTxOs. Specifically, this means that for every redeemer and `ScriptContext` given to a _strong TxTMP,_ there is _exactly one_ valid output that is considered valid; all other outputs are rejected.
- _Strict_ families of transactions also treat transactions as functions from their inputs to their outputs,  but have the additional restriction that a given transaction family operates according to a fixed set of input and output UTxO types. Specifically, the difference between a _strong_ family of transactions and a _strict_ family is that a strong family could say &quot;given _one or more_ UTxOs at validator `A`, and one UTxO at validator `B`, this the output is `X`&quot;, while  a _strict_ family of transactions would say &quot;given _exactly_ one UTxO at each of validators `A` _and_ `B`, the output is `Y`&quot;. Strong transaction families permit more flexible parameterization than strict families.

The TxTMP associated with a given transaction family works as a &quot;deferred validator&quot; to which validators route for the validation of the UTxOs participating in a given transaction. It is the converse of the [Forwarding Minting Policy](./forwarding1.md)  pattern; the given UTxOs only unlock is an authorized transaction token is minted as part of the transaction.

With this model in place, users now must _announce_ their _semantic intention_ when submitting a transaction by choosing a particular TxTMP to target. This unlocks a number of benefits for modularity, conceptual reasoning, ease of specification and development, and security.

## How is it done today, and what are the limits of current practice?

Today, UTxOs at a given validator address are generally burdened with capturing all the ways in which they may be consumed. Developers are generally tasked with determining a set of predicates that capture properties they believe should hold for a given validator, and the unlocking of a UTxO fails if any of those predicates do not hold. This has two downsides.

First, this can lead to a &quot;blacklist&quot; approach. Rather than taking a &quot;default deny&quot; approach where the types of _valid_ transactions are established by passing a set of predicates, there is a tendency for contracts to be written where transactions are considered _invalid_ if certain predicates hold, and any other transaction is valid. This is poor practice for the same reason as for internet firewalls: only blocking &quot;bad actors&quot; via firewall policy assumes that the entire attack surface can be enumerated, while authorizing network usage only in trusted ways ensures that security staff can focus their attention on hardening specific parts of the system. Further, whitelists, by providing an enumerable set of acceptable usages, are much more amenable to formal and informal specification.

Second, complex transactions require consuming UTxOs at multiple Validator addresses. If each Validator Script encodes the logic necessary to validate the conditions for unlocking their own UTxOs, we run into an issue: how do we determine the logic to unlock a group of UTxOs  that can only be unlocked in a given context (quite literally: where do we place logic that requires validation on the entire `ScriptContext`?)

If we choose to fragment the logic across all validators that lock UTxOs for a given transaction family, then we have to be confident that there are no [_generative effects_](https://math.mit.edu/~dspivak/teaching/sp18/C1-Cascade_effects.pdf) (i.e., emergent behavior) caused by recombining the validation logic. This increases the attack surface considerably.

Further, the application logic, application parameters, and component data are fragmented across _all_ Validators required to assemble the complex transaction. For each Validator `V1, V2, V3`, that participates in a complex family of transactions `T1`, a partial transitive closure of the application logic and application parameters necessary to implement any other complex families of transactions `T2, T3, (...)` in which `V1, V2,` and `V3` participate is thus included in the Validator script of `V1, V2`, and `V3`, and hence in the on-chain representation of `T1`. This leads to three issues, all of which are characteristic of [_single dispatch_](https://en.wikipedia.org/wiki/Dynamic_dispatch#Single_and_multiple_dispatch)_._

- First, application logic that is _only_ valid in a context where multiple validators participate is tied to an &quot;owner&quot;. This is akin to a programming language requiring division to be implemented as either a method of the divisor or the dividend. 
- Second, it leads to bloat on-chain. It is akin to requiring the addition of two Integers to first include a proof of how they participate in multiplication, or an unormalized database returning records with extraneous information.
- It is difficult to specify and implement such a system. There are not clear boundaries as to what data is &quot;transaction context specific&quot; or &quot;validator/component&quot; specific. Data and logic often needs to be duplicated, complex (and often circular)  dependencies arise, and systems become fragile. Such a setup hampers modularity, composability, and extensibility.

## What is new in your approach, and why do you think it will be successful?

In the TxT model, we flip the perspective to become &quot;transaction first.&quot; We essentially achieve multiple dispatch for validating transactions _as a whole_, rather than validating the unlocking of each UTxO individually.

Suppose that we have a set of validators (including, with some abuse of terminology, minting policies and user wallets) `V = {V_1, V_2, V_3}` and a set of transaction families `T = {T_1, T_2}`. Additionally, suppose that `V_1` needs logic for `T_1`, `V_2` needs logic for `T_2`, and `V_3` needs logic for both `T_1` and `T_2`. We can think of this as `V_3` being a global state validator that needs to track changes to two subsystems, one of which is expressed by the logic of  `V_1` and the other by the logic of  `V_2`.

The old way of looking at this is as follows. First, we form a table like this:

- `V_1 → {T_1}`
- `V_2 → {T_2}`
- `V_3 → {T_1, T_2}`

Then, we try to determine a set of predicates that would hold to say that a UTxO locked by a given `V_i` is consumed in a valid way. If we let the predicates required for a validator `V_i` to unlock its UTxO be called `P_i`, and then predicates required for transaction family `T_j` to be semantically valid to be called `P'_j`, then we have to show that:

- `P_1 && P_3 = P'_1`
- `P_2 && P_3 = P'_2`

This is non-trivial in the general case, since we are logically working in two different contexts: `P_i` is capturing individual UTxO validation, while `P'_j` is capturing transaction validation.

Implementing this same situation via the TxT pattern means having a TxTMP associated with each of `T1` and `T2` . The TxTMPs encode the complete logic necessary to validate the respective family of transactions. Our table looks like this:

- `T_1 → {V_1, V_3}`  
- `T_2 → {V_2, V_3}`

The Validation logic for `V_i` now works as follows:

- `V_i` carrys information about an authorized set of TxTMPs (i.e., in our first table where `V_1 → {T_1}`, etc.). The _only_ logic contained in the actual validator script is routing logic on how to &quot;dispatch&quot; to a given authorized TxTMP
- To determine whether or not to unlock it&#39;s UTxO, `V_i` checks for the minting of a token with the correct asset class (i.e., the currency symbol of an authorized TxTMP, perhaps with a specific token name) as part of the transaction. If not, the UTxO remains locked.

In effect, instead of having the Validator scripts themselves encode the application logic, they store _references_ (and delegate the validation logic) to the TxTMPs.

Checking that the TxTMP of a particular transaction is in the set of authorized TxTMPs can be facilitated by a State Thread token, hard-coded in the Validator itself, passed in via a continuing Datum, or via any other method that allows for access control over the stored reference. The reference itself must be highly secure, as the Validators  will not have additional checks; it is essentially a privilege escalation, and mechanisms (or unintentional code paths) that allow for changing such a reference should be carefully scrutinized. Such scrutiny is made easier by the fact that the attack surface can be narrowed with  careful modeling and design, and invariants now become easier to prove at the _transaction level_ rather than the _validator level._

Approaches similar to the TxT pattern have already been implemented or theorized in Cardano. The &quot;Governance Authority Token,&quot; specified by Emily Martins from Liqwid, has a similar flavor and takes the appearance of a &quot;dynamic&quot; one-time authorization of a TxTMP via an act of DAO governance. Tilde Rose&#39;s escrow system for Liqwid also has a similar flavor, using a pattern delegating validation to any validator within a given set.

Finally, as mentioned above, the TxT model is essentially the converse of the &quot;forwarded minting policy&quot; pattern and very similiar to multiple dispatch.

> Two notes:  
> -	We use a TxTMP rather than a validator to reduce contention. This circumvents the requirement of introducing additional UTxOs to a transaction to enable the TxT pattern.
> - However, this is not ideal. The minting of a TxT is essentially the lightest-weight way to provide a proof witness that a certain script (the TxTMP) as successfully run, but we don&#39;t necessarily need nor want the token itself. A better option would be allowing for something like a &quot;Transaction Scripts&quot; field to be add to `ScriptContext`, which would require that a given script is run as part of the transaction — regardless of it is actually unlocking a UTxO or minting a token. If the TxT pattern proves viable in practice, this will be worthwhile to write a CIP for.

## Who cares? If you are successful, what difference will it make?

If this pattern works as theorized, we immediately gain several advantages.

- Application logic becomes transaction-centric. It becomes easier to specify a protocol formally, especially when using _strong_ or _strict_ transaction families, since the transition functions are isomorphic to the logic contained in a particular TxTMP.  Analysis techniques such as Petri nets may prove viable from this vantage point.
- Specification and implementation efforts can be more organized. The transaction token pattern gives a _model_ for thinking about contracts that ~~is~~ should be equal in expressiveness to other models. Once the necessary data for a given component is specified, developers can design transactions to manipulate data according to a well-defined schema. Adding support for additional TxTMPs would not typically require adding additional fields to a Datum or parameters to a validator, as is currently the case.
    - The benefits of the pattern are akin to adopting a relational data modeling approach. There are constraints, and it is not _in practice_ the best approach to every domain, but is captures a wide swath of real-world use cases. Where the model is appropriate, the benefits are numerous.
- Validator logic can leverage centralized development and auditing. Because all validators in the TxT pattern implement essentially the same &quot;authorized and delegate&quot; pattern, this logic can be highly scrutinized and optimized.
- The set of authenticated TxTMPs for a given validator can be modified without redeploying the entire protocol. References need to be changed, rather than hard-coded logic. 
- TxTMPs do not need to contain logic to parse, validate, or apply parameters for application logic. As a result, they can be highly specialized for a given protocol, reducing attack surface, script size, and cognitive burden. 
- Theoretical advancements may follow; the TxT pattern has flavors of an effect system, and viewing strict transaction families as morphisms between validator objects lends itself to [categorical analysis](./protocol-category.md).
- Composability and modularity: it becomes easier to integrate off-the-shelf components such as Agora. Implementing a  governance system could become as simple as adding a TxTMP to all application components. Providing &quot;open appliances&quot; on-chain could become viable, where multiple projects use an identical TxTMP parameterized by application-specific authenticated parameters.
- Opinionated development can lead to cleaner code, highlight additional abstractions, and provide both cognitive and technical frameworks for advanced reasoning.

## What are the risks?

The TxT pattern proposes that the converse of the (author&#39;s) current perspective of smart contract development in Cardano be pursued.

Utilizing a complex system such as Cardano in a manner that it was not intended to be used runs the risk of:

- Vendor decisions obsoleting the techniques used
- An increased attack surface via invalid assumptions made about the underlying technology
- Incompatibility with legacy and future developments not utilizing the pattern
- Adding auditing, testing, specification, and cognitive ramp-up burden to existing projects that wish to adopt the pattern

In addition, forthcoming CIPs may simplify this development considerably, so tradeoffs must be weighed regarding the effort expended at a given point in time.

## How much will it cost?

Given the above risks, it is difficult (for the author) to estimate what the cost will be. We can assume, in general,

- Research and labor to prepare a specification to the level of formality required for stakeholder (including auditor) approval
- Experimental development
- Library development
- Testing, auditing, and documentation
- Developer relations, internally and externally, to ensure that such a pattern is considered legitimate and will not become obsolete in a forthcoming update

These costs apply whether a single project adopts the pattern or if an organization-wide library is a goal, although the magnitude will change.

## How long will it take?

A proof-of-concept could be accomplished using existing technologies within a week of dedicated labor. However, full specification, audit, library development, and opinionated documentation are more challenging to estimate and will likely be ongoing as resources and demand allow.

## What are the mid-term and final &quot;exams&quot; to check for success?

The milestones sought, in order, for the general case are:

- A proof-of-concept 
- A detailed specification, including documentation on how to adapt the pattern
- A library/framework
- Analysis and verification techniques (such as Petri nets or other state-transition models)
- Formal third-party audits

The milestones are the same but more limited in scope for inclusion on a single project.
