%% OPERATORS ON INSTANCES, PART 2 (0.284): the forms that 0.266 left -- `% & | ^', the unary `-' and `~', the compound
%% assignments, a function named with the word of its right operand's type, a shift by a number, and `[]' as a value.
%% bits<K>: K bits in one word, 64 at most. `& | ^ ~ << >>' by value, their assignments in the object's place; b[i]
%% is a bit's VALUE, which has no address, and b[i] = x writes the bit
type_bits([int(K)], base([], [typedef(N)]), Items) :- ccl_instance_name(bits, [K], N), atom_number(KA, K),
    ccl_c_items("typedef struct @N { unsigned long long w; } @N;
static unsigned long long @{N}__mask(void) { return @k >= 64 ? ~0ULL : (1ULL << @k) - 1; }
@N @{N}_and(@N a, @N b) { @N r = { a.w & b.w }; return r; }
@N @{N}_or(@N a, @N b) { @N r = { a.w | b.w }; return r; }
@N @{N}_xor(@N a, @N b) { @N r = { a.w ^ b.w }; return r; }
@N @{N}_compl(@N a) { @N r = { ~a.w & @{N}__mask() }; return r; }
@N @{N}_shl(@N a, size_t n) { @N r = { n >= 64 ? 0 : (a.w << n) & @{N}__mask() }; return r; }
@N @{N}_shr(@N a, size_t n) { @N r = { n >= 64 ? 0 : a.w >> n }; return r; }
int @{N}_eq(const @N *a, const @N *b) { return a->w == b->w; }
void @{N}_and_assign(@N *a, @N b) { a->w &= b.w; }
void @{N}_or_assign(@N *a, @N b) { a->w |= b.w; }
void @{N}_xor_assign(@N *a, @N b) { a->w ^= b.w; }
void @{N}_shl_assign(@N *a, size_t n) { a->w = n >= 64 ? 0 : (a->w << n) & @{N}__mask(); }
void @{N}_shr_assign(@N *a, size_t n) { a->w = n >= 64 ? 0 : a->w >> n; }
int @{N}_item(const @N *a, size_t i) { return (int)(a->w >> i & 1); }
void @{N}_set_item(@N *a, size_t i, int x) { if (x) a->w |= 1ULL << i; else a->w &= ~(1ULL << i); }",
        ['N' = name(N), k = name(KA)], Items).
%% num<T>: a number in a struct. `+' and `==' take a num, and an int too: the function named with the word of the
%% right operand's type goes first (`_add_int', `_eq_int', `_add_assign_int'). Its functions are made at their first
%% use, an operator's as a call's (fn_num/3): num<double> never asks for `%', which a double has not
type_num([T], base([], [typedef(N)]), Items) :- ccl_instance_name(num, [T], N),
    ccl_c_items("typedef struct @N { @T v; } @N;", ['N' = name(N), 'T' = type(T)], Items).
fn_num(Name, [T], Items) :- num_fn(Name, Text), ccl_instance_name(num, [T], N),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
num_fn(add, "@N @{N}_add(@N a, @N b) { @N r = { a.v + b.v }; return r; }").
num_fn(add_int, "@N @{N}_add_int(@N a, int k) { @N r = { a.v + k }; return r; }").
num_fn(mod, "@N @{N}_mod(@N a, @N b) { @N r = { a.v % b.v }; return r; }").
num_fn(neg, "@N @{N}_neg(@N a) { @N r = { -a.v }; return r; }").
num_fn(eq, "int @{N}_eq(const @N *a, const @N *b) { return a->v == b->v; }").
num_fn(eq_int, "int @{N}_eq_int(const @N *a, int k) { return a->v == k; }").
num_fn(add_assign, "void @{N}_add_assign(@N *a, @N b) { a->v += b.v; }").
num_fn(add_assign_int, "void @{N}_add_assign_int(@N *a, int k) { a->v += k; }").
num_fn(sub_assign, "void @{N}_sub_assign(@N *a, @N b) { a->v -= b.v; }").
num_fn(mul_assign, "void @{N}_mul_assign(@N *a, @N b) { a->v *= b.v; }").
num_fn(div_assign, "void @{N}_div_assign(@N *a, @N b) { a->v /= b.v; }").
num_fn(mod_assign, "void @{N}_mod_assign(@N *a, @N b) { a->v %= b.v; }").
%% peek<K>: a word whose bits are read by [] and written by no operator
type_peek([int(K)], base([], [typedef(N)]), Items) :- ccl_instance_name(peek, [K], N),
    ccl_c_items("typedef struct @N { unsigned w; } @N;
int @{N}_item(const @N *a, size_t i) { return (int)(a->w >> i & 1); }", ['N' = name(N)], Items).
