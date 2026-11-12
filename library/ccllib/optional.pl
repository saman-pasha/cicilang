%% ccllib's <optional.pl> (0.300; CCLLIB.md's phase 1b): std::optional for cicilang's C, and for cicilang++ beside
%% libc++'s.
%%
%%   #include <optional.pl>
%%   optional<int> o;                no value: an instance's object is born zero (0.285)
%%   optional<int> p = 5;  o = 7;  o = nullopt;           of a value, and of nullopt, by the type's _of
%%   if (has_value(o)) x = value(o);  y = value_or(o, 3);  reset(o);  *emplace(o, 4) += 1;
%%   if (o == p || o < 5 || nullopt < o) swap(o, p);
%%
%% type_optional/3 gives the instance's type, `optional_int', a struct of the value and a byte that says that the value
%% is there: a value with no heap and no drop, so `q := o' and `f(o)' copy, as std::optional's do. fn_optional/3 gives
%% ONE function of the instance at its first use, a call's or an operator's. The names are std::optional's. What
%% differs from C++:
%%   the value is a value with no pointer in it (CCLLIB.md's open decision 2), and no array and no nullopt_t, as in C++;
%%   value(o) stops the program (abort) where o has no value, where C++ throws bad_optional_access;
%%   `*o', `o->m' and `if (o)' have no form in C: value(o), the place that emplace gives back, and has_value(o);
%%   a relation with a value takes a value of the optional's own type -- `o == 5' over an optional<int>, `o == 5.0'
%%     over an optional<double>, where `o == 5' is refused by name, an operand of another type;
%%   an optional is made of a value by `=' and of its own type alone: there is no make_optional, whose argument names
%%     no instance, no in_place, and no optional<double> made of an optional<int>;
%%   and_then, transform and or_else are C++23's (phase 3), and hash comes with phase 1b's hash.
:- ensure_loaded(library(ccllib/ccllib)).
type_optional([T], base([], [typedef(N)]), Items) :- !,
    ccllib_plain_element('an optional''s value', T),
    ( catch(ccl_resolve_type(T, arr(_, _)), _, fail) -> ccl_macro_error('an optional''s value is no array') ; true ),
    ( catch(ccl_type_word(T, nullopt_t), _, fail) -> ccl_macro_error('an optional''s value is no nullopt_t') ; true ),
    ccllib_optional_holes(T, N, Hs), ccl_c_items("typedef struct @N { @T value; unsigned char has; } @N;", Hs, Items).
type_optional(_, _, _) :- ccl_macro_error('an optional takes one type, its value''s').
fn_optional(Name, [T], Items) :-
    ccllib_optional_key(Name, T, Key), ccllib_optional_fn(Key, Text), ccllib_optional_holes(T, _, Hs),
    ccl_c_items(Text, Hs, Items).
%% the holes of a text: @N the instance's name, @T the value's type, @w the word of the value's type
ccllib_optional_holes(T, N, ['N' = name(N), 'T' = type(T), w = name(W)]) :-
    ccl_instance_name(optional, [T], N), ccl_type_word(T, W).
%% a function's key in the table by its name: a relation with a value of the optional's own type is named with the word
%% of that type (`eq_int' over an optional<int>, the operators' typed names, 0.284 and 0.291), and is the table's
%% `eq_value'; every other name is its own key
ccllib_optional_key(Name, T, Key) :-
    (   member(Op, [eq, lt, gt, le, ge]), catch(ccl_type_word(T, W), _, fail), W \== nullopt_t,
        atomic_list_concat([Op, '_', W], Name)
    ->  atom_concat(Op, '_value', Key)
    ;   Key = Name ).
%% a function's C text by its key. A relation follows C++'s ([optional.relops], [optional.nullops],
%% [optional.comp.with.t]): an optional with no value is equal to another with none and to nullopt, and less than one
%% with a value and than any value; `<' of two values goes by the values' `<'
ccllib_optional_fn(of, "@N @{N}_of(@T x) {
    @N v = {0};
    v.value = x;
    v.has = 1;
    return v;
}").
ccllib_optional_fn(of_nullopt_t, "@N @{N}_of_nullopt_t(nullopt_t n) {
    @N v = {0};
    (void)n;
    return v;
}").
ccllib_optional_fn(has_value, "int @{N}_has_value(const @N *v) { return v->has; }").
ccllib_optional_fn(value, "@T @{N}_value(const @N *v) {
    if (!v->has) abort();
    return v->value;
}").
ccllib_optional_fn(value_or, "@T @{N}_value_or(const @N *v, @T d) { return v->has ? v->value : d; }").
ccllib_optional_fn(reset, "void @{N}_reset(@N *v) { v->has = 0; }").
ccllib_optional_fn(emplace, "@T *@{N}_emplace(@N *v, @T x) tie v {
    v->value = x;
    v->has = 1;
    return &v->value;
}").
ccllib_optional_fn(swap, "void @{N}_swap(@N *a, @N *b) { @N t = *a; *a = *b; *b = t; }").
ccllib_optional_fn(eq, "int @{N}_eq(const @N *a, const @N *b) {
    if (a->has != b->has) return 0;
    return !a->has || a->value == b->value;
}").
ccllib_optional_fn(lt, "int @{N}_lt(const @N *a, const @N *b) {
    if (!b->has) return 0;
    return !a->has || a->value < b->value;
}").
ccllib_optional_fn(eq_value, "int @{N}_eq_@w(const @N *a, @T x) { return a->has && a->value == x; }").
ccllib_optional_fn(lt_value, "int @{N}_lt_@w(const @N *a, @T x) { return !a->has || a->value < x; }").
ccllib_optional_fn(gt_value, "int @{N}_gt_@w(const @N *a, @T x) { return a->has && x < a->value; }").
ccllib_optional_fn(eq_nullopt_t, "int @{N}_eq_nullopt_t(const @N *a, nullopt_t n) { (void)n; return !a->has; }").
ccllib_optional_fn(lt_nullopt_t, "int @{N}_lt_nullopt_t(const @N *a, nullopt_t n) { (void)a; (void)n; return 0; }").
ccllib_optional_fn(gt_nullopt_t, "int @{N}_gt_nullopt_t(const @N *a, nullopt_t n) { (void)n; return a->has; }").
%% `<=' AND `>=' BY THE STANDARD'S OWN WORDS (0.304; [optional.relops], [optional.comp.with.t], [optional.nullops]): by
%% the values' own `<=' and `>=', where the negations of `>' and `<' were true over a NaN: `x <= y' is true where x has
%% no value, false where y has none, else `*x <= *y'; `o <= v' is `*o <= v' or true; `o <= nullopt' is `!o', and `o >=
%% nullopt' is true. With the optional on the right the reader asks the other one, `v <= o' as `o >= v'
ccllib_optional_fn(le, "int @{N}_le(const @N *a, const @N *b) {
    if (!a->has) return 1;
    return b->has && a->value <= b->value;
}").
ccllib_optional_fn(ge, "int @{N}_ge(const @N *a, const @N *b) {
    if (!b->has) return 1;
    return a->has && a->value >= b->value;
}").
ccllib_optional_fn(le_value, "int @{N}_le_@w(const @N *a, @T x) { return !a->has || a->value <= x; }").
ccllib_optional_fn(ge_value, "int @{N}_ge_@w(const @N *a, @T x) { return a->has && a->value >= x; }").
ccllib_optional_fn(le_nullopt_t, "int @{N}_le_nullopt_t(const @N *a, nullopt_t n) { (void)n; return !a->has; }").
ccllib_optional_fn(ge_nullopt_t, "int @{N}_ge_nullopt_t(const @N *a, nullopt_t n) { (void)a; (void)n; return 1; }").
