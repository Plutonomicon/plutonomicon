# _FLLocked_

A **Forwarding Logic-Locked  Minting Policy (_FLLocked MP_)** is a Minting Script parametrised with a Script Address (**Home Address** or **_HA_**).

```
HomeAddress          = Hash ValidationScript 
FLLockedMintigPolicy = HomeAddress -> MintingPolicy
```

The unique property of a **FLLocked Minting Policy** is that it only validates transactions which mint tokens sent to the **Home Address**. This guarantees that the Handling logic of the tokens is done by the **Home Script.**

## Use case 

Usually [Come and Go Proof Tokens](https://mlabs.slab.com/posts/j8zg8yst)s make use of such forwarding Logic-Locked Minting Policies.

# Unique _FLLocked_ 

A **Unique**  **Forwarding Logic-Locked Minting Policy (u_FLLocked MP_)** is a **_FLLocked MP_** further parametrised by the **state** of a unique [Come and Go Proof Tokens](https://mlabs.slab.com/posts/j8zg8yst)  which must be present in the minting/spending transaction for both the **Home Script** and **u_FLLocked MP._**

```
State       = Active | Consumed 
uniqueToken = AssetClass
CnGToken    = (state : State) -> AssetClass -> CnGToken state

HomeAddress = Hash ( uniqueToken ->  ValidationScript ) 

uFLLockedMintigPolicy = uniqueToken -> HomeAddress -> MintingPolicy
```

The logic of Minting Tokens with the **u_FLLocked MP_** is now determined by the state of the **CnG**  **PToken** and so is their subsequent use/unlocking of host `UTXo` from the **Home Script** address.
