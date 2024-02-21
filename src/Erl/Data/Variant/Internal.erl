-module(erl_data_variant_internal@foreign).

-export([ matchImpl/2
        , unsafeGet/2
        , unsafeHas/2
        ]).

matchImpl(Fns, #{type := Type, value := Value}) ->
    Fn = maps:get(Type, Fns),
    Fn(Value).

unsafeHas(Label, Rec) -> maps:is_key(Label, Rec).

unsafeGet(Label, Rec) -> maps:get(Label, Rec).
