Credit - Koz Ross

# Introduction

> &quot;God gave us the integers; all else is the work of man.&quot;
> [Leopold Kronecker](https://en.wikiquote.org/wiki/Leopold_Kronecker)
> 
> &quot;Plutus gave us the `Integer`s; all else is the work of MLabs.&quot;
> Anonymous

Numbers are a concept that is at the same time familiar in its generalities, but aggravating in its detail. This is mostly because mathematicians typically operate in the real line, which we, as computer scientists, cannot; additionally, as Haskell developers, we are more concerned with _capabilities_ than _theorems._ Therefore, working with numbers on a computer is, in basically every language, some degree of unsatisfactory.

The goal of this document is to provide:

1. An explanation of the numerical hierarchy of Plutus, as well as our extensions to it;
1. A reasoning of why it was designed, or extended, in the way that it was; and
1. A clarification of the algebraic laws and principles underlying everything, to aid you in their use and extension.

# Basics

Plutus provides two &#39;base&#39; numerical types: `Integer` and `Rational`. These correspond to `Z` and `Q` in mathematics, and in theory, all the operations reasonable to define on them.

Why do mathematicians refer to the integers as `Z` and the rationals as `Q`? The former is from the German _Zahlen,_ meaning &#39;numbers&#39;; the latter from the Italian _quoziente,_ meaning &#39;quotient&#39;.

As MLabs extensions, we also provide `Natural` and `NatRatio`; the former corresponds to `N` in mathematics, while the latter doesn&#39;t really have an analog that&#39;s talked about much, but represents the non-negative part of `Q`. We will write this as `Q+`.

Part of the challenge of a numerical hierarchy is the tension between:

1. The overloading of many mathematical concepts, such as addition; and
1. The fact that the behaviour of different numerical types makes these vary in behaviour.

We want to have the ability to write number-related concepts without having to have several varieties of the same operation: the natural method for this is type classes, whose original purpose was ad-hoc polymorphism. It is likely that numerical concepts were a high priority for this kind of behaviour. However, _because_ type classes allow ad-hoc polymorphism, we have to define clear expectations of what we expect a &#39;valid&#39; or &#39;correct&#39; implementation of a type class method to do. This also ties back to our problem: we want the behaviour of our numerical operators to be consistent with our intuition and reasoning, but also flexible enough to allow grouping of common behaviour.

## Inadequacy of `Num`

The Haskell approach to  arithmetic and numerical operations involves the `Num` type class. This approach is highly unsatisfactory as a foundation, for multiple reasons:

- A lot of unrelated concepts are &#39;mashed together&#39; in this design. In particular, `fromInteger` is really a _syntactic_ construction for overloading numerical syntax, which is at odds with everything else in `Num`.
- `Num` is &#39;too strong&#39; to serve as a foundation for a numerical hierarchy. As it demands a definition of either `negate` or `-`, it means that many types (including `Natural`) must be partial in _at least_ this method. Furthermore, demanding a definition of `fromInteger` for values that _cannot_ be negative (such as `Natural`) requires either odd behaviour or partiality.
- `Num` is not well-founded. It is similar enough to a range of concepts, but not similar enough to actually rely on.

Thus, instead of this, Plutus took a different approach, which we both explain, and extend, here.

It is informative to compare the approach chosen by Plutus (and our extensions) with similar concepts in Purescript, which often start on similar foundations, but use different implementations and laws. We will mention these where useful in green boxes like this.

## Semigroups and Monoids

Everything must begin with a foundation; in the case of the Plutus numerical hierarchy, it is the familiar `Semigroup` and `Monoid`.

```haskell
class Semigroup (a :: Type) where
  (<>) :: a -> a -> a

class (Semigroup a) => Monoid (a :: Type) where
  mempty :: a
```

These come with two laws:

- For any `x, y, z`, `(x <> y) <> z = x <> (y <> z)` (associativity).
- For any `x`, `x <> mempty = mempty <> x = x` (identity of `mempty`).

When we describe _laws,_ the `=` symbol refers to _substitution,_ rather than _equality_ in the sense of the `Eq` type class. Thus, in the description of a law, when we say `lhs = rhs`, we mean &#39;we can always replace `lhs` with `rhs`, and vice versa, and get the same result&#39;.

`Semigroup` and `Monoid` have a plethora of uses, and act as a foundation of _many_ concepts, both in Haskell and outside of it. However, we need more structure than this to define sensible arithmetic.

Mathematically, there is a convention to talk of _additive_ and _multiplicative_ semigroups, monoids, and indeed, other structures. This &#39;links together&#39; two _different_ structures over the same set, and provides us with additional guarantees. To this effect, Plutus defines `AdditiveSemigroup`, `AdditiveMonoid`, `MultiplicativeSemigroup` and `MultiplicativeMonoid`, as so:

```haskell
class AdditiveSemigroup (a :: Type) where
  (+) :: a -> a -> a

class (AdditiveSemigroup a) => AdditiveMonoid (a :: Type) where
  zero :: a

class MultiplicativeSemigroup (a :: Type) where
  (*) :: a -> a -> a

class (MultiplicativeSemigroup a) => MultiplicativeMonoid (a :: Type) where
  one :: a
```

As per [additive semigroups](https://en.wikipedia.org/wiki/Additive_group), [multiplicative semigroups](https://en.wikipedia.org/wiki/Multiplicative_group), and the corresponding monoids, we have the following laws:

- `a` must be a `Semigroup` (and `Monoid`) under `+` (with `zero`) and `*` (with `one`).
- For any `x, y`, `x + y = y + x`. In words, `+` must _commute,_ or `+` is a _commutative operation._

Using this, we get the following instances:

```haskell
-- Provided by Plutus

instance AdditiveSemigroup Integer
instance AdditiveMonoid Integer
instance MultiplicativeSemigroup Integer
instance MultiplicativeMonoid Integer

instance AdditiveSemigroup Rational
instance AdditiveMonoid Rational
instance MultiplicativeSemigroup Rational
instance MultiplicativeMonoid Rational

-- Provided by us

instance AdditiveSemigroup Natural
instance AdditiveMonoid Natural
instance MultiplicativeSemigroup Natural
instance MultiplicativeMonoid Natural

instance AdditiveSemigroup NatRatio
instance AdditiveMonoid NatRatio
instance MultiplicativeSemigroup NatRatio
instance MultiplicativeMonoid NatRatio
```

These are defined in the expected way, using addition, zero and one for `Z`, `Q`, `N` and `Q+` respectively.

## Semiring: the foundation of the universe

The combination of additive and multiplicative monoids on the same set (type for Haskell) has special treatment, and capabilities, as well as a name: a [_semiring_](https://en.wikipedia.org/wiki/Semiring)_._ This forms a fundamental structure, both for abstract algebra, but also for any numerical system, as it fundamentally represents a combination of two fundamental operations (addition and multiplication), plus the identities and behaviours we expect from them.

In Plutus, it is assumed that _anything_ which is both an `AdditiveMonoid` and a `MultiplicativeMonoid` is, in fact, a semiring:

```haskell
type Semiring (a :: Type) = (AdditiveMonoid a, MultiplicativeMonoid a)
```

This statement hides some laws which are required for `a` to be a semiring:

- For any `x, y, z`, `x * (y + z) = x * y + x * z`. This law is called _distributivity_; we can also say that `*`  _distributes over_ `+`_._
- For any `x`, `x * zero = zero * x = zero`. This law is called _annihilation._

We thus have to ensure that we _only_ define this combination of instances for types where these laws apply.

Purescript defines a `Semiring type class` of its own instead of defining the &#39;additive&#39; and &#39;multiplicative&#39; halves separately. This is better for lawfulness, but less compositional than the Plutus approach.

Distributivity in particular is a powerful concept, as it allows us much of the power of algebra over numbers. This can be applied in many contexts, possibly achieving non-trivial speedups: consider some of the examples from [_Semirings for Breakfast_](https://marcpouly.ch/pdf/internal_100712.pdf)_._

While `*` for `Integer`, `Natural`, `NatRatio` and `Rational` happens to be commutative, this isn&#39;t required in general; for a semiring, only addition must commute. For a good counter-example, consider [square matrices](https://en.wikipedia.org/wiki/Square_matrix) of any of these types: all the semiring laws fit, but matrix multiplication _certainly_ does not commute.

# Two universes

As a foundation for a numerical hierarchy (or system in general), semirings (and indeed, `Semiring`s) get us fairly far. However, they do not give us enough for a full treatment of the four basic arithmetical operations: we have a treatment of addition and multiplication, but _not_ subtraction or division.

Generally, addition and subtraction are viewed as &#39;paired&#39; operations, where one &#39;undoes&#39; the other. This is a common mathematical concept, termed an [_inverse_](https://en.wikipedia.org/wiki/Inverse_function)_._ Thus, it&#39;s common to consider subtraction as &#39;inverse addition&#39; (and division as &#39;inverse multiplication&#39;). However, these statements hide some complexity; there are, in fact, _two_ ways to view subtraction (only one of which is a true inverse), while division is only a partial inverse. These are of minor note to mathematicians, but of _significant_ concern to us as Haskell developers. We want to ensure good laws and totality, but also have the behaviour of these operations line up with our intuition.

The &#39;classical&#39; treatment of subtraction involves extending the additive monoids we have seen so far to [_additive groups_](https://en.wikipedia.org/wiki/Additive_group)_,_ which contain the notion of an [_additive inverse_](https://en.wikipedia.org/wiki/Additive_inverse) __ for each element. In Plutus, we have this notion in the `AdditiveGroup` type class:

```haskell
class (AdditiveMonoid a) => AdditiveGroup (a :: Type) where
  (-) :: a -> a -> a
```

There is also a helper function `negate :: (AdditiveGroup a) => a -> a`, which gives the additive inverse of its argument. The only law for `AdditiveGroup`s is that for all `x`, there exists a `y` such that `x + y = zero`. Both `Integer` and `Rational` are `AdditiveGroup`s (using subtraction for `-`); however, neither `Natural` nor `NatRatio` can be, as subtraction on `N` or `Q+` is not [_closed_](https://en.wikipedia.org/wiki/Closure_(mathematics))_._ This is one reason why `Natural` is awkward to use in Haskell in particular. While we _could_ define some kind of &#39;alt-subtraction&#39; based on additive inverses for these two types, they wouldn&#39;t fit our notion of what subtraction &#39;should be like&#39;.

An alternative approach is proposed by [Gondran and Minoux](https://www.springer.com/gp/book/9780387754499). This is done by identifying an alternative (and mutually-incompatible) property of (some) monoids, and using it as a basis for a separate, but lawful, operation.

## A mathematical aside

The next stuff leans heavily on abstract algebra and maths. You can skip past this section if this doesn&#39;t interest you - another marker of this kind will indicate the end of that section, along with a summary of the conclusions.

For any monoid, we can define two _natural orders._ Given a monoid `M = (S, *, 0)`, we define the _left natural order_ on `S` as so: for all `x, y` in `S`, `x <~= y` if and only if there exists `z` in `S` such that `y = z * x`. The _right natural order_ on `S` is defined analogously: for all `x, y` in `S`, `x <=~ y` if and only if there exists `z` in `S` such that `y = x * z`.

Consider `Ordering`, with its instances of `Semigroup` and `Monoid`:

```haskell
data Ordering = LT | EQ | GT

-- Slightly longer than what exists in base, for clarity
instance Semigroup Ordering where
  LT <> LT = LT
  LT <> EQ = LT
  LT <> GT = LT
  EQ <> LT = LT
  EQ <> EQ = EQ
  EQ <> GT = GT
  GT <> LT = GT
  GT <> EQ = GT
  GT <> GT = GT

instance Monoid Ordering where
  mempty = EQ
```

The left natural order on `Ordering` would be defined as so:

```haskell
(<~=) :: Ordering -> Ordering -> Bool
LT <~= LT = True
LT <~= EQ = False
LT <~= GT = True
EQ <~= LT = True
EQ <~= EQ = True
EQ <~= GT = True
GT <~= LT = True
GT <~= EQ = False
GT <~= GT = True
```

Intuitively, the left natural ordering makes `EQ` the smallest element, and all the others are &#39;about the same&#39;. The right natural order on `Ordering` is instead this:

```haskell
(<=~) :: Ordering -> Ordering -> Bool
LT <=~ LT = True
LT <=~ EQ = False
LT <=~ GT = False
EQ <=~ LT = True
EQ <=~ EQ = True
EQ <=~ GT = True
GT <=~ LT = False
GT <=~ EQ = False
GT <=~ GT = True
```

This is different; here, `EQ` is still the smallest element, but `LT` and `GT` are now mutually incomparable.

We note that:

- Any natural order is [_reflexive_](https://en.wikipedia.org/wiki/Reflexive_relation). As `0` is a neutral element, for any `x`, `x * 0 = 0 * x = x`; from  this, it follows that both `x <~= x`  and `x <=~ x` is always the case.
- Any natural order is [_transitive_](https://en.wikipedia.org/wiki/Transitive_relation). If we have `x, y, z` such that `x <~= y` and `y <~= z`, we have `x', y'` such that `y = x' * x` and `z = y' * y`; thus, as `*` is closed, we can see that `z = (y' * x') * x`. Furthermore, as `*` is associative, we can ignore the bracketing. While we demonstrate this on a left natural order, the case for the right natural order is symmetric.

This combination of properties means that any natural order is at least a [_preorder_](https://en.wikipedia.org/wiki/Preorder)_._ We also note that the only thing setting left and right natural orders apart is the fact that `*` doesn&#39;t have to be commutative; if it is, the two are identical, and we can just talk about _the_ natural order, which we denote `<~=~`. In our case, this is convenient, as additive monoids are _always_ commutative in their operation.

In order to have a natural order (that is, have left and right natural orders coincide), being a commutative monoid is _sufficient,_ but not _necessary_. More precisely, all commutative monoids have coinciding left and right natural orders (as changing the order of the arguments to their operator doesn&#39;t change the meaning); however, there are non-commutative monoids whose left and right natural orders happen to coincide anyway.

Consider `N` under multiplication, with 1 as the identity element. For the left natural ordering, we note the following:

- 1 is smaller than anything else: `1 <~= y` must imply that there exists `z` such that `y = z * 1`; as _anything_ multiplied by 1 is just itself, this holds for any `y`. However, `x <~= 1` must imply that there exists `z` such that `1 = z * x`, which is impossible for any `x` except 1.
- 0 is larger than anything else: `x <~= 0` must imply that there exists `z` such that `0 = z * x`; we can always choose `z = 0` to make that true. However, `0 <~= y` must imply that there exists `z` such that `y = z * 0`; for any `y`  _other_ than 0, this is not possible.
- Otherwise, `x <~= y` if `x` is a factor of `y`, but never else: if `x <~= y` holds, it implies that there exists `z` such that `y = z * x`. This is only possible if `x` is a factor of `y`, as otherwise, we would have to produce `z = y / x`, which does not exist in general in `N`.

For the right natural ordering, we get the following, repeated for clarity:

- 1 is smaller than anything else: `1 <=~ y` must imply that there exists `z` such that `y = 1 * z`; as _anything_ multiplied by 1 is just itself, this holds for any `y`. However, `x <=~ 1` must imply that there exists `z` such that `1 = x * z`, which is impossible for any `x` except 1.
- 0 is larger than anything else: `x <=~ 0` must imply there exists `z` such that `0 = x * z`; we can always choose `z = 0` to make that true. However, `0 <=~ y` must imply there exists `z` such that `y = 0 * z`; for any `y`  _other_ than 0, this is not possible.
- Otherwise, `x <=~ y` if `x` is a factor of `y`, but never else: if `x <= y` holds, it implies that there exists `z` such that `y = x * z`. This is only possible if `x` is a factor of `y`, as otherwise, we would have to produce `z = y / x`, which does not exist in general in `N`.

We can see that the outcomes are the same for both orders, as multiplication on `N` commutes.

Let `M = (S, *, 0)` be a monoid with a natural order `<~=~`. We say that `<~=~` is a _canonical natural order_ if `<=` is [_antisymmetric_](https://en.wikipedia.org/wiki/Antisymmetric_relation)_;_ specifically, if for any `x,y`, `x <~=~ y` and `y <~=~ x`imply that `x = y`. Because all natural orders (canonical or not) are also reflexive and transitive, any canonical natural order is (at least) a [_partial order_](https://en.wikipedia.org/wiki/Partially_ordered_set#Partial_order_relation)_._

As an example, consider the natural order of `N` with multiplication and 1 as the identity described above. This is a canonical natural order, for the following reason: if we have both `x <~=~ y` and `y <~=~ x`, it means that we have `z1` and `z2` such that both `y = x * z1` and also `x = y * z2`. Substituting the definition of `x` into the first equation yields `y = y * z2 * z1`, which implies that `z2 * z1 = 1`, which in turn implies that `z1 = 1` and `z2 = 1`. Therefore, it must be the case that `x = y * 1` and `y = x * 1`, which means `x = y`. As a counter-example, consider the natural order on `Z` with multiplication and 1 as the identity. We observe that `1 <~=~ -1`, as `-1 = 1 * -1`; however, simultaneously, `-1 <~=~ 1`, as `1 = -1 * -1` - but of course, `1 /= -1`.

By a theorem of Gondran and Minoux, the properties of canonical natural order and additive inverse are mutually-exclusive: _no_ monoid can have both. We say that `M` is _canonically-ordered_ in this case.

This raises the question of whether we can recover something similar to an additive inverse, but in the context of a canonical natural order. It turns out that we can.  Let `M = (S, +, 0)` be a commutative, canonically-ordered monoid with canonical natural order `<~=~`. Then, there exists an operation _monus_ (denoted `^-`), such that `x ^- y` is the unique least `z` in `S` such that `x <~=~ y + z`.

We call such an `M` a _hemigroup;_ if `M` happens to be an additive monoid, that would make it an _additive hemigroup._ The term &#39;hemigroup&#39; derives from Gondran and Minoux, designed to designate a &#39;separate but parallel&#39; concept to groups.

This terminology is a little different to Gondran and Minoux&#39;s original presentation: in their work, a hemigroup must be cancellative. We take the approach described here for two reasons: firstly, having a parallel to minus (in monus) makes the &#39;symmetry&#39; with groups far clearer; secondly, our goals are  a sensible definition of arithmetic in Plutus, rather than a minimal elucidation of properties.

tl;dr of the above: we can define a mutually-incompatible notion similar to additive inverses (based on an operation called &#39;monus&#39;), which follows its own rules.

## A different subtraction

Based on the principles described above, we can define a parallel concept to `AdditiveGroup` in Plutus. We provide this as so:

```haskell
class (AdditiveMonoid a) => AdditiveHemigroup (a :: Type) where
  (^-) :: a -> a -> a
```

Unlike `AdditiveGroup`, the laws required for `AdditiveHemigroup` are [more extensive](https://en.wikipedia.org/wiki/Monus#Properties):

- For any `x, y`, `x + (y ^- x) = y + (x ^- y)`.
- For any `x, y, z`, `(x ^- y) ^- z = x ^- (y + z)`
- For any `x`, `x ^- x = zero ^- x = zero`

Both `Natural` and `NatRatio` are valid instances of this type class; in both cases, monus corresponds to the &#39;difference-or-zero&#39; operation, which can be (informally) described as:

```haskell
x ^- y 
  | x < y = zero
  | otherwise = x - y
```

## One arithmetic, two systems

Having both `AdditiveGroup` and `AdditiveHemigroup`, and their mutual incompatibility (in the sense that no type can lawfully be both) creates two &#39;universes&#39; in the numerical hierarchy, both rooted at `Semigroup`. On one hand, if we have an additive inverse available, we get a combination of additive group and multiplicative monoid, which is a [_ring_](https://en.wikipedia.org/wiki/Ring_(mathematics))_:_

```haskell
-- Provided by Plutus
type Ring (a :: Type) = (AdditiveGroup a, MultiplicativeMonoid a)
```

As with `Semiring`, Purescript instead has a dedicated `Ring type class`. This follows essentially the same laws we have.

On the (incompatible) other, if we have a monus operation, we get a combination of additive _hemi_group and multiplicative monoid, which is a _hemiring:_

```haskell
-- Provided by us
type Hemiring (a :: Type) = (AdditiveHemigroup a, MultiplicativeMonoid a)
```

Both of these retain the laws necessary to be `Semiring`s (which they are both extensions of), but add the requirements of `AdditiveGroup` and `AdditiveHemigroup` respectively.

Rings have a rich body of research in mathematics, as well as considerably many extensions; hemirings (and generally, work related to canonically-ordered monoids and monus) are far less studied: only [Gondran and Minoux](https://www.springer.com/gp/book/9780387754499) have done significant investigation of this universe mathematically, demonstrating that many of the capabilities and theorems around rings can, to some degree, be recovered in the alternate universe. [_Semirings for Breakfast_](https://marcpouly.ch/pdf/internal_100712.pdf) __ presents more practical results, but takes a slightly different foundation (since the basis of his work are what Gondran and Minoux call _pre-semirings_, which lack identity elements).

In some respect, this distinction is similar to the inherent separation between `Integer` (which, corresponding to `Z`, is &#39;the canonical ring&#39;) and `Natural` (which, corresponding to `N`, is &#39;the canonical hemiring&#39;).

## Absolute value and signum

The extended structures based on rings are not only of theoretical interest: we describe one example where they allow us to capture useful behaviour (absolute value and signum) in a law-abiding, but generalizable way.

Let `R = (S, +, *, 0, 1)` be a ring. We say that `R` is an [_integral domain_](https://en.wikipedia.org/wiki/Integral_domain) __ if for any `x /= 0`  and `y, z` in `S`, `x * y = x * z` implies `y = z`. In some sense, being an integral domain implies a (partial) cancellativity for multiplication. Both `Z` and `Q` are integral domains; this serves as an important &#39;extended structure&#39; based on rings.

We can use this as a basis for notions of [absolute value](https://en.wikipedia.org/wiki/Absolute_value) and [signum](https://en.wikipedia.org/wiki/Sign_function). First, we take an [algebraic presentation](https://en.wikipedia.org/wiki/Absolute_value_(algebra)) of absolute value; translated into Haskell, this would look as so:

```haskell
-- Not actually defined by us, but similar
class (Ord a, Ring a) => IntegralDomain (a :: Type) where
  abs :: a -> a
```

In this case, `abs` acts as a measure of the &#39;magnitude&#39; of a value, irrespective of its &#39;sign&#39;. The laws in this case would be as follows:

1. For any `x /= zero` and `y, z`, `x * y = x * z` implies `y = z`. This is a rephrasing of the integral domain axiom above.
1. For any `x`, `abs x >= 0`. This assumes an order exists on `a`; we make this explicit with an `Ord a` constraint.
1. `abs x = zero` if and only if `x = zero`.
1. For any `x, y`, `abs (x * y) = abs x * abs y`.
1. For any `x, y`, `abs (x + y) <= abs x + abs y`. This is called the [_triangle inequality_](https://en.wikipedia.org/wiki/Triangle_inequality)_;_ we are subject to the same caveats regarding `Ord` as law 2 above.

Technically, laws 1 and 5 are quite restrictive; they forbid, for example, [Gaussian integers](https://en.wikipedia.org/wiki/Gaussian_integer) from being an instance, even though mathematically, they are indeed integral domains. However, as it is unlikely we&#39;ll work in the complex plane any time soon, we will set this problem aside for now.

This definition of absolute value is &#39;blind&#39; in the sense that we have no information in the type system that the value _must_ be &#39;non-negative&#39; in some sense. We will address this later in this section.

Having this concept, we can now define a notion of &#39;sign function&#39; on that basis. We base this on the [signum function on real numbers relative the absolute value](https://en.wikipedia.org/wiki/Sign_function#Properties); rephrased in Haskell, this states that, for any `x`, `signum x * abs x = x`. Thus, we can introduce a default definition of signum as so:

```haskell
-- Version 2
-- Not actually defined by us, but similar
class (Ord a, Ring a) => IntegralDomain (a :: Type) where
  abs :: a -> a
  signum :: a -> a
  signum x = case compare x zero of 
    EQ -> zero
    LT -> negate one
    GT -> one
```

This is an adequate definition: both `Integer` and `Rational` can be valid instances, based on a function already provided by Plutus (but hard to find). The basis taken by Plutus for absolute value differs slightly from the treatment we&#39;ve provided; instead, they define the following:

```haskell
-- Provided by Plutus in Data.Ratio
abs :: (Ord a, AdditiveGroup a) => a -> a
abs x = if x < zero then negate x else x
```

We decided for our approach above, instead of this, for several reasons:

- Despite its generality, the location of this function is fairly surprising - it&#39;s not technically to do with `Ratio` only, but applies just as well (at least) to `Integer` also.
- A general notion of signum is impossible in this presentation, as `AdditiveGroup` does not give us a multiplicative identity (or even multiplication as such).
- The notion being appealed to here is that of a [_linearly-ordered group_](https://en.wikipedia.org/wiki/Linearly_ordered_group)_;_ thus, the extension being done is of additive groups, not rings. This is a problem, as linearly-ordered groups must be either trivial (one element big) or infinite; we require no such restrictions.
- The issue with &#39;blindness&#39; we described already remains here; our method has a way of resolving it (see below).

Finally, we address the notion of &#39;blindness&#39; in our implementation of absolute value; more precisely, `abs` as defined above does not enshrine the &#39;non-negativity&#39; of its result in the type system. As in Haskell, we want to make [illegal states unrepresentable](https://buttondown.email/hillelwayne/archive/making-illegal-states-unrepresentable/) and [parse, not validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate), this feels a bit unsatisfactory. We would like to have a way to inform the compiler that after we call (possibly a different version) of our absolute value function that the result _cannot_ be &#39;negative&#39;. To do this requires a little more theoretical ground.

Rings (and indeed, `Ring`s) are characterized by the existence of additive inverses; likewise, non-rings (and non-`Ring`s) are characterized by their inability to have such. The two-universe presentation we have given here demonstrates this in one way: we essentially claim these inhabit different universes. However, a more &#39;baseline&#39; mathematical view of this is to state that non-rings are _incomplete_ - for example, `N`is an incomplete version of `Z`, and `Q+` is an incomplete version of `Q`. In this sense, we can see `Z` as &#39;completing&#39; `N` by introducing additive inverses; analogously, we can view `Q` as &#39;completing&#39; `Q+` by introducing additive inverses.

Based on this view, we can extend `IntegralDomain` into a multi-parameter type class, which, in addition to specifying an abstract notion of absolute value, also relates together a type and its &#39;additive completion&#39; (or an &#39;additive restriction&#39; and its extension):

```haskell
-- Version 3
-- Still not quite what we provide, but we're nearly there!
class (Ring a, Ord a) => IntegralDomain a r | a -> r, r -> a where
  abs :: a -> a
  signum :: a -> a
  signum x = case compare x zero of 
    EQ -> zero
    LT -> negate one
    GT -> one
  projectAbs :: a -> r
  addExtend :: r -> a
```

`projectAbs` is an &#39;absolute value projection&#39;: it takes us from a &#39;larger&#39; type `a` into a &#39;smaller&#39; type `r` by &#39;squashing together&#39; values whose absolute value would be the same. `addExtend` on the other hand is an &#39;additive extension&#39;, which &#39;extends&#39; the &#39;smaller&#39; type `r` into the &#39;larger&#39; type `a`. These are governed by the following laws:

1. `projectAbs . addExtend = id`
1. For any `x`, if `abs x = x`, then `addExtend . projectAbs $ x = x`

These laws provide necessary consistency with `abs`, as well as demonstrating that the operations form a (partial) inverse. Our use of functional dependencies in the definition is to ensure good type inference. They&#39;re arguably a little _too_ strict, as they insist on a bijective relationship between `a` and `r` - for now, this is not an issue, at least not for arithmetic.

Lastly, to round out our observations, we note that `a` and `r` are partially isomorphic: in fact, you can form a `Prism` between them. Thus, for completeness, we also provide the `preview` direction of this `Prism`, finally yielding the definition of `IntegralDomain` which we provide:

```haskell
-- What we provide, at last
class (Ring a, Ord a) => IntegralDomain a r | a -> r, r -> a where
  abs :: a -> a
  signum :: a -> a
  signum x = case compare x zero of 
    EQ -> zero
    LT -> negate one
    GT -> one
  projectAbs :: a -> r
  addExtend :: r -> a
  restrictMay :: a -> Maybe r
  restrictMay x
    | x == abs x = Just . projectAbs $ x
    | otherwise = Nothing
```

Naturally, the behaviour of `restrictMay` is governed by a law: for any `x`, `restrictMay x = Just y` if and only if `abs x = x`.

Purescript instead treats `abs` and `signum` as concepts of `Ring`, with the additional requirement of an `Ord` constraint. This could also work, but our solution also allows us to give additional information to the compiler. We also choose to make `signum zero = zero`; this is arguably more in-line with the mathematical sign function.

# The problem of division

The operation of division is the most complex of all the arithmetic operations, for a variety of reasons. Firstly, for two of our types of interest (namely, `Natural` and `Integer`), the operation is not even _defined;_ secondly, even where it _is_ defined, it&#39;s inherently partial, as [division by zero is problematic](https://en.wikipedia.org/wiki/Division_by_zero#Division_as_the_inverse_of_multiplication). While there do exist systems that [can define division by zero](https://en.wikipedia.org/wiki/Projectively_extended_real_line), these do not behave the way we expect algebraically, both in terms of division and also other operations, and come with complications of their own. Resolving these problems in a satisfactory way is complex: we decided for a two-pronged approach. Roughly, we define an analogy of &#39;division-with-remainder&#39; which can be closed, and use this for `Integer` and `Natural`; additionally, we attempt a more &#39;mathematical&#39; treatment of division for what remains, with the acceptance of partiality in the narrowest possible scope.

## Division with remainder

One basis for division we can consider is [_Euclidean division_](https://en.wikipedia.org/wiki/Euclidean_division#Division_theorem)_._ Intuitively, this treats division like repeated subtraction: `x / y` is seen as a combination of:

1. The count of how many times `y` can be subtracted from `x`; and
1. What remains after that.

In this view, division as an operation that produces _two_ results: a _quotient_ (corresponding to 1) and a _remainder_ (corresponding to 2). This, together with the axioms of Euclidean division, suggests an implementation of this form:

```haskell
-- Not actually implemented - just a stepping stone
class (IntegralDomain a) => Euclidean (a :: Type) where
  divMod :: a -> a -> (a, a)
```

Here, `divMod` is &#39;division with remainder&#39;, producing both the quotient and remainder. This would require the following law: for all `x`and `y /= zero`, if `divMod x y = (q, r)`, then `q * y + r = x` and `0 <= r < abs y`.

However, this design is unsatisfying for two reasons:

- Due to the `IntegralDomain` requirement, only `Integer` could be an instance. This seems strange, as the concept of division-with-remainder doesn&#39;t intuitively require a notion of signedness.
- The Euclidean division axioms exclude `y = zero`, making `/` inherently partial.

The main reason these are required mathematically are due to a requirement that division be an &#39;inverse&#39; to multiplication inherently - Euclidean division is designed as a stepping stone to &#39;actual&#39; division, which is viewed as a partial inverse to multiplication generally, and the two _cannot_ disagree. There is no _inherent_ reason why we have to be bound by this as Haskell developers: the two concepts can be viewed as orthogonal. While this approach is somewhat [Procrustean](https://www.schoolofhaskell.com/user/edwardk/editorial/procrustean-mathematics) in nature, we are interested in lawful and useful behaviours that fit within the intuition we have, and the operators we can provide, rather than mathematical theorems in and of themselves.

Thus, we solve this issue by instead defining the following:

```haskell
-- What we actually provide
class (Ord a, Semiring a) => EuclideanClosed (a :: Type) where
  divMod :: a -> a -> (a, a)
```

This presentation requires more laws to constrain its behaviour; specifically, we have to ensure that there is a _unique_ quotient and remainder for any combination of arguments, as well as handling the case of `y = zero`. Thus, we have the following laws:

1. For all `x, y`, if `divMod x y = (q, r)`, then `q * y + r = x`.
1. For all `x`, `divMod x zero = (zero, x)`.
1. For all `x`, `y /= zero`, if `divMod x y = (q, r)`, then `zero <= r < y`; if `a` is an `IntegralDomain`, then `zero <= abs r < abs y` instead.

This allows us to define:

```haskell
-- Defined by us
div :: forall (a :: Type) . 
  (EuclideanClosed a) => a -> a -> a
div x = fst . divMod x

-- Also defined by us
rem :: forall (a :: Type) . 
  (EuclideanClosed a) => a -> a -> a
rem x = snd . divMod x
```

This resolves both issues: we now have closure, and both `Natural` and `Integer` can be lawful instances. For `Natural`, the behaviour is clear; for `Integer`, this acts as a combination of `quotient` and `remainder`.

Purescript instead uses the concept of a [_Euclidean domain_](https://en.wikipedia.org/wiki/Euclidean_domain), and defines a `EuclideanRing type class` to embody it. Our solution is both more general and more total: more general as it does not require `a` to be a commutative ring (or even a ring as such); more total as we define division and remainder by zero. While less &#39;mathematically-grounded&#39;, we consider the increased generality and totality worth the somewhat narrower concept.

## Multiplicative inverses and groups

Mathematically-speaking, the notion of [multiplicative inverse](https://en.wikipedia.org/wiki/Multiplicative_inverse) provides the basis of division. This requires the existence of a _reciprocal_ for every value (except the multiplicative identity). This creates the notion of [_multiplicative group_](https://en.wikipedia.org/wiki/Multiplicative_group)_;_ translated into Haskell, it looks like so:

```haskell
-- Provided by us (plus one more method, see Exponentiation)
class (MultiplicativeMonoid a) => MultiplicativeGroup (a :: Type) where
  {-# MINIMAL (/) | reciprocal #-}
  (/) :: a -> a -> a
  x / y = x * reciprocal y
  reciprocal :: a -> a
  reciprocal x = one / x
```

As expected, this has laws following the axioms of multiplicative groups. In particular, the following laws assume `y /= zero`; we _must_ leave division by zero undefined.

1. If `x / y = z` then `y * z = x`.
1. `x / y = x * reciprocal y`.

This means that both `/` and `reciprocal` are partial functions; while it is desirable to have total division, it is difficult to do without creating mathematical paradoxes or breaking assumptions on the behaviour of either division itself, or the other arithmetic operators. With this caveat, both `Rational` and `NatRatio` can be lawful instances.

Purescript instead follows the concept of a [_skew field_](https://en.wikipedia.org/wiki/Division_ring)_,_ and defines a `DivisionRing type class` to embody it. This is slightly more general than the approach we take: instead of having a _singular_ division operation, it has a left and right division, representing a product with the reciprocal on the left and the right respectively. This has the advantage of being slightly more general. Our definition technically could work the same way, but due to lack of need, we decided not to distinguish left and right division.

This also gives rise to two additional structures. A ring extended with multiplicative inverses is a [_field_](https://en.wikipedia.org/wiki/Field_(mathematics))_:_

```haskell
type Field (a :: Type) = (AdditiveGroup a, MultiplicativeGroup a)
```

In the parallel universe of canonical natural orderings, we can define a similar concept:

```haskell
type Hemifield (a :: Type) = (AdditiveHemigroup a, MultiplicativeGroup a)
```

These require no additional laws beyond the ones required by their respective component instances.

Purescript instead has a [dedicated `Field` type class](https://pursuit.purescript.org/packages/purescript-prelude/5.0.1/docs/Data.Field), which enforces that its multiplicative monoid must be a skew field where right and left division coincide (or, put another way, the multiplicative monoid must also commute).

# Exponentiation

In some sense, we can view multiplication as repeated addition:

```
x * y = x + x + ... + x
        \_____________/         
            y times
```

By a similar analogy, we can view exponentiation as repeated multiplication:

```
x ^ y = x * x * ... * x
        \_____________/
            y times
```

In this presentation, we expect that for any `x`, `x ^ 1 = x`. Since in this case, the exponent is a _count_, and the only required operation is multiplication, we can define a form of exponentiation for any `MultiplicativeMonoid`:

```
-- We define this operation, but not in this way, as it's inefficient.
powNat :: forall (a :: Type) . 
  (MultiplicativeMonoid a) => 
  a -> Natural -> a
powNat x i
  | i == zero = one
  | i == one = x
  | otherwise = x * (powNat x (i ^- 1))
```

The convention that `x ^ 0 = 1` for all `x` is maintained here, replacing the number `1` with the multiplicative monoid identity. This also provides closure.

If we have a `MultiplicativeGroup`, we can also have negative exponents, which are defined with the equivalence `x ^ (negate y) = reciprocal (x ^ y)` (in Haskell terms). We can thus provide a function to perform this operation for any `MultiplicativeGroup`; we instead choose to make it part of the `MultiplicativeGroup` type class, as it allows more efficient implementations to be defined in some cases.

```haskell
-- This is part of MultiplicativeGroup, and is more efficient, in our case
powInteger :: forall (a :: Type) . 
  (MultiplicativeGroup a) =>
  a -> Integer -> a
powInteger x i
  | i == zero = one
  | i == one = x
  | i < zero = reciprocal . powNat x . projectAbs $ i
  | otherwise = powNat x . projectAbs $ i 
```

Both of these presentations are [mathematically-grounded](https://en.wikipedia.org/wiki/Exponentiation#Monoids).
