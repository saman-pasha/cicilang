%% OPERATORS WHOSE LEFT OPERAND IS NO INSTANCE (0.291): tag<T>, a text of up to 15 characters in its object, no heap
%% and no drop. Its relations take a text of C on their right -- `_eq_ptr_const_char', `_lt_...', `_gt_...' -- and the
%% reader writes `"abc" == t' and `"abd" > t' over them with the operands exchanged; `_radd_ptr_const_char' and
%% `_radd_int' (C's character constant) and `_radd_char' (C++'s) take a text or a character on the left of `+', and
%% `_add_ptr_const_char' a text on its right
type_tag([T], base([], [typedef(N)]), Items) :- ccl_instance_name(tag, [T], N),
    ccl_c_items("typedef struct @N { char s[16]; } @N;
@N @{N}_of_ptr_const_char(const char *p) { @N r = {{0}}; strncpy(r.s, p, 15); return r; }
int @{N}_eq_ptr_const_char(const @N *a, const char *p) { return strcmp(a->s, p) == 0; }
int @{N}_lt_ptr_const_char(const @N *a, const char *p) { return strcmp(a->s, p) < 0; }
int @{N}_gt_ptr_const_char(const @N *a, const char *p) { return strcmp(a->s, p) > 0; }
@N @{N}_add_ptr_const_char(const @N *a, const char *p) {
    @N r = *a;
    strncat(r.s, p, 15 - strlen(r.s));
    return r;
}
@N @{N}_radd_ptr_const_char(const char *p, const @N *b) {
    @N r = {{0}};
    strncpy(r.s, p, 15);
    strncat(r.s, b->s, 15 - strlen(r.s));
    return r;
}
@N @{N}_radd_int(int c, const @N *b) {
    @N r = {{0}};
    r.s[0] = (char)c;
    strncat(r.s, b->s, 14);
    return r;
}
@N @{N}_radd_char(char c, const @N *b) { return @{N}_radd_int(c, b); }", ['N' = name(N)], Items).
