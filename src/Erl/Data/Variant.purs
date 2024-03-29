module Erl.Data.Variant
  ( Variant
  , inj
  , prj
  , prj'
  , on
  , onMatch
  , case_
  , match
  , default
  , expand
  , contract
  , Unvariant(..)
  , Unvariant'
  , unvariant
  , revariant
  , class VariantEqs
  , variantEqs
  , class VariantOrds
  , variantOrds
  , class VariantShows
  , variantShows
  , class VariantBounded
  , variantBounded
  , class VariantBoundedEnums
  , variantBoundedEnums
  , module Exports
  , class DebugErlVariantRowList
  , debugErlVariantRowList
  ) where

import Prelude

import Control.Alternative (empty, class Alternative)
import Data.Debug (class Debug)
import Data.Debug as D
import Data.Either (Either(..))
import Data.Enum (class Enum, pred, succ, class BoundedEnum, Cardinality(..), fromEnum, toEnum, cardinality)
import Data.List as L
import Data.Maybe (Maybe)
import Data.Symbol (class IsSymbol, reflectSymbol)
import Erl.Atom as ErlAtom
import Erl.Atom.Symbol (Atom, atom, toAtom)
import Erl.Data.Variant.Internal (class Contractable, class VariantMatchCases) as Exports
import Erl.Data.Variant.Internal (class Contractable, class VariantMatchCases, class VariantTags, BoundedDict, BoundedEnumDict, VariantCase, VariantRep(..), contractWith, lookup, lookupCardinality, lookupEq, lookupFirst, lookupFromEnum, lookupLast, lookupOrd, lookupPred, lookupSucc, lookupToEnum, matchImpl, unsafeGet, unsafeHas, variantTags)
import Partial.Unsafe (unsafeCrashWith)
import Prim.Row as R
import Prim.Row as Row
import Prim.RowList (class RowToList, Nil, Cons, RowList)
import Prim.RowList as RL
import Type.Proxy (Proxy(..))
import Unsafe.Coerce (unsafeCoerce)

foreign import data Variant ∷ Row Type → Type

-- | Inject into the variant at a given label.
-- | ```purescript
-- | intAtFoo :: forall r. Variant (foo :: Int | r)
-- | intAtFoo = inj (Proxy :: Proxy "foo") 42
-- | ```
inj
  ∷ ∀ proxy sym a r1 r2
  . R.Cons sym a r1 r2
  ⇒ IsSymbol sym
  ⇒ proxy sym
  → a
  → Variant r2
inj _p value = coerceV $ VariantRep { type: toAtom $ (atom :: Atom sym), value }
  where
  coerceV ∷ VariantRep a → Variant r2
  coerceV = unsafeCoerce

-- | Attempt to read a variant at a given label.
-- | ```purescript
-- | case prj (Proxy :: Proxy "foo") intAtFoo of
-- |   Just i  -> i + 1
-- |   Nothing -> 0
-- | ```
prj
  ∷ ∀ proxy sym a r1 r2 f
  . R.Cons sym a r1 r2
  ⇒ IsSymbol sym
  ⇒ Alternative f
  ⇒ proxy sym
  → Variant r2
  → f a
prj p = on p pure (const empty)

-- | Attempt to read a variant at a given label, returning an either.
prj'
  ∷ ∀ proxy sym a r1 r2
  . R.Cons sym a r1 r2
  ⇒ IsSymbol sym
  ⇒ proxy sym
  → Variant r2
  → Either (Variant r1) a
prj' _p r =
  case coerceV r of
    VariantRep v | v.type == (toAtom $ (atom :: Atom sym)) → Right v.value
    _ → Left (coerceR r)
  where
  coerceV ∷ Variant r2 → VariantRep a
  coerceV = unsafeCoerce

  coerceR ∷ Variant r2 → Variant r1
  coerceR = unsafeCoerce

-- | Attempt to read a variant at a given label by providing branches.
-- | The failure branch receives the provided variant, but with the label
-- | removed.
on
  ∷ ∀ proxy sym a b r1 r2
  . R.Cons sym a r1 r2
  ⇒ IsSymbol sym
  ⇒ proxy sym
  → (a → b)
  → (Variant r1 → b)
  → Variant r2
  → b
on _p f g r =
  case coerceV r of
    VariantRep v | v.type == (toAtom $ (atom :: Atom sym)) → f v.value
    _ → g (coerceR r)
  where
  coerceV ∷ Variant r2 → VariantRep a
  coerceV = unsafeCoerce

  coerceR ∷ Variant r2 → Variant r1
  coerceR = unsafeCoerce

-- | Match a `Variant` with a `Record` containing functions for handling cases.
-- | This is similar to `on`, except instead of providing a single label and
-- | handler, you can provide a record where each field maps to a particular
-- | `Variant` case.
-- |
-- | ```purescript
-- | onMatch
-- |   { foo: \foo -> "Foo: " <> foo
-- |   , bar: \bar -> "Bar: " <> bar
-- |   }
-- | ````
-- |
-- | Polymorphic functions in records (such as `show` or `id`) can lead
-- | to inference issues if not all polymorphic variables are specified
-- | in usage. When in doubt, label methods with specific types, such as
-- | `show :: Int -> String`, or give the whole record an appropriate type.
onMatch
  ∷ ∀ rl r r1 r2 r3 b
  . RL.RowToList r rl
  ⇒ VariantMatchCases rl r1 b
  ⇒ R.Union r1 r2 r3
  ⇒ Record r
  → (Variant r2 → b)
  → Variant r3
  → b
onMatch r k v =
  case coerceV v of
    VariantRep v' | unsafeHas v'.type r → unsafeGet v'.type r v'.value
    _ → k (coerceR v)

  where
  coerceV ∷ ∀ a. Variant r3 → VariantRep a
  coerceV = unsafeCoerce

  coerceR ∷ Variant r3 → Variant r2
  coerceR = unsafeCoerce

-- | Combinator for exhaustive pattern matching.
-- | ```purescript
-- | caseFn :: Variant (foo :: Int, bar :: String, baz :: Boolean) -> String
-- | caseFn = case_
-- |  # on (Proxy :: Proxy "foo") (\foo -> "Foo: " <> show foo)
-- |  # on (Proxy :: Proxy "bar") (\bar -> "Bar: " <> bar)
-- |  # on (Proxy :: Proxy "baz") (\baz -> "Baz: " <> show baz)
-- | ```
case_ ∷ ∀ a. Variant () → a
case_ r =
  unsafeCrashWith case unsafeCoerce r of
    VariantRep v → "Data.Variant: pattern match failure [" <> show v.type <> "]"

-- | Combinator for exhaustive pattern matching using an `onMatch` case record.
-- | ```purescript
-- | matchFn :: Variant (foo :: Int, bar :: String, baz :: Boolean) -> String
-- | matchFn = match
-- |   { foo: \foo -> "Foo: " <> show foo
-- |   , bar: \bar -> "Bar: " <> bar
-- |   , baz: \baz -> "Baz: " <> show baz
-- |   }
-- | ```
match
  ∷ ∀ rl r r1 r2 b
  . RL.RowToList r rl
  ⇒ VariantMatchCases rl r1 b
  ⇒ R.Union r1 () r2
  ⇒ Record r
  → Variant r2
  → b
--match r = case_ # onMatch r
match r v = matchImpl r (coerceV v)
  where
  coerceV ∷ ∀ a. Variant r2 → VariantRep a
  coerceV = unsafeCoerce

-- | Combinator for partial matching with a default value in case of failure.
-- | ```purescript
-- | caseFn :: forall r. Variant (foo :: Int, bar :: String | r) -> String
-- | caseFn = default "No match"
-- |  # on (Proxy :: Proxy "foo") (\foo -> "Foo: " <> show foo)
-- |  # on (Proxy :: Proxy "bar") (\bar -> "Bar: " <> bar)
-- | ```
default ∷ ∀ a r. a → Variant r → a
default a _ = a

-- | Every `Variant lt` can be cast to some `Variant gt` as long as `lt` is a
-- | subset of `gt`.
expand
  ∷ ∀ lt a gt
  . R.Union lt a gt
  ⇒ Variant lt
  → Variant gt
expand = unsafeCoerce

-- | A `Variant gt` can be cast to some `Variant lt`, where `lt` is is a subset
-- | of `gt`, as long as there is proof that the `Variant`'s runtime tag is
-- | within the subset of `lt`.
contract
  ∷ ∀ lt gt f
  . Alternative f
  ⇒ Contractable gt lt
  ⇒ Variant gt
  → f (Variant lt)
contract v =
  contractWith
    (Proxy ∷ Proxy gt)
    (Proxy ∷ Proxy lt)
    (case coerceV v of VariantRep v' → v'.type)
    (coerceR v)
  where
  coerceV ∷ ∀ a. Variant gt → VariantRep a
  coerceV = unsafeCoerce

  coerceR ∷ Variant gt → Variant lt
  coerceR = unsafeCoerce

type Unvariant' r x =
  ∀ proxy s t o
  . IsSymbol s
  ⇒ R.Cons s t o r
  ⇒ proxy s
  → t
  → x

newtype Unvariant r = Unvariant
  (∀ x. Unvariant' r x → x)

-- | A low-level eliminator which reifies the `IsSymbol` and `Cons`
-- | constraints required to reconstruct the Variant. This lets you
-- | work generically with some Variant at runtime.
unvariant
  ∷ ∀ r
  . Variant r
  → Unvariant r
unvariant v = case (unsafeCoerce v ∷ VariantRep Unit) of
  VariantRep o →
    Unvariant \f →
      coerce f { reflectSymbol: const o.type } {} Proxy o.value
  where
  coerce
    ∷ ∀ proxy x
    . Unvariant' r x
    → { reflectSymbol ∷ proxy "" → ErlAtom.Atom }
    → {}
    → proxy ""
    → Unit
    → x
  coerce = unsafeCoerce

-- | Reconstructs a Variant given an Unvariant eliminator.
revariant ∷ ∀ r. Unvariant r -> Variant r
revariant (Unvariant f) = f inj

class VariantEqs :: RL.RowList Type -> Constraint
class VariantEqs rl where
  variantEqs ∷ forall proxy. proxy rl → L.List (VariantCase → VariantCase → Boolean)

instance eqVariantNil ∷ VariantEqs RL.Nil where
  variantEqs _ = L.Nil

instance eqVariantCons ∷ (VariantEqs rs, Eq a) ⇒ VariantEqs (RL.Cons sym a rs) where
  variantEqs _ =
    L.Cons (coerceEq eq) (variantEqs (Proxy ∷ Proxy rs))
    where
    coerceEq ∷ (a → a → Boolean) → VariantCase → VariantCase → Boolean
    coerceEq = unsafeCoerce

instance eqVariant ∷ (RL.RowToList r rl, VariantTags rl, VariantEqs rl) ⇒ Eq (Variant r) where
  eq v1 v2 =
    let
      c1 = unsafeCoerce v1 ∷ VariantRep VariantCase
      c2 = unsafeCoerce v2 ∷ VariantRep VariantCase
      tags = variantTags (Proxy ∷ Proxy rl)
      eqs = variantEqs (Proxy ∷ Proxy rl)
    in
      lookupEq tags eqs c1 c2

class VariantBounded :: RL.RowList Type -> Constraint
class VariantBounded rl where
  variantBounded ∷ forall proxy. proxy rl → L.List (BoundedDict VariantCase)

instance boundedVariantNil ∷ VariantBounded RL.Nil where
  variantBounded _ = L.Nil

instance boundedVariantCons ∷ (VariantBounded rs, Bounded a) ⇒ VariantBounded (RL.Cons sym a rs) where
  variantBounded _ = L.Cons dict (variantBounded (Proxy ∷ Proxy rs))
    where
    dict ∷ BoundedDict VariantCase
    dict =
      { top: coerce top
      , bottom: coerce bottom
      }

    coerce ∷ a → VariantCase
    coerce = unsafeCoerce

instance boundedVariant ∷ (RL.RowToList r rl, VariantTags rl, VariantEqs rl, VariantOrds rl, VariantBounded rl) ⇒ Bounded (Variant r) where
  top =
    let
      tags = variantTags (Proxy ∷ Proxy rl)
      dicts = variantBounded (Proxy ∷ Proxy rl)
      coerce = unsafeCoerce ∷ VariantRep VariantCase → Variant r
    in
      coerce $ VariantRep $ lookupLast (ErlAtom.atom "top") _.top tags dicts
  bottom =
    let
      tags = variantTags (Proxy ∷ Proxy rl)
      dicts = variantBounded (Proxy ∷ Proxy rl)
      coerce = unsafeCoerce ∷ VariantRep VariantCase → Variant r
    in
      coerce $ VariantRep $ lookupFirst (ErlAtom.atom "bottom") _.bottom tags dicts

class VariantBoundedEnums :: RL.RowList Type -> Constraint
class
  VariantBounded rl ⇐
  VariantBoundedEnums rl where
  variantBoundedEnums ∷ forall proxy. proxy rl → L.List (BoundedEnumDict VariantCase)

instance enumVariantNil ∷ VariantBoundedEnums RL.Nil where
  variantBoundedEnums _ = L.Nil

instance enumVariantCons ∷ (VariantBoundedEnums rs, BoundedEnum a) ⇒ VariantBoundedEnums (RL.Cons sym a rs) where
  variantBoundedEnums _ = L.Cons dict (variantBoundedEnums (Proxy ∷ Proxy rs))
    where
    dict ∷ BoundedEnumDict VariantCase
    dict =
      { pred: coerceAToMbA pred
      , succ: coerceAToMbA succ
      , fromEnum: coerceFromEnum fromEnum
      , toEnum: coerceToEnum toEnum
      , cardinality: coerceCardinality cardinality
      }

    coerceAToMbA ∷ (a → Maybe a) → VariantCase → Maybe VariantCase
    coerceAToMbA = unsafeCoerce

    coerceFromEnum ∷ (a → Int) → VariantCase → Int
    coerceFromEnum = unsafeCoerce

    coerceToEnum ∷ (Int → Maybe a) → Int → Maybe VariantCase
    coerceToEnum = unsafeCoerce

    coerceCardinality ∷ Cardinality a → Int
    coerceCardinality = unsafeCoerce

instance enumVariant ∷ (RL.RowToList r rl, VariantTags rl, VariantEqs rl, VariantOrds rl, VariantBoundedEnums rl) ⇒ Enum (Variant r) where
  pred a =
    let
      rep = unsafeCoerce a ∷ VariantRep VariantCase
      tags = variantTags (Proxy ∷ Proxy rl)
      bounds = variantBounded (Proxy ∷ Proxy rl)
      dicts = variantBoundedEnums (Proxy ∷ Proxy rl)
      coerce = unsafeCoerce ∷ Maybe (VariantRep VariantCase) → Maybe (Variant r)
    in
      coerce $ lookupPred rep tags bounds dicts
  succ a =
    let
      rep = unsafeCoerce a ∷ VariantRep VariantCase
      tags = variantTags (Proxy ∷ Proxy rl)
      bounds = variantBounded (Proxy ∷ Proxy rl)
      dicts = variantBoundedEnums (Proxy ∷ Proxy rl)
      coerce = unsafeCoerce ∷ Maybe (VariantRep VariantCase) → Maybe (Variant r)
    in
      coerce $ lookupSucc rep tags bounds dicts

instance boundedEnumVariant ∷ (RL.RowToList r rl, VariantTags rl, VariantEqs rl, VariantOrds rl, VariantBoundedEnums rl) ⇒ BoundedEnum (Variant r) where
  cardinality =
    Cardinality $ lookupCardinality $ variantBoundedEnums (Proxy ∷ Proxy rl)
  fromEnum a =
    let
      rep = unsafeCoerce a ∷ VariantRep VariantCase
      tags = variantTags (Proxy ∷ Proxy rl)
      dicts = variantBoundedEnums (Proxy ∷ Proxy rl)
    in
      lookupFromEnum rep tags dicts
  toEnum n =
    let
      tags = variantTags (Proxy ∷ Proxy rl)
      dicts = variantBoundedEnums (Proxy ∷ Proxy rl)
      coerceV = unsafeCoerce ∷ Maybe (VariantRep VariantCase) → Maybe (Variant r)
    in
      coerceV $ lookupToEnum n tags dicts

class VariantOrds :: RL.RowList Type -> Constraint
class VariantOrds rl where
  variantOrds ∷ forall proxy. proxy rl → L.List (VariantCase → VariantCase → Ordering)

instance ordVariantNil ∷ VariantOrds RL.Nil where
  variantOrds _ = L.Nil

instance ordVariantCons ∷ (VariantOrds rs, Ord a) ⇒ VariantOrds (RL.Cons sym a rs) where
  variantOrds _ =
    L.Cons (coerceOrd compare) (variantOrds (Proxy ∷ Proxy rs))
    where
    coerceOrd ∷ (a → a → Ordering) → VariantCase → VariantCase → Ordering
    coerceOrd = unsafeCoerce

instance ordVariant ∷ (RL.RowToList r rl, VariantTags rl, VariantEqs rl, VariantOrds rl) ⇒ Ord (Variant r) where
  compare v1 v2 =
    let
      c1 = unsafeCoerce v1 ∷ VariantRep VariantCase
      c2 = unsafeCoerce v2 ∷ VariantRep VariantCase
      tags = variantTags (Proxy ∷ Proxy rl)
      ords = variantOrds (Proxy ∷ Proxy rl)
    in
      lookupOrd tags ords c1 c2

class VariantShows :: RL.RowList Type -> Constraint
class VariantShows rl where
  variantShows ∷ forall proxy. proxy rl → L.List (VariantCase → String)

instance showVariantNil ∷ VariantShows RL.Nil where
  variantShows _ = L.Nil

instance showVariantCons ∷ (VariantShows rs, Show a) ⇒ VariantShows (RL.Cons sym a rs) where
  variantShows _ =
    L.Cons (coerceShow show) (variantShows (Proxy ∷ Proxy rs))
    where
    coerceShow ∷ (a → String) → VariantCase → String
    coerceShow = unsafeCoerce

instance showVariant ∷ (RL.RowToList r rl, VariantTags rl, VariantShows rl) ⇒ Show (Variant r) where
  show v1 =
    let
      VariantRep v = unsafeCoerce v1 ∷ VariantRep VariantCase
      tags = variantTags (Proxy ∷ Proxy rl)
      shows = variantShows (Proxy ∷ Proxy rl)
      body = lookup (ErlAtom.atom "show") v.type tags shows v.value
    in
      "(inj @" <> show v.type <> " " <> body <> ")"

-- | This class is part of the machinery for the `Debug (ErlVariant.Variant r)` instance;
-- | it is not intended to be used directly.
class DebugErlVariantRowList :: RowList Type -> Row Type -> Constraint
class DebugErlVariantRowList rl r | rl -> r where
  debugErlVariantRowList :: Proxy rl -> Variant r -> D.Repr

instance debugErlVariantRowListNil :: DebugErlVariantRowList Nil () where
  debugErlVariantRowList _ = case_

instance debugErlVariantRowListCons ::
  ( DebugErlVariantRowList tailRL rowTail
  , IsSymbol sym
  , Row.Cons sym item rowTail row
  , Debug item
  ) =>
  DebugErlVariantRowList (Cons sym item tailRL) row where
  debugErlVariantRowList _ variant = do
    let
      fn item = D.prop (ErlAtom.atom $ reflectSymbol (Proxy :: _ sym)) $ D.debug item
      recurse = debugErlVariantRowList (Proxy :: _ tailRL)
    on (Proxy :: _ sym) fn recurse variant

instance
  ( RowToList row list
  , DebugErlVariantRowList list row
  ) =>
  Debug (Variant row) where
  debug r =
    debugErlVariantRowList prx r
    where
    prx = Proxy :: Proxy list
