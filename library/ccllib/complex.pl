%% ccllib's <complex.pl> (phase 1c): C++'s std::complex<T> as a value struct of a real and an imaginary part, for
%% cicilang's C and for cicilang++ beside libc++'s. The type macro is `complex<T>', the functions are std::complex's:
%% real(z), imag(z), abs(z), arg(z), norm(z), conj(z), exp(z), log(z), sqrt(z), pow(z, n), sin(z), cos(z), tan(z);
%% `z + w', `z - w', `z * w', `z / w', `-z' and `z == w' are the instance's own functions. `complex<T> z = {1, 2};'
%% makes one; a complex is a value with no pointer and no drop.
:- ensure_loaded(library(ccllib/ccllib)).
type_complex([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(complex, [T], N), ccllib_plain_element('a complex''s part', T),
    ccl_c_items("typedef struct @N { @T re, im; } @N;", ['N' = name(N), 'T' = type(T)], Items).
fn_complex(Name, [T], Items) :- ccl_instance_name(complex, [T], N),
    ccllib_complex_fn(Name, T, Text),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).

ccllib_complex_fn(real, _, "@T @{N}_real(const @N *z) { return z->re; }").
ccllib_complex_fn(imag, _, "@T @{N}_imag(const @N *z) { return z->im; }").
ccllib_complex_fn(abs, _, "@T @{N}_abs(const @N *z) { return (@T)hypot((double)z->re, (double)z->im); }").
ccllib_complex_fn(arg, _, "@T @{N}_arg(const @N *z) { return (@T)atan2((double)z->im, (double)z->re); }").
ccllib_complex_fn(norm, _, "@T @{N}_norm(const @N *z) { return z->re * z->re + z->im * z->im; }").
ccllib_complex_fn(conj, _, "@N @{N}_conj(const @N *z) { return (@N){ z->re, -z->im }; }").
ccllib_complex_fn(exp, _, "@N @{N}_exp(const @N *z) { @T e = (@T)exp((double)z->re); return (@N){ e * (@T)cos((double)z->im), e * (@T)sin((double)z->im) }; }").
ccllib_complex_fn(log, _, "@N @{N}_log(const @N *z) { return (@N){ (@T)log((double)hypot((double)z->re, (double)z->im)), (@T)atan2((double)z->im, (double)z->re) }; }").
ccllib_complex_fn(sqrt, _, "@N @{N}_sqrt(const @N *z) { @T r = (@T)sqrt((double)hypot((double)z->re, (double)z->im)), a = (@T)atan2((double)z->im, (double)z->re) / 2; return (@N){ r * (@T)cos((double)a), r * (@T)sin((double)a) }; }").
ccllib_complex_fn(sin, _, "@N @{N}_sin(const @N *z) { return (@N){ (@T)sin((double)z->re) * (@T)cosh((double)z->im), (@T)cos((double)z->re) * (@T)sinh((double)z->im) }; }").
ccllib_complex_fn(cos, _, "@N @{N}_cos(const @N *z) { return (@N){ (@T)cos((double)z->re) * (@T)cosh((double)z->im), -(@T)sin((double)z->re) * (@T)sinh((double)z->im) }; }").
ccllib_complex_fn(tan, _, "@N @{N}_tan(const @N *z) { @N s = @{N}_sin(z), c = @{N}_cos(z); return @{N}_div(&s, &c); }").
ccllib_complex_fn(pow, _, "@N @{N}_pow(const @N *z, int n) { @N r = { 1, 0 }; int neg = n < 0; if (neg) n = -n; for (int i = 0; i < n; i++) r = @{N}_mul(&r, z); if (!neg) return r; @N one = { 1, 0 }; return @{N}_div(&one, &r); }").
ccllib_complex_fn(add, _, "@N @{N}_add(const @N *a, const @N *b) { return (@N){ a->re + b->re, a->im + b->im }; }").
ccllib_complex_fn(sub, _, "@N @{N}_sub(const @N *a, const @N *b) { return (@N){ a->re - b->re, a->im - b->im }; }").
ccllib_complex_fn(mul, _, "@N @{N}_mul(const @N *a, const @N *b) { return (@N){ a->re * b->re - a->im * b->im, a->re * b->im + a->im * b->re }; }").
ccllib_complex_fn(div, _, "@N @{N}_div(const @N *a, const @N *b) { @T d = b->re * b->re + b->im * b->im; return (@N){ (a->re * b->re + a->im * b->im) / d, (a->im * b->re - a->re * b->im) / d }; }").
ccllib_complex_fn(neg, _, "@N @{N}_neg(const @N *a) { return (@N){ -a->re, -a->im }; }").
ccllib_complex_fn(eq, _, "int @{N}_eq(const @N *a, const @N *b) { return a->re == b->re && a->im == b->im; }").
ccllib_complex_fn(ne, _, "int @{N}_ne(const @N *a, const @N *b) { return !(@{N}_eq(a, b)); }").
