# CnG PToken

A **Come and Go Proof Token (CnG PToken)** is an **Asset** present in a `UTXo` which if used in the input of a `Tx`  **must be replaced at the same address** where it was taken from.

This property must be guaranteed by the **Home Address Script** at which the **CnG PToken** can be found.

![](https://static.slab.com/prod/uploads/pigzq8jp/posts/images/p5QrXcrQ8ndWr2PZtvueujIt.jpg)

## Use case

### Linked List Head Token 

When guaranteeing that an a soon to be inserted node (yet to be minted)  is **Valid** the **Minting Policy** can make use of a **CnG PToken** found in the **HEAD** of the list to assess if the list exists or was correctly minted.

## State CnG PTokens

**CnG PTokens** can also record _State_ and _State_ change. Due to their unlocking being controlled by the  **Home Script**, additional logic can be integrated to check for the change of `Datum` attached to the `UTXo` or burning and re-minting with a different  `TokenName.`

![](https://static.slab.com/prod/uploads/pigzq8jp/posts/images/FuqavNZ8jtKU7nSUv19iRPqr.png)
