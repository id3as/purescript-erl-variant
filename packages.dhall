let upstream =
      https://github.com/purerl/package-sets/releases/download/erl-0.15.3-20220629/packages.dhall sha256:48ee9f3558c00e234eae6b8f23b4b8b66eb9715c7f2154864e1e425042a0723b

in  upstream
  with debugged =
       { repo = "https://github.com/id3as/purescript-debugged"
       , version = "f844c7bf711be81cc0d6ac57f251db56354c2b85"
       , dependencies =
         [ "arrays"
         , "bifunctors"
         , "console"
         , "datetime"
         , "debug"
         , "effect"
         , "either"
         , "enums"
         , "erl-atom"
         , "erl-binary"
         , "erl-lists"
         , "erl-maps"
         , "erl-process"
         , "erl-tuples"
         , "foldable-traversable"
         , "foreign"
         , "lists"
         , "maybe"
         , "newtype"
         , "numbers"
         , "ordered-collections"
         , "partial"
         , "prelude"
         , "record"
         , "strings"
         , "tuples"
         , "variant"
         ]
       }
