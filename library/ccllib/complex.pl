%% ccllib's <complex.pl> (phase 1c): C++'s std::complex<T> as a value struct of a real and an imaginary part, for
%% cicilang's C and for cicilang++ beside libc++'s. The type macro is `complex<T>', the functions are std::complex's:
%% real(z), imag(z), abs(z), arg(z), norm(z), conj(z), exp(z), log(z), sqrt(z), pow(z, y), sin(z), cos(z), tan(z);
%% `z + w', `z - w', `z * w', `z / w', `-z' and `z == w' are the instance's own functions. `complex<T> z = {1, 2};'
%% makes one; a complex is a value with no pointer and no drop.
%%
%% THE VALUES ARE LIBC++'S (1.6.4): a product and a quotient are C's own of `T _Complex', the runtime's __muldc3 and
%% __divdc3 (__mulsc3, __divsc3 of a float, __mulxc3, __divxc3 of a long double), as libc++ 22's operators are the
%% compiler's -- Annex G's, which scale a quotient and recover the infinities that the textbook formulas make NaNs
%% (through 1.6.3 a quotient by 1e300 + 1e300i was NaN, (cc + dd) past the type's range, and one by zero NaN where Annex
%% G gives an infinity); each other function is
%% libc++'s formula, with the part type's own functions (expf for a float, expl for a long double: through 1.6.3 each went
%% through double), sin, cos and tan through sinh, cosh and tanh of (-im, re), and pow(z, y) is exp(y log z), where it
%% was a loop of products of an int's count. The part is float, double or long double, as C++ specifies
%% ([complex.numbers]/2); another type is refused by name. What differs from C++: pow(z, y) computes in the part's type,
%% where C++ promotes a complex<float> and an integer y to complex<double>.
:- ensure_loaded(library(ccllib/ccllib)).
type_complex([T], base([], [typedef(N)]), Items) :-
    ccl_instance_name(complex, [T], N), ccllib_complex_sfx(T, _),
    ccl_c_items("typedef struct @N { @T re, im; } @N;", ['N' = name(N), 'T' = type(T)], Items).
fn_complex(Name, [T], Items) :- ccl_instance_name(complex, [T], N), ccllib_complex_sfx(T, S), ccllib_complex_word(S, W),
    ccllib_complex_fn(Name, Text0), atom_codes(A0, Text0), atomic_list_concat(Ps, '$', A0), atomic_list_concat(Ps, S, A1),
    atomic_list_concat(Qs, '@T _Complex', A1), atomic_list_concat(Qs, W, Text),
    ccl_c_items(Text, ['N' = name(N), 'T' = type(T)], Items).
%% C's complex type of the part, by its words: a hole's type before `_Complex' is no type that the reader takes
ccllib_complex_word(f, 'float _Complex').
ccllib_complex_word('', 'double _Complex').
ccllib_complex_word(l, 'long double _Complex').
%% the suffix of the part type's math functions: expf, exp, expl
ccllib_complex_sfx(T, S) :- catch(ccl_resolve_type(T, base(_, W)), _, fail), msort(W, M),
    ( M == [float] -> S = f ; M == [double] -> S = '' ; M == [double, long] -> S = l ), !.
ccllib_complex_sfx(_, _) :- ccl_macro_error('a complex''s part is float, double or long double, as C++ specifies').

ccllib_complex_fn(real, "@T @{N}_real(const @N *z) { return z->re; }").
ccllib_complex_fn(imag, "@T @{N}_imag(const @N *z) { return z->im; }").
ccllib_complex_fn(abs, "@T @{N}_abs(const @N *z) { return hypot$(z->re, z->im); }").
ccllib_complex_fn(arg, "@T @{N}_arg(const @N *z) { return atan2$(z->im, z->re); }").
ccllib_complex_fn(norm, "@T @{N}_norm(const @N *z) {
    if (__builtin_isinf(z->re)) return fabs$(z->re);
    if (__builtin_isinf(z->im)) return fabs$(z->im);
    return z->re * z->re + z->im * z->im;
}").
ccllib_complex_fn(conj, "@N @{N}_conj(const @N *z) { return (@N){ z->re, -z->im }; }").
ccllib_complex_fn('_polar', "static @N @{N}__polar(@T rho, @T theta) {
    @T nan = (@T)__builtin_nan(\"\");
    if (__builtin_isnan(rho) || __builtin_signbit(rho)) return (@N){ nan, nan };
    if (__builtin_isnan(theta)) { if (__builtin_isinf(rho)) return (@N){ rho, theta }; return (@N){ theta, theta }; }
    if (__builtin_isinf(theta)) { if (__builtin_isinf(rho)) return (@N){ rho, nan }; return (@N){ nan, nan }; }
    @T x = rho * cos$(theta), y = rho * sin$(theta);
    if (__builtin_isnan(x)) x = 0;
    if (__builtin_isnan(y)) y = 0;
    return (@N){ x, y };
}").
ccllib_complex_fn(exp, "@N @{N}_exp(const @N *z) {
    @T i = z->im;
    if (i == 0) return (@N){ exp$(z->re), copysign$((@T)0, z->im) };
    if (__builtin_isinf(z->re)) {
        if (z->re < 0) { if (!__builtin_isfinite(i)) i = 1; }
        else if (i == 0 || !__builtin_isfinite(i)) { if (__builtin_isinf(i)) i = (@T)__builtin_nan(\"\"); return (@N){ z->re, i }; }
    }
    @T e = exp$(z->re);
    return (@N){ e * cos$(i), e * sin$(i) };
}").
ccllib_complex_fn(log, "@N @{N}_log(const @N *z) { return (@N){ log$(hypot$(z->re, z->im)), atan2$(z->im, z->re) }; }").
ccllib_complex_fn(sqrt, "@N @{N}_sqrt(const @N *z) {
    if (__builtin_isinf(z->im)) return (@N){ (@T)__builtin_inf(), z->im };
    if (__builtin_isinf(z->re)) {
        if (z->re > 0) return (@N){ z->re, __builtin_isnan(z->im) ? z->im : copysign$((@T)0, z->im) };
        return (@N){ __builtin_isnan(z->im) ? z->im : (@T)0, copysign$(z->re, z->im) };
    }
    return @{N}__polar(sqrt$(hypot$(z->re, z->im)), atan2$(z->im, z->re) / (@T)2);
}").
ccllib_complex_fn(pow, "@N @{N}_pow(const @N *z, @T y) {
    @N l = @{N}_log(z);
    @T _Complex p = __builtin_complex(y, (@T)0) * __builtin_complex(l.re, l.im);
    @N q = { __real__ p, __imag__ p };
    return @{N}_exp(&q);
}").
ccllib_complex_fn('_sinh', "static @N @{N}__sinh(@T re, @T im) {
    @T nan = (@T)__builtin_nan(\"\");
    if (__builtin_isinf(re) && !__builtin_isfinite(im)) return (@N){ re, nan };
    if (re == 0 && !__builtin_isfinite(im)) return (@N){ re, nan };
    if (im == 0 && !__builtin_isfinite(re)) return (@N){ re, im };
    return (@N){ sinh$(re) * cos$(im), cosh$(re) * sin$(im) };
}").
ccllib_complex_fn('_cosh', "static @N @{N}__cosh(@T re, @T im) {
    @T nan = (@T)__builtin_nan(\"\");
    if (__builtin_isinf(re) && !__builtin_isfinite(im)) return (@N){ fabs$(re), nan };
    if (re == 0 && !__builtin_isfinite(im)) return (@N){ nan, re };
    if (re == 0 && im == 0) return (@N){ (@T)1, im };
    if (im == 0 && !__builtin_isfinite(re)) return (@N){ fabs$(re), im };
    return (@N){ cosh$(re) * cos$(im), sinh$(re) * sin$(im) };
}").
ccllib_complex_fn('_tanh', "static @N @{N}__tanh(@T re, @T im) {
    if (__builtin_isinf(re)) {
        if (!__builtin_isfinite(im)) return (@N){ copysign$((@T)1, re), (@T)0 };
        return (@N){ copysign$((@T)1, re), copysign$((@T)0, sin$((@T)2 * im)) };
    }
    if (__builtin_isnan(re) && im == 0) return (@N){ re, im };
    @T r2 = (@T)2 * re, i2 = (@T)2 * im;
    @T d = cosh$(r2) + cos$(i2), sh = sinh$(r2);
    if (__builtin_isinf(sh) && __builtin_isinf(d)) return (@N){ sh > 0 ? (@T)1 : (@T)-1, i2 > 0 ? (@T)0 : -(@T)0 };
    return (@N){ sh / d, sin$(i2) / d };
}").
ccllib_complex_fn(sin, "@N @{N}_sin(const @N *z) { @N w = @{N}__sinh(-z->im, z->re); return (@N){ w.im, -w.re }; }").
ccllib_complex_fn(cos, "@N @{N}_cos(const @N *z) { return @{N}__cosh(-z->im, z->re); }").
ccllib_complex_fn(tan, "@N @{N}_tan(const @N *z) { @N w = @{N}__tanh(-z->im, z->re); return (@N){ w.im, -w.re }; }").
ccllib_complex_fn(add, "@N @{N}_add(const @N *a, const @N *b) { return (@N){ a->re + b->re, a->im + b->im }; }").
ccllib_complex_fn(sub, "@N @{N}_sub(const @N *a, const @N *b) { return (@N){ a->re - b->re, a->im - b->im }; }").
ccllib_complex_fn(mul, "@N @{N}_mul(const @N *a, const @N *b) { @T _Complex r = __builtin_complex(a->re, a->im) * __builtin_complex(b->re, b->im); return (@N){ __real__ r, __imag__ r }; }").
ccllib_complex_fn(div, "@N @{N}_div(const @N *a, const @N *b) { @T _Complex r = __builtin_complex(a->re, a->im) / __builtin_complex(b->re, b->im); return (@N){ __real__ r, __imag__ r }; }").
ccllib_complex_fn(neg, "@N @{N}_neg(const @N *a) { return (@N){ -a->re, -a->im }; }").
ccllib_complex_fn(eq, "int @{N}_eq(const @N *a, const @N *b) { return a->re == b->re && a->im == b->im; }").
ccllib_complex_fn(ne, "int @{N}_ne(const @N *a, const @N *b) { return !(@{N}_eq(a, b)); }").
