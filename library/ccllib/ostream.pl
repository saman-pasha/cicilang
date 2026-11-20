%% ccllib's <ostream.pl> (phase 1d): std::ostream over C's stdio, for cicilang's C and for cicilang++ beside libc++'s.
%%
%%   #include <ostream.pl>
%%   ostream<char> o;                 writes to stdout until it is given a file
%%   o << "text";  o << 42;  o << 3.5;  o << endl;
%%   setw(o, 6);  setfill(o, '0');  hex(o);  setprecision(o, 3);  boolalpha(o);
%%   put(o, 'x');  flush(o);  good(o);
%%
%% The instance is a value with no drop: its `FILE *f' is a file that it does not own, and a function that takes it
%% by value copies it. `<<' is the reader's operator over an instance: the function named with the right operand's
%% word, `_write_int', `_write_double', `_write_ptr_char', `_write_ptr_const_char', `_write_bool', `_write_size_t'; a name that the
%% instance has not is refused by name. Each gives the stream, tied to it, so `o << x << y' is two calls, the second on
%% the stream that the first gave (1.6.3). The state -- the integer's base, the floating format, boolalpha, the width,
%% the fill and the precision -- belongs to the stream, as C++'s does, and <iomanip>'s manipulators are functions of it
%% here, `setw(o, 6)', since C has no `<<' that takes one. `endl' is a value of a type of its own, whose write is the
%% end of a line and a flush, as C++'s (1.6.3). What differs from C++:
%%   in C a character literal is an int, so `o << 'x'' writes its number; put(o, 'x') writes the character;
%%   a pointer is written by write_ptr_void only where a program names a void pointer; there is no operator for any
%%     other pointer's word.
:- ensure_loaded(library(ccllib/ccllib)).
:- ensure_loaded(library(ccllib/iostream_impl)).
type_ostream([T], base([], [typedef(N)]), Items) :-
    ( ccl_arg_words([T], [char]) -> true ; ccl_macro_error('an ostream''s element is char: the other character types wait') ),
    ccl_instance_name(ostream, [T], N), ccllib_stream_type(N, Items).
fn_ostream(Name, [T], Items) :- ccl_instance_name(ostream, [T], N), D = expr(call(id(ccllib_stdout), [])),
    ( ccllib_stream_common_fn(Name, D, Text) ; ccllib_stream_out_fn(Name, D, Text) ),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T), 'D' = D], Items).

%% std::cerr: the same stream with stderr for its file
type_cerrstream([], base([], [typedef(N)]), Items) :-
    ccl_instance_name(cerrstream, [], N), ccllib_stream_type(N, Items).
fn_cerrstream(Name, [], Items) :- ccl_instance_name(cerrstream, [], N), D = expr(call(id(ccllib_stderr), [])),
    ( ccllib_stream_common_fn(Name, D, Text) ; ccllib_stream_out_fn(Name, D, Text) ),
    ccl_c_items(Text, ['N' = name(N), 'D' = D], Items).
