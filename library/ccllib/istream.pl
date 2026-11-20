%% ccllib's <istream.pl> (phase 1d): std::istream over C's stdio. `cin' is declared by <iostream.pl>.
%%
%%   #include <istream.pl>
%%   istream<char> i;                 reads from stdin until it is given a file
%%   i >> x;  i >> d;  n := get(i);  getline(i, buf, 64);  read(i, buf, 16);  eof(i);  good(i);
%%
%% `>>' is the reader's operator over an instance: the right operand is taken by its address, and the function is named
%% with its word, `_read_int', `_read_double', `_read_char'. It gives the stream, tied to it, so `i >> a >> b' chains,
%% or a null pointer where it found no value, so `while (i >> x)' ends where the input does; the stream is then failed,
%% and a read after it reads nothing until clear(i), as C++'s sentry (1.6.3). A character is read after the white
%% space before it, as C++'s skipws.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/iostream_impl)).
type_istream([T], base([], [typedef(N)]), Items) :-
    ( ccl_arg_words([T], [char]) -> true ; ccl_macro_error('an istream''s element is char: the other character types wait') ),
    ccl_instance_name(istream, [T], N), ccllib_stream_type(N, Items).
fn_istream(Name, [T], Items) :- ccl_instance_name(istream, [T], N), D = expr(call(id(ccllib_stdin), [])),
    ( ccllib_stream_common_fn(Name, D, Text) ; ccllib_stream_in_fn(Name, D, Text) ),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T), 'D' = D], Items).
