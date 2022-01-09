# Forwarding Minting Policy

(credit to [Tilde Rose](https://mlabs.slab.com/users/ayej0o73)  )



Native currencies on the cardano blockchain are 'minted' or 'forged' according to a special type of smart contract called a 'Minting Policy' which determines the conditions in which currencies can be created or destroyed.

Currencies are defined and identified by the hash of the Minting Policy script.



# Plutus  `MintingPolicy` type



In the Plutus Haskell API, Minting Policies are defined by scripts such as the following minting policy,  which allows anybody to mint or destroy exactly one token at a time:



```haskell
> mintingPolicy :: TokenName -> ScriptContext -> Bool
> mintingPolicy tName ctx = 
>   txInfoForge (scriptContextTxInfo ctx) `elem`
>     [ Value.singleton symbol tName 1
>     , Value.singleton symbol tName -1
>     ]
>   where 
>    symbol = ownCurrencySymbol ctx
```

## 'Forwarding' Minting Policies in Plutus



Often, tokens play a more complex role in a smart-contract application, so it's convenient for a validator  script to handle the validation of forging operations.

The Plutus API provides some conveniences for creating 'forwarding' minting policies, which simply check that a particular validator script has been run for any of the inputs to the transaction.

From `Ledger.Typed.Scripts.MonetaryPolicies` (formatting modified) :

```haskell
> {-# INLINABLE forwardToValidator #-}
> forwardToValidator :: ValidatorHash -> () -> ScriptContext -> Bool
> forwardToValidator 
>   h
>   _
>   ScriptContext
>     { scriptContextTxInfo=TxInfo{ txInfoInputs }
>     , scriptContextPurpose=Minting _ }  =
>      let checkHash TxOut 
>           { txOutAddress=Address
>              { addressCredential=ScriptCredential vh } } = vh == h
>          checkHash _                                     = False
>      in any (checkHash . Validation.txInInfoResolved) txInfoInputs
> forwardToValidator _ _ _ = False
```

Using this script, there are some functions to easily work with forwarding minting policies.

```haskell
> -- | A minting policy that checks whether the validator script was run
> --   in the minting transaction.
> mkForwardingMintingPolicy :: ValidatorHash -> MintingPolicy
```

Interestingly, the function we use to wrap and initialize the compiled validator script  adds a `mkForwardingMintingPolicy` to the `tvForwardingMPS` field of the `TypedValidator`, just in  case we might need it.

From `Ledger.Typed.Scripts.Validators` :

```haskell
> -- | Make a 'TypedValidator' from the 'CompiledCode' of a validator script 
> -- | and its wrapper.
> mkTypedValidator ::
>    CompiledCode (ValidatorType a)
>   -- ^ Validator script (compiled)
>   -> CompiledCode (ValidatorType a -> WrappedValidatorType)
>   -- ^ A wrapper for the compiled validator
>   -> TypedValidator a
> mkTypedValidator vc wrapper =
>   let val = Scripts.mkValidatorScript $ wrapper `applyCode` vc
>       hsh = Scripts.validatorHash val
>       mps = MPS.mkForwardingMintingPolicy hsh
>   in TypedValidator
>       { tvValidator         = val
>       , tvValidatorHash     = hsh
>       , tvForwardingMPS     = mps
>       , tvForwardingMPSHash = Scripts.mintingPolicyHash mps
>       }
```

The `typedValidatorLookups`, which itself is called by `submitTxConstraints`, will also include the forwarding minting policy of the script you give it.

```haskell
> -- | A script lookups value with a script instance. For convenience this also
> --   includes the minting policy script that forwards all checks to the
> --   instance's validator.
> typedValidatorLookups :: TypedValidator a -> ScriptLookups a
```

On-Chain Access to the Forwarding Minting Policy of the Current Validator



Since plutus-core doesn't support any primitives computing hashes, all the usual needed hashes are somehow provided via the `ValidatorCtx` or `PolicyCtx` inputs - except for any hashes which are dependent on others.

To work around this, we have to provide the hash of the forwarding policy as part of a Datum input.  In our case, we have to add an extra field containing the  `CurrencySymbol` of the `tvForwardingMPS` to the `MarketState` datum.
