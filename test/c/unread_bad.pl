%% ARGUMENTS TAKEN UNREAD, REFUSED (0.264): a macro that gives its unread argument back unread, and a text that puts one
%% where it does not read
keep(unread(B), unread(B)).
plus_one(unread(B), E) :- ccl_c_expr("(@b) + 1", [b = unread(B)], E).
