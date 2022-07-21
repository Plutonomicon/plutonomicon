This article will compile information on how the UPLC  (Untyped Plutus Core) cost model works. This is useful for developing intuition on how your scripts&#39; execution budget is calculated, which may in turn help you optimize your scripts!

As a preliminary, you should read the [Tricks section](https://github.com/Plutonomicon/plutarch/blob/master/docs/Tricks.md) of the Plutarch guide - which detail a few useful optimization tricks.

# The CPU and Memory costs are completely unlike regular CPU and Memory usage

The very first thing you have to realize is that the CEK evaluation machine uses a very different, yet arguably naive cost model. Although the execution units are named after &quot;CPU&quot; and &quot;Memory&quot; - they don&#39;t actually work like your typical CPU and Memory!

For example, memory isn&#39;t measured based on a runtime heap (and/or a stack), it is not &quot;freed&quot; when a value goes out of scope, and variable references cost the same (practically _more_) as constants, no matter how big the constant is. In fact, the size of the constant is irrelevant to its **individual** memory cost altogether!

This is why it&#39;s important to not walk into the trap of _assuming_ these units work the same way as real CPU/Mem. Many optimizations that make sense in the real world, may not make any sense in the context of the CEK evaluation machine!

# All UPLC terms have a constant cost - added each time they are evaluated

There are only two **primary** ways your script can ever consume execution units. The first of them is the cost for each UPLC term. Here is what the UPLC AST looks like:

```haskell
data Term name uni fun ann
  = Var !ann !name
  | LamAbs !ann !name !(Term name uni fun ann)
  | Apply !ann !(Term name uni fun ann) !(Term name uni fun ann)
  | Force !ann !(Term name uni fun ann)
  | Delay !ann !(Term name uni fun ann)
  | Constant !ann !(Some (ValueOf uni))
  | Builtin !ann !fun
  | Error !ann
```

Only the tags and the `Term` fields are really relevant, you may ignore everything else. As you can see, you have variable references, lambda abstractions, lambda applications, force, delay, constants, and builtin function identifiers. It&#39;s very similar to regular untyped lambda calculus.

Whenever one of these terms is encountered (also referred to as &quot;machine steps&quot;), any time during your script execution, a **constant** CPU and Memory cost is added. This cost depends on the costing model, but you can see an example of the cost model [here](https://github.com/input-output-hk/plutus/blob/3c4067bb96251444c43ad2b17bc19f337c8b47d7/plutus-core/cost-model/data/cekMachineCosts.json):

```
{
    "cekStartupCost" : {"exBudgetCPU":     100, "exBudgetMemory": 100},
    "cekVarCost"     : {"exBudgetCPU":   23000, "exBudgetMemory": 100},
    "cekConstCost"   : {"exBudgetCPU":   23000, "exBudgetMemory": 100},
    "cekLamCost"     : {"exBudgetCPU":   23000, "exBudgetMemory": 100},
    "cekDelayCost"   : {"exBudgetCPU":   23000, "exBudgetMemory": 100},
    "cekForceCost"   : {"exBudgetCPU":   23000, "exBudgetMemory": 100},
    "cekApplyCost"   : {"exBudgetCPU":   23000, "exBudgetMemory": 100},
    "cekBuiltinCost" : {"exBudgetCPU":   23000, "exBudgetMemory": 100}
}
```

As you can see, all terms have the same cost.

## Constants are more efficient than Variable references

You&#39;ll note here that both `Constant` and `Var` terms have the same cost. This is perhaps somewhat unintuitive as a `Var` will always be accompanied by a `Apply` and a `LamAbs` (or a `Builtin`) - so you always have to pay for those as well. Meanwhile, `Constant`s can be free-standing, and therefore only need to pay the 23000/100 cost.

This effectively means that in many cases, using a `Constant` (no matter how large) is more efficient than using a `Var`. Of course, this is still highly impractical - as the script size would increase drastically if big constants were inlined all around scripts!

As an example, I compared the two scenarios:

1. Working with a constant inlined everywhere.
1. ex: `<huge constant> == <huge constant>`

```
Apply ()
  (Apply ()
    (Builtin () PLC.EqualsData)
      (Constant ()
        (PLC.Some $ PLC.ValueOf PLC.DefaultUniData $ Constr 0
          [ I 50000000
          , B "abcdDASDAWDASDdadlkwqajkjdjhajkhsdiouahwiduhasiuhdikajwhwdkjahskjsdhkajwhdas"
          , I 32135165131
          ]
        )
      )
  )
  (Constant ()
    (PLC.Some $ PLC.ValueOf PLC.DefaultUniData $ Constr 0
      [ I 50000000
      , B "abcdDASDAWDASDdadlkwqajkjdjhajkhsdiouahwiduhasiuhdikajwhwdkjahskjsdhkajwhdas"
      , I 32135165131
      ]
    )
  )
```

1. Working with a variable reference to a constant.
1. ex: `(\x -> x == x) <huge constant>`

```
Apply ()
  (LamAbs () (DeBruijn 0)
    (Apply ()
      (Apply ()
        (Builtin () PLC.EqualsData)
          (Var () (DeBruijn 1))
      )
      (Var () (DeBruijn 1))
    )
  )
  (Constant ()
    (PLC.Some $ PLC.ValueOf PLC.DefaultUniData $ Constr 0
      [ I 50000000
      , B "abcdDASDAWDASDdadlkwqajkjdjhajkhsdiouahwiduhasiuhdikajwhwdkjahskjsdhkajwhdas"
      , I 32135165131
      ]
    )
  )
```

(2. - using references) consumes `exBudgetCPU = ExCPU 668284, exBudgetMemory = ExMemory 901`, whereas (1. - just constants) consumes: `exBudgetCPU = ExCPU 578965, exBudgetMemory = ExMemory 601`

> **NOTE**: The cost model used here may be different from the example cost model linked above. However, the relativity between scenarios will never change based on different _valid_ cost models. Specifically, I used `PlutusCore.defaultCostModel` from `plutus` commit rev `96a00d6e813546e8b5a85fc9d745844979815b07` to measure this.

Indeed, although the variable references _themselves_ cost the exact same as the constants (in terms of CPU and Mem), the mandatory `Apply`, alongside the `LamAbs` drives up the costs.

To reiterate: 3 variable references cost the same as 3 constants (no matter the size) on their own. But surely each of those variable references must accompany a set of `Apply` + `LamAbs` (or `Builtin`)!

# All builtin function calls have a cost

Now, we come to the second _and final_  **major** way your script can consume execution units: builtin function calls. These are the primitives of the UPLC language, and as a result: the backbone of everything you do.

These have a more involved costing model, comparatively speaking. Although some builtin functions have a constant cost across both CPU and Memory (such as `ConstrData`, `MapData` etc.), many of them have their cost associated with their argument(s), with a provided relation.

You can find the example cost model [here](https://github.com/input-output-hk/plutus/blob/3c4067bb96251444c43ad2b17bc19f337c8b47d7/plutus-core/cost-model/data/builtinCostModel.json).

## How to understand the different models

You might be confused by all the different terminology listed within, and may ask how they actually come into calculation.

For example, you might be asking:

> _What the hell does it mean for the_ `type` _to be_ `max_size`_? What is the_ `intercept`_? What is the_ `slope`_? What does this have to do with adding 1 and 1????_

In general, most of the models are just providing arguments for a simple formula - if you&#39;re a data science wizard, you probably already figured out all the formulae for each model type. But I&#39;m not a data science wizard, so I usually glance at the formulae from the [docs](https://playground.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore-Evaluation-Machine-BuiltinCostModel.html) ([backup permalink](https://github.com/input-output-hk/plutus/blob/3c4067bb96251444c43ad2b17bc19f337c8b47d7/plutus-core/plutus-core/src/PlutusCore/Evaluation/Machine/CostingFun/Core.hs)).

You&#39;ll notice how `ModelMaxSize` is described:

```haskell
-- | s * max(x, y) + I
```

Indeed, the `s` is the slope, whereas the `I` is the intercept.

> **NOTE**: Whenever the cost models make a reference to &quot;size&quot;, they are talking about the size of the _actual underlying value_ - not the term. Whether you&#39;re using a variable reference or a constant as an argument to a builtin function that does costing relative to size - the size used for calculation is the same.

But what is _size_? What is that measured with and how? Well, the size is simply the number of **words** a value takes in memory. Finally, we have a real world measurement. Indeed, a word is 64 bits for the conventional CEK evaluation machine. As a result, the integer `18446744073709551615` (maximum value of a 64 bit unsigned integer) has size one. The very next integer: `18446744073709551616` has size two.

## Example analysis with `AddInteger`

Let&#39;s analyze a simple example: the `AddInteger` builtin:

```haskell
"addInteger": {
    "cpu": {
        "arguments": {
            "intercept": 205665,
            "slope": 812
        },
        "type": "max_size"
    },
    "memory": {
        "arguments": {
            "intercept": 1,
            "slope": 1
        },
        "type": "max_size"
    }
}
```

Here&#39;s what is says, given 2 integer arguments: `x` and `y`, of size `m` and `n` respectively - the CPU cost is linear in `max(m, n)` (whichever size is bigger). The exact slope and intercept is also given for the linear graph.

Similarly, the memory cost is also linear in the max size between `m` and `n`, just the intercept and slope are different.

So, given 2 integers, one with size 2 words, and another with size 3 words: the CPU cost of **just the builtin function execution** would be: `812 * 3 + 205665`, or `208101`. Similarly, the memory cost would be: `1 * 3 + 1`, or `4`.

### Hands on

This is all great, but why don&#39;t we test it out? I&#39;ll be using `PlutusCore.defaultCostModel` from `plutus` commit rev `96a00d6e813546e8b5a85fc9d745844979815b07` to test out an example. This cost model is slightly different, let&#39;s look at it briefly:

The machine costs:

```haskell
{
    "cekStartupCost" : {"exBudgetCPU":     100, "exBudgetMemory": 100},
    "cekVarCost"     : {"exBudgetCPU":   29773, "exBudgetMemory": 100},
    "cekConstCost"   : {"exBudgetCPU":   29773, "exBudgetMemory": 100},
    "cekLamCost"     : {"exBudgetCPU":   29773, "exBudgetMemory": 100},
    "cekDelayCost"   : {"exBudgetCPU":   29773, "exBudgetMemory": 100},
    "cekForceCost"   : {"exBudgetCPU":   29773, "exBudgetMemory": 100},
    "cekApplyCost"   : {"exBudgetCPU":   29773, "exBudgetMemory": 100},
    "cekBuiltinCost" : {"exBudgetCPU":   29773, "exBudgetMemory": 100}
}
```

The `AddInteger` cost:

```haskell
"addInteger": {
    "cpu": {
        "arguments": {
            "intercept": 197209,
            "slope": 0
        },
        "type": "max_size"
    },
    "memory": {
        "arguments": {
            "intercept": 1,
            "slope": 1
        },
        "type": "max_size"
    }
}
```

> Aside: Yes, the slope is 0 on this cost model. Wait, doesn&#39;t that make the CPU cost effectively constant? Yes, yes it does. Don&#39;t ask me why it&#39;s like this!

Alright, with that out of the way, let&#39;s write and evaluate a UPLC term:

```haskell
Apply ()
  (Apply ()
    (Builtin () PLC.AddInteger)
    (Constant () $ PLC.Some $ PLC.ValueOf PLC.DefaultUniInteger 1)
  )
  (Constant () $ PLC.Some $ PLC.ValueOf PLC.DefaultUniInteger 1)
```

Starting with a good ol&#39; philosophical &quot;what _is_ one plus one really?&quot; never hurts.

Here&#39;s the execution cost I got for that: `exBudgetCPU = ExCPU 346174, exBudgetMemory = ExMemory 602`

Alright! So let&#39;s get dissecting. First off, we can take out 100 CPU and 100 Mem right out since that&#39;s the startup cost, giving us:

| CPU | Mem |
| --- | --- |
| 346,074 | 502 |

Now, we have 5 terms - it&#39;s obvious that each of them is only evaluated once, so we can multiply the constant cost for each term (29,773 CPU; 100 Mem) with 5 and subtract that out, which gives us:

| CPU | Mem |
| --- | --- |
| 197,209 | 2 |

Hmm, that&#39;s a familiar number. `197,209` is exactly the amount the `AddInteger` execution should consume! Don&#39;t believe me?

```
= slope * max(m, n) + intercept
= 0 * max(m, n) + 197209 [∵ See `AddInteger` cost model above]
= 197209
```

During high school exams, this sort of correspondence was usually a sign of all your calculations being correct, allowing you to breathe a sigh of relief. It&#39;s probably not too different in this case.

What about the memory? Well, the memory follows the same formula with different slope and intercept amounts:

```
= slope * max(m, n) + intercept
= 1 * max(m, n) + 1 [∵ See `AddInteger` cost model above]
= 1 * 1 + 1 [∵ The integer `1` consumes one word in memory, ∴ size = 1]
= 2
```

And it all plays out nicely.

Let&#39;s try replacing the `1 + 1` with `52154512154012152215121 + 1`!

```haskell
Apply ()
  (Apply ()
    (Builtin () PLC.AddInteger)
    (Constant () $ PLC.Some $ PLC.ValueOf PLC.DefaultUniInteger 52154512154012152215121)
  )
  (Constant () $ PLC.Some $ PLC.ValueOf PLC.DefaultUniInteger 1)
```

Result: `exBudgetCPU = ExCPU 346174, exBudgetMemory = ExMemory 603`.

Of course, `52154512154012152215121` takes two words in memory, and as a result the `max(m, n)` has changed.

The CPU _should have_ changed in usual scenarios, but this cost model has the slope for `AddInteger` set to 0! So the CPU cost doesn&#39;t depend on the argument sizes at all.

The memory on the other hand, has expectedly increased by one:

```haskell
= slope * max(m, n) + intercept
= 1 * max(m, n) + 1 [∵ See `AddInteger` cost model above]
= 1 * 2 + 1 [∵ The integer `52154512154012152215121` consumes two words in memory, ∴ size = 2]
= 3
```

## Remember: This cost is _only_ for the builtin function execution!

Recall that you pay execution cost for evaluating each UPLC term (also known as CEK machine steps) and builtin function execution. It&#39;s important to realize that the cost you calculate for **just the builtin function execution** (e.g `AddInteger 1 2`) is not the only cost you pay for that expression. In fact, you&#39;re still paying for the builtin function term, the application, the constants/variable references etc. Some builtin functions even need to be [accompanied with a `Force`](https://github.com/Plutonomicon/plutonomicon/blob/main/builtin-functions.md) before they can be applied, driving up the tertiary costs even higher (albeit by a constant amount)!

# The CEK machine has a constant startup cost

This one will be brief. There is a small, constant startup cost associated with each script. This will be added to each script execution no matter what - so it is important you&#39;re aware of it before doing reverse engineering calculations on the execution cost. For the example cost model we&#39;re using here, it is simply 100 CPU and 100 Memory units.

# Unevaluated bodies of Lambdas don’t add to CPU/Memory costs

This is to clarify that script size does not contribute to Memory costs (or CPU costs), as some outdated comments in the Plutus repo suggest. See discussion [on github](https://github.com/input-output-hk/plutus/issues/4737).

As a result, when you have a script like:

```haskell
LamAbs () (DeBruijn 0) (<huge body with loads of terms>)
```

Evaluating it (without applying any arguments) will simply cost you: the CEK startup cost + cost of a singular LamAbs term.

# You only pay for what you look at

You may have realized that due to how the cost model works, due to the fact that `Memory`  _isn&#39;t really_ a measure of memory, costing for script arguments (script context, datum, redeemer) is very much ad-hoc.

Indeed, if your script receives a massive `ScriptContext` with loads of data, but you never look at most of it, you don&#39;t pay the execution units for it. No CPU, No Memory.

Feels a bit unintuitive? Well, that&#39;s not unexpected - but if you forget everything about how real CPU and Memory works, and simply walk the fully laid out and naive UPLC costing model path - you&#39;ll realize why this is the case.

> Aside: Are you already familiar with how builtin data and data deconstruction works in UPLC? Awesome! If not, you should familiarize yourself with it before moving forward in this specific section. Refer to the [builtin-data guide on Plutonomicon](https://github.com/Plutonomicon/plutonomicon/blob/main/builtin-data.md)

First, let&#39;s talk about the function application. Surely, the massive script context is _applied_ to your script, right? Well, what does this cost? The `ScriptContext` being applied will be a `Constant` term - this is pre-known. But recall that there&#39;s a constant cost associated with the `Apply`, and the `Constant` - and the size of the constant doesn&#39;t matter! So there you go, you don&#39;t pay anything extra for large script contexts during the initial application.

Ok, but what next? Surely the first thing you do with the `ScriptContext` is call `UnConstrData` on it, to obtain its two fields. Won&#39;t `UnConstrData` consume extra execution units depending on size?

As a matter of fact, no! It has a constant cost:

```javascript
"unConstrData": {
    "cpu": {
        "arguments": 32696,
        "type": "constant_cost"
    },
    "memory": {
        "arguments": 32,
        "type": "constant_cost"
    }
}
```

Well, that&#39;s quite nice! But now, you want to look into the `TxInfo` - which, in our example scenario, is huge. `TxInfo` is the first field in `ScriptContext`, so we need to get the `head` of the returned list of fields.

That means we have to do a `HeadList` call, maybe this has extra cost depending on si-….. no, it doesn&#39;t:

```javascript
"headList": {
    "cpu": {
        "arguments": 43249,
        "type": "constant_cost"
    },
    "memory": {
        "arguments": 32,
        "type": "constant_cost"
    }
}
```

And then you go on to `UnConstrData` on `TxInfo` and the cycle continues! Indeed, most builtin construction _and_ deconstruction functions are constant cost (only exceptions being bytestring cons, append, and slice). As a result, even if your script gets a massive script context - you don&#39;t pay the full cost for it if you don&#39;t go looking in every nook and cranny for it!

## What this means for PlutusTx and Plutarch

For PlutusTx, this hardly means anything - it&#39;s a lost cause. You see, PlutusTx compiled code decodes all the arguments it receives from the chain. Indeed, the `ScriptContext`, the `Datum`, the `Redeemer` - everything goes through a structure validation and decoding process to be converted to scott encoding. This effectively means that you always pay the full cost.

Unless, of course, you use the [Spooky technique](https://gitlab.com/fresheyeball/plutus-tx-spooky) - which basically delegates the decoding by using `BuiltinData` for all field types, forcing the PlutusTx compiler to not insert massive decoding and validation steps (everything is kept as `BuiltinData`). Later on, it is the user&#39;s responsibility to decode only the fields they want/need.



As you may expect, Plutarch fares a whole lot better. Plutarch made a conscious decision to never implicitly decode anything. Your `PAsData` arguments _stay_ data encoded, they&#39;re not decoded in any way.

You can, of course, choose to validate them using `PTryFrom` - which is often necessary for avoiding security holes. Indeed, you may not be able to trust the datums/redeemers  provided to the script depending on your spec/protocol.

In these cases, you must note that `PTryFrom` is _supposed to_ do a deep validation. In other words, it _does_ look at every nook and cranny. Of course, there is no reason to do this on a `ScriptContext`. But you may be forced to do it on your datum/redeemer . As a result, you end up paying the cost upfront for validating large datums/redeemers even if you&#39;re not interested in all its fields.

# Memory calculation is often unfair and inaccurate

As showcased above, due to how the CEK evaluation machine works: memory consumption of a script may sometimes feel unfair and downright illogical - with no real idiomatic way to optimize it. Unfortunately, it seems like IOG themselves have not paid much attention to the memory costing in particular - and everything is rather handwavy. They imply that memory budgeting isn&#39;t all too relevant[1](#references) - yet they refuse to remove it as a limit altogether (for good reason). As a result, for large, complex scripts - memory costs often end up becoming a big problem. In this case, it is recommended that you try and simplify the logic of the script - and potentially break it up into different scripts, and perhaps even different transactions.

# Where is the real cost model?

As far as I know, you can find the real cost model from the protocol parameters, which you can query for via `cardano-cli`.

# References and useful links

1. Section 8, Memory Usage on [plc-cost-model-description](https://app.slack.com/client/T01UN827FQV/C01URABDHKL/files/F031S8NHJ21) (**internal** slack link)
2. The [plc-cost-model-description](https://app.slack.com/client/T01UN827FQV/C01URABDHKL/files/F031S8NHJ21) (**internal** slack link)
3. [Plutonomicon `builtin-functions` guide](https://github.com/Plutonomicon/plutonomicon/blob/main/builtin-functions.md)
4. [Plutonomicon `builtin-data` guide](https://github.com/Plutonomicon/plutonomicon/blob/main/builtin-data.md)
5. The [example cost model](https://github.com/input-output-hk/plutus/blob/3c4067bb96251444c43ad2b17bc19f337c8b47d7/plutus-core/cost-model/data/cekMachineCosts.json) from the plutus-core repo
6. [Builtin functions](https://playground.plutus.iohkdev.io/doc/haddock/plutus-core/html/PlutusCore.html#t:DefaultFun), i.e `DefaultFun`
7. The [UPLC AST](https://playground.plutus.iohkdev.io/doc/haddock/plutus-core/html/UntypedPlutusCore-Core-Type.html#t:Term) definition.
