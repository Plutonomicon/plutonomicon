# Troubleshooting Plutus

This is a space to add/discuss known difficulties in Plutus development and how to overcome them

## Issues with `plutus-tx-plugin`

If your project compiles Haskell functions directly to on-chain validators, that job is done by
[`plutus-tx-plugin`](https://github.com/input-output-hk/plutus/tree/master/plutus-tx-plugin). This GHC plugin can be
finnicky:

* `cabal: Could not resolve dependencies`
  * As of today, the plugin works with GHC 8.10; a newer GHC won't work.
* `Error: Reference to a name which is not a local, a builtin, or an external INLINABLE function`
  * The plugin requires access to AST of all functions and other values involved in the in-chain code. That means every
    function `myHelperFunction` that's called by some on-chain code must be accompanied by an `{-# INLINABLE
    myHelperFunction #-}` pragma.
  * Sometimes GHC mangles the code regardless. Try adding the `{-# OPTIONS_GHC -fno-full-laziness #-}` pragma to the
    top of the module where the problematic value is defined.
  * Another pragma that seems to help is `{-# OPTIONS_GHC -fno-specialise #-}`.
