{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "erl-variant"
, dependencies =
  [ "debugged"
  , "either"
  , "erl-atom"
  , "foldable-traversable"
  , "maybe"
  , "partial"
  , "prelude"
  , "unsafe-coerce"
  , "control"
  , "enums"
  , "lists"
  , "type-equality"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
, backend = "purerl"
}
