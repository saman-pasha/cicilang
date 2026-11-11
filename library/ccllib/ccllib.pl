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
