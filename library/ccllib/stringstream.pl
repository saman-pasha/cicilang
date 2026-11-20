%% ccllib's <stringstream.pl> (phase 1d): std::stringstream over a buffer of its own.
%%
%%   #include <stringstream.pl>
%%   stringstream<> s;
%%   s << "abc";  s << 42;  printf("%s\n", str(s));  clear(s);
%%   s << "12 3.5";  s >> a;  s >> b;
%%
%% The type macro takes no argument, as <any.pl>'s does: `stringstream<>'. `str(s)' gives the text as a `char *' tied
%% to the stream, a borrow that a write after it ends, where C++ gives a string (1.6.3); `clear(s)' empties it and puts
%% its state back, `rewind(s)' puts the read place back at the start. A local
%% stringstream is dropped where its scope ends, and its drop frees the buffer.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/iostream_impl)).
type_stringstream([], base([], [typedef(N)]), Items) :-
    ccl_instance_name(stringstream, [], N), ccllib_sstream_type(N, Items).
type_stringstream([T], base([], [typedef(N)]), Items) :-
    ( ccl_arg_words([T], [char]) -> true ; ccl_macro_error('a stringstream''s element is char: the other character types wait') ),
    ccl_instance_name(stringstream, [T], N), ccllib_sstream_type(N, Items).
fn_stringstream(Name, As, Items) :- ( As == [] ; As == [base([], [char])] ), ccl_instance_name(stringstream, As, N),
    ( ccllib_sstream_fn(Name, Text) ; ccllib_sstream_in_fn(Name, Text) ),
    ccl_c_items(Text, ['N' = name(N)], Items).
