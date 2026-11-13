%% A C TEXT WHOSE FUNCTIONS CALL ONE ANOTHER IN ANY ORDER (1.1.2): the names that a macro's text uses are no uses of the
%% program's file, which may not call a function before a declaration of it (the reader's notes take no C text's,
%% ccl_use_quiet/1). scaled_pair(K); at file scope: two functions, the first calling the second, which scales by K
scaled_pair(K, Items) :-
    ccl_c_items("static int textorder_first(int x) { return textorder_second(x) + 1; }
static int textorder_second(int x) { return x * @k; }", [k = expr(K)], Items).
