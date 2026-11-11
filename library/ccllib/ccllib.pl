%% what ccllib's macro files share (0.275; CCLLIB.md's phase 1). A module loads this file by a directive,
%% `:- ensure_loaded(library(ccllib/ccllib)).', so a predicate that two modules need is written once, here: the flow
%% gate refuses a predicate in two files. No program includes this file.
%%
%% AN ELEMENT IS A VALUE WITH NO POINTER IN IT (CCLLIB.md's open decision 2): a container refuses another where its
%% type is written. What is the head of the message, `a vector''s element'
ccllib_plain_element(What, T) :-
    (   ccl_holds_pointer(T)
    ->  ccl_arg_words([T], [W]),
        atomic_list_concat([What, ' is a value with no pointer in it, and ', W, ' holds one'], M), ccl_macro_error(M)
    ;   true ).

%% A MERGE SORT BY THE LINKS OF AN ARENA'S NODES (<list.pl>, <forward_list.pl>): the text of `@{N}__NAME', which sorts
%% the n nodes from the place p on by their `next' and gives the run's first node, the node after the run in *rest. No
%% element moves, each keeps its place, and equal elements keep their order. Param and Arg are the comparison's
%% parameter and argument (`, int (*lt)(@T, @T)' and `, lt', or nothing), Lt is `the element at b comes before the one
%% at a'
ccllib_msort_text(Name, Param, Arg, Lt, Text) :-
    append(["static size_t @{N}__", Name, "(@N *v, size_t p, size_t n, size_t *rest", Param, ") {
    size_t a, b, q, h = 0, t = 0;
    if (n == 1) { *rest = v->data[p - 1].next; v->data[p - 1].next = 0; return p; }
    a = @{N}__", Name, "(v, p, n / 2, &q", Arg, ");
    b = @{N}__", Name, "(v, q, n - n / 2, rest", Arg, ");
    while (a && b) {
        size_t e;
        if (", Lt, ") { e = b; b = v->data[b - 1].next; }
        else { e = a; a = v->data[a - 1].next; }
        if (t) v->data[t - 1].next = e; else h = e;
        t = e;
    }
    v->data[t - 1].next = a ? a : b;
    return h;
}"], Text).

%% A TEXT THAT A FEW CONTAINERS SHARE (0.283; the tree of <set.pl> and <map.pl>, the table of the unordered ones): a
%% list of lines, where a line with a condition is kept where the condition holds -- `multi-"..."' where `multi' is one
%% of Holds, `multi+map-"..."' where both are; the lines that are kept are joined, each with its end.
%% ccllib_text_lines(+Holds, +Lines, -Text)
ccllib_text_lines(_, [], []).
ccllib_text_lines(H, [L|Ls], Text) :-
    (   L = C-Codes -> ( ccllib_text_holds(C, H) -> Line = Codes ; Line = none ) ; Line = L ),
    ccllib_text_lines(H, Ls, Rest),
    (   Line == none -> Text = Rest ; append(Line, [10|Rest], Text) ).
ccllib_text_holds(A+B, H) :- !, ccllib_text_holds(A, H), ccllib_text_holds(B, H).
ccllib_text_holds(C, H) :- memberchk(C, H).
