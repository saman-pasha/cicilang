%% what ccllib's iostream modules share (phase 1d): the type text of a stream and the C texts of its functions.
%% ostream.pl, istream.pl, fstream.pl and stringstream.pl load this file by a directive; no program includes it.
%%
%% A stream's state is the same in every instance: the FILE (or, for a stringstream, the buffer), the base of an
%% integer (10, 16, 8), the floating format (fixed or scientific), boolalpha, the width and fill of the next value,
%% and the precision. A manipulator is a function of the instance, `setw(cout, 6)', because C has no `<<' that takes
%% one: C++'s `cout << setw(6)' waits for a reader form that a macro cannot give.
:- ensure_loaded(library(ccllib/ccllib)).

%% THE TYPE. `err' is kept for a stream that names its file by a default; the file of a fstream is its own after
%% open, and a stringstream's buffer is its own.
ccllib_stream_type(N, Items) :-
    ccl_c_items("typedef struct @N { long long f; int err; int base, fixed, sci, boolalpha; long width, prec; int fillch; } @N;",
                ['N' = name(N)], Items).

%% -- what every kind has: the file it writes to or reads from, and the tests
ccllib_stream_common_fn('_f', D, "static FILE *@{N}__f(const @N *o) { return o->f ? ccllib_file_of(o->f) : @D; }").
ccllib_stream_common_fn(good, _, "int @{N}_good(const @N *o) { return @{N}__f(o) && !ferror(@{N}__f(o)); }").
ccllib_stream_common_fn(bad, _, "int @{N}_bad(const @N *o) { return ferror(@{N}__f(o)) != 0; }").
ccllib_stream_common_fn(flush, _, "void @{N}_flush(@N *o) { fflush(@{N}__f(o)); }").
ccllib_stream_common_fn(eof, _, "int @{N}_eof(const @N *o) { return feof(@{N}__f(o)) != 0; }").

%% -- a value written: the width and the fill are applied once, then given up, as C++'s do
ccllib_stream_out_fn('_emit', _, "static void @{N}__emit(@N *o, const char *s, size_t n) {
    long w = o->width; o->width = 0;
    if (w > (long)n) for (long i = 0; i < w - (long)n; i++) fputc(o->fillch ? o->fillch : ' ', @{N}__f(o));
    if (n) fwrite(s, 1, n, @{N}__f(o));
}").
ccllib_stream_out_fn('_str', _, "static void @{N}__str(@N *o, const char *s) { @{N}__emit(o, s ? s : \"(null)\", s ? strlen(s) : 6); }").
ccllib_stream_out_fn('_int', _, "static void @{N}__int(@N *o, long long x, int uns) {
    char b[64]; int n;
    if (o->base == 16) n = snprintf(b, sizeof b, uns ? \"%llx\" : \"%llx\", (unsigned long long)x);
    else if (o->base == 8) n = snprintf(b, sizeof b, uns ? \"%llo\" : \"%llo\", (unsigned long long)x);
    else n = snprintf(b, sizeof b, uns ? \"%llu\" : \"%lld\", uns ? (unsigned long long)x : (long long)x);
    @{N}__emit(o, b, (size_t)n);
}").
ccllib_stream_out_fn('_flt', _, "static void @{N}__flt(@N *o, double x) {
    char b[512]; int n;
    if (o->prec > 0) {
        if (o->fixed) n = snprintf(b, sizeof b, \"%.*f\", (int)o->prec, x);
        else if (o->sci) n = snprintf(b, sizeof b, \"%.*e\", (int)o->prec, x);
        else n = snprintf(b, sizeof b, \"%.*g\", (int)o->prec, x);
    } else {
        if (o->fixed) n = snprintf(b, sizeof b, \"%f\", x);
        else if (o->sci) n = snprintf(b, sizeof b, \"%e\", x);
        else n = snprintf(b, sizeof b, \"%g\", x);
    }
    @{N}__emit(o, b, (size_t)n);
}").
ccllib_stream_out_fn(write_char, _, "int @{N}_write_char(@N *o, char x) { char b[1]; b[0] = x; @{N}__emit(o, b, 1); return 1; }").
ccllib_stream_out_fn(write_schar, _, "int @{N}_write_schar(@N *o, signed char x) { @{N}__int(o, (long long)x, 0); return 1; }").
ccllib_stream_out_fn(write_uchar, _, "int @{N}_write_uchar(@N *o, unsigned char x) { @{N}__int(o, (long long)x, 1); return 1; }").
ccllib_stream_out_fn(write_short, _, "int @{N}_write_short(@N *o, short x) { @{N}__int(o, (long long)x, 0); return 1; }").
ccllib_stream_out_fn(write_ushort, _, "int @{N}_write_ushort(@N *o, unsigned short x) { @{N}__int(o, (long long)x, 1); return 1; }").
ccllib_stream_out_fn(write_int, _, "int @{N}_write_int(@N *o, int x) { @{N}__int(o, (long long)x, 0); return 1; }").
ccllib_stream_out_fn(write_uint, _, "int @{N}_write_uint(@N *o, unsigned x) { @{N}__int(o, (long long)x, 1); return 1; }").
ccllib_stream_out_fn(write_long, _, "int @{N}_write_long(@N *o, long x) { @{N}__int(o, (long long)x, 0); return 1; }").
ccllib_stream_out_fn(write_ulong, _, "int @{N}_write_ulong(@N *o, unsigned long x) { @{N}__int(o, (long long)x, 1); return 1; }").
ccllib_stream_out_fn(write_llong, _, "int @{N}_write_llong(@N *o, long long x) { @{N}__int(o, x, 0); return 1; }").
ccllib_stream_out_fn(write_ullong, _, "int @{N}_write_ullong(@N *o, unsigned long long x) { @{N}__int(o, (long long)x, 1); return 1; }").
ccllib_stream_out_fn(write_size_t, _, "int @{N}_write_size_t(@N *o, size_t x) { @{N}__int(o, (long long)x, 1); return 1; }").
ccllib_stream_out_fn(write_double, _, "int @{N}_write_double(@N *o, double x) { @{N}__flt(o, x); return 1; }").
ccllib_stream_out_fn(write_float, _, "int @{N}_write_float(@N *o, float x) { @{N}__flt(o, (double)x); return 1; }").
ccllib_stream_out_fn(write_ldouble, _, "int @{N}_write_ldouble(@N *o, long double x) { @{N}__flt(o, (double)x); return 1; }").
ccllib_stream_out_fn(write_bool, _, "int @{N}_write_bool(@N *o, _Bool x) { @{N}__str(o, x ? (o->boolalpha ? \"true\" : \"1\") : (o->boolalpha ? \"false\" : \"0\")); return 1; }").
ccllib_stream_out_fn(write_ptr_char, _, "int @{N}_write_ptr_char(@N *o, char *x) { @{N}__str(o, x); return 1; }").
ccllib_stream_out_fn(write_ptr_const_char, _, "int @{N}_write_ptr_const_char(@N *o, const char *x) { @{N}__str(o, x); return 1; }").
ccllib_stream_out_fn(write_ptr_void, _, "int @{N}_write_ptr_void(@N *o, void *x) { char b[32]; int n = snprintf(b, sizeof b, \"%p\", x); @{N}__emit(o, b, (size_t)n); return 1; }").
ccllib_stream_out_fn(put, _, "void @{N}_put(@N *o, char x) { @{N}__emit(o, &x, 1); }").
ccllib_stream_out_fn(write, _, "void @{N}_write(@N *o, const char *s, size_t n) { @{N}__emit(o, s, n); }").

%% -- the manipulators of <iomanip>, as functions of the stream
ccllib_stream_out_fn(setw, _, "void @{N}_setw(@N *o, long n) { o->width = n; }").
ccllib_stream_out_fn(setprecision, _, "void @{N}_setprecision(@N *o, long n) { o->prec = n; }").
ccllib_stream_out_fn(setfill, _, "void @{N}_setfill(@N *o, char c) { o->fillch = c; }").
ccllib_stream_out_fn(hex, _, "void @{N}_hex(@N *o) { o->base = 16; }").
ccllib_stream_out_fn(dec, _, "void @{N}_dec(@N *o) { o->base = 10; }").
ccllib_stream_out_fn(oct, _, "void @{N}_oct(@N *o) { o->base = 8; }").
ccllib_stream_out_fn(fixed, _, "void @{N}_fixed(@N *o) { o->fixed = 1; o->sci = 0; }").
ccllib_stream_out_fn(scientific, _, "void @{N}_scientific(@N *o) { o->sci = 1; o->fixed = 0; }").
ccllib_stream_out_fn(boolalpha, _, "void @{N}_boolalpha(@N *o) { o->boolalpha = 1; }").
ccllib_stream_out_fn(noboolalpha, _, "void @{N}_noboolalpha(@N *o) { o->boolalpha = 0; }").

%% -- a value read. The right operand is taken by its address (ccl_iop_right/5), so each takes a pointer
ccllib_stream_in_fn(read_int, _, "int @{N}_read_int(@N *o, int *x) { return fscanf(@{N}__f(o), \"%d\", x) == 1; }").
ccllib_stream_in_fn(read_uint, _, "int @{N}_read_uint(@N *o, unsigned *x) { return fscanf(@{N}__f(o), \"%u\", x) == 1; }").
ccllib_stream_in_fn(read_long, _, "int @{N}_read_long(@N *o, long *x) { return fscanf(@{N}__f(o), \"%ld\", x) == 1; }").
ccllib_stream_in_fn(read_ulong, _, "int @{N}_read_ulong(@N *o, unsigned long *x) { return fscanf(@{N}__f(o), \"%lu\", x) == 1; }").
ccllib_stream_in_fn(read_llong, _, "int @{N}_read_llong(@N *o, long long *x) { return fscanf(@{N}__f(o), \"%lld\", x) == 1; }").
ccllib_stream_in_fn(read_ullong, _, "int @{N}_read_ullong(@N *o, unsigned long long *x) { return fscanf(@{N}__f(o), \"%llu\", x) == 1; }").
ccllib_stream_in_fn(read_double, _, "int @{N}_read_double(@N *o, double *x) { return fscanf(@{N}__f(o), \"%lf\", x) == 1; }").
ccllib_stream_in_fn(read_float, _, "int @{N}_read_float(@N *o, float *x) { return fscanf(@{N}__f(o), \"%f\", x) == 1; }").
ccllib_stream_in_fn(read_char, _, "int @{N}_read_char(@N *o, char *x) { return fscanf(@{N}__f(o), \"%c\", x) == 1; }").
ccllib_stream_in_fn(get, _, "int @{N}_get(@N *o) { return fgetc(@{N}__f(o)); }").
ccllib_stream_in_fn(getline, _, "char *@{N}_getline(@N *o, char *b, size_t n) {
    char *r = fgets(b, (int)n, @{N}__f(o));
    if (r) { size_t k = strlen(r); if (k && r[k - 1] == '\\n') r[--k] = 0; if (k && r[k - 1] == '\\r') r[--k] = 0; }
    return r;
}").
ccllib_stream_in_fn(read, _, "size_t @{N}_read(@N *o, char *b, size_t n) { return fread(b, 1, n, @{N}__f(o)); }").

%% -- a file stream: its file is opened and closed here
ccllib_stream_file_fn(open, "int @{N}_open(@N *o, const char *path, const char *mode) { if (o->f) ccllib_file_close(o->f); o->f = ccllib_file_open(path, mode); return o->f != 0; }").
ccllib_stream_file_fn(close, "void @{N}_close(@N *o) { if (o->f) { ccllib_file_close(o->f); o->f = 0; } }").
ccllib_stream_file_fn(is_open, "int @{N}_is_open(const @N *o) { return o->f != 0; }").
ccllib_stream_file_fn(drop, "void @{N}_drop(@N *o) { if (o->f) { ccllib_file_close(o->f); o->f = 0; } }").

%% A STRING STREAM: its characters stand in one own buffer. Writing appends at the end; reading walks a place from
%% the start. `str(ss)' gives the buffer's text, a `char *' where C++'s gives a string.
ccllib_sstream_type(N, Items) :-
    ccl_c_items("typedef struct @N { own char *buf; size_t len, cap, pos; int base, fixed, sci, boolalpha; long width, prec; int fillch; } @N;
void @{N}_drop(@N *s) { free(s->buf); }", ['N' = name(N)], Items).
ccllib_sstream_fn('_room', "static void @{N}__room(@N *s, size_t need) {
    if (need + 1 <= s->cap) return;
    size_t c = s->cap ? 2 * s->cap : 32;
    while (c < need + 1) c *= 2;
    s->buf = (char *)realloc(s->buf, c);
    if (!s->buf) abort();
    s->cap = c;
}").
ccllib_sstream_fn('_emit', "static void @{N}__emit(@N *s, const char *p, size_t n) {
    @{N}__room(s, s->len + n);
    long w = s->width; s->width = 0;
    if (w > (long)n) for (long i = 0; i < w - (long)n; i++) s->buf[s->len++] = (char)(s->fillch ? s->fillch : ' ');
    if (n) memcpy(s->buf + s->len, p, n), s->len += n;
    s->buf[s->len] = 0;
}").
ccllib_sstream_fn('_str', "static void @{N}__str(@N *s, const char *p) { @{N}__emit(s, p ? p : \"(null)\", p ? strlen(p) : 6); }").
ccllib_sstream_fn('_int', "static void @{N}__int(@N *s, long long x, int uns) {
    char b[64]; int n;
    if (s->base == 16) n = snprintf(b, sizeof b, \"%llx\", (unsigned long long)x);
    else if (s->base == 8) n = snprintf(b, sizeof b, \"%llo\", (unsigned long long)x);
    else n = snprintf(b, sizeof b, uns ? \"%llu\" : \"%lld\", uns ? (unsigned long long)x : (long long)x);
    @{N}__emit(s, b, (size_t)n);
}").
ccllib_sstream_fn('_flt', "static void @{N}__flt(@N *s, double x) {
    char b[512]; int n;
    if (s->prec > 0) {
        if (s->fixed) n = snprintf(b, sizeof b, \"%.*f\", (int)s->prec, x);
        else if (s->sci) n = snprintf(b, sizeof b, \"%.*e\", (int)s->prec, x);
        else n = snprintf(b, sizeof b, \"%.*g\", (int)s->prec, x);
    } else {
        if (s->fixed) n = snprintf(b, sizeof b, \"%f\", x);
        else if (s->sci) n = snprintf(b, sizeof b, \"%e\", x);
        else n = snprintf(b, sizeof b, \"%g\", x);
    }
    @{N}__emit(s, b, (size_t)n);
}").
ccllib_sstream_fn(write_char, "int @{N}_write_char(@N *s, char x) { @{N}__emit(s, &x, 1); return 1; }").
ccllib_sstream_fn(write_int, "int @{N}_write_int(@N *s, int x) { @{N}__int(s, (long long)x, 0); return 1; }").
ccllib_sstream_fn(write_uint, "int @{N}_write_uint(@N *s, unsigned x) { @{N}__int(s, (long long)x, 1); return 1; }").
ccllib_sstream_fn(write_long, "int @{N}_write_long(@N *s, long x) { @{N}__int(s, (long long)x, 0); return 1; }").
ccllib_sstream_fn(write_ulong, "int @{N}_write_ulong(@N *s, unsigned long x) { @{N}__int(s, (long long)x, 1); return 1; }").
ccllib_sstream_fn(write_llong, "int @{N}_write_llong(@N *s, long long x) { @{N}__int(s, x, 0); return 1; }").
ccllib_sstream_fn(write_ullong, "int @{N}_write_ullong(@N *s, unsigned long long x) { @{N}__int(s, (long long)x, 1); return 1; }").
ccllib_sstream_fn(write_size_t, "int @{N}_write_size_t(@N *s, size_t x) { @{N}__int(s, (long long)x, 1); return 1; }").
ccllib_sstream_fn(write_double, "int @{N}_write_double(@N *s, double x) { @{N}__flt(s, x); return 1; }").
ccllib_sstream_fn(write_float, "int @{N}_write_float(@N *s, float x) { @{N}__flt(s, (double)x); return 1; }").
ccllib_sstream_fn(write_bool, "int @{N}_write_bool(@N *s, _Bool x) { @{N}__str(s, x ? (s->boolalpha ? \"true\" : \"1\") : (s->boolalpha ? \"false\" : \"0\")); return 1; }").
ccllib_sstream_fn(write_ptr_char, "int @{N}_write_ptr_char(@N *s, char *x) { @{N}__str(s, x); return 1; }").
ccllib_sstream_fn(write_ptr_const_char, "int @{N}_write_ptr_const_char(@N *s, const char *x) { @{N}__str(s, x); return 1; }").
ccllib_sstream_fn(put, "void @{N}_put(@N *s, char x) { @{N}__emit(s, &x, 1); }").
ccllib_sstream_fn(write, "void @{N}_write(@N *s, const char *p, size_t n) { @{N}__emit(s, p, n); }").
ccllib_sstream_fn(setw, "void @{N}_setw(@N *s, long n) { s->width = n; }").
ccllib_sstream_fn(setprecision, "void @{N}_setprecision(@N *s, long n) { s->prec = n; }").
ccllib_sstream_fn(setfill, "void @{N}_setfill(@N *s, char c) { s->fillch = c; }").
ccllib_sstream_fn(hex, "void @{N}_hex(@N *s) { s->base = 16; }").
ccllib_sstream_fn(dec, "void @{N}_dec(@N *s) { s->base = 10; }").
ccllib_sstream_fn(oct, "void @{N}_oct(@N *s) { s->base = 8; }").
ccllib_sstream_fn(fixed, "void @{N}_fixed(@N *s) { s->fixed = 1; s->sci = 0; }").
ccllib_sstream_fn(scientific, "void @{N}_scientific(@N *s) { s->sci = 1; s->fixed = 0; }").
ccllib_sstream_fn(boolalpha, "void @{N}_boolalpha(@N *s) { s->boolalpha = 1; }").
ccllib_sstream_fn(noboolalpha, "void @{N}_noboolalpha(@N *s) { s->boolalpha = 0; }").
ccllib_sstream_fn(str, "char *@{N}_str(@N *s) { @{N}__room(s, s->len); s->buf[s->len] = 0; return s->buf; }").
ccllib_sstream_fn(clear, "void @{N}_clear(@N *s) { s->len = 0; s->pos = 0; if (s->buf) s->buf[0] = 0; }").
ccllib_sstream_fn(rewind, "void @{N}_rewind(@N *s) { s->pos = 0; }").
ccllib_sstream_fn(good, "int @{N}_good(const @N *s) { return s->pos <= s->len; }").
ccllib_sstream_fn(eof, "int @{N}_eof(const @N *s) { return s->pos >= s->len; }").
ccllib_sstream_fn(flush, "void @{N}_flush(@N *s) { (void)s; }").
ccllib_sstream_in_fn(read_int, "int @{N}_read_int(@N *s, int *x) { char *e; long long v; if (s->pos > s->len) return 0; v = strtoll(s->buf + s->pos, &e, s->base == 16 ? 16 : 10); if (e == s->buf + s->pos) return 0; *x = (int)v; s->pos = (size_t)(e - s->buf); return 1; }").
ccllib_sstream_in_fn(read_uint, "int @{N}_read_uint(@N *s, unsigned *x) { char *e; unsigned long long v; if (s->pos > s->len) return 0; v = strtoull(s->buf + s->pos, &e, s->base == 16 ? 16 : 10); if (e == s->buf + s->pos) return 0; *x = (unsigned)v; s->pos = (size_t)(e - s->buf); return 1; }").
ccllib_sstream_in_fn(read_long, "int @{N}_read_long(@N *s, long *x) { char *e; long v; if (s->pos > s->len) return 0; v = strtol(s->buf + s->pos, &e, s->base == 16 ? 16 : 10); if (e == s->buf + s->pos) return 0; *x = v; s->pos = (size_t)(e - s->buf); return 1; }").
ccllib_sstream_in_fn(read_ulong, "int @{N}_read_ulong(@N *s, unsigned long *x) { char *e; unsigned long v; if (s->pos > s->len) return 0; v = strtoul(s->buf + s->pos, &e, s->base == 16 ? 16 : 10); if (e == s->buf + s->pos) return 0; *x = v; s->pos = (size_t)(e - s->buf); return 1; }").
ccllib_sstream_in_fn(read_llong, "int @{N}_read_llong(@N *s, long long *x) { char *e; long long v; if (s->pos > s->len) return 0; v = strtoll(s->buf + s->pos, &e, s->base == 16 ? 16 : 10); if (e == s->buf + s->pos) return 0; *x = v; s->pos = (size_t)(e - s->buf); return 1; }").
ccllib_sstream_in_fn(read_ullong, "int @{N}_read_ullong(@N *s, unsigned long long *x) { char *e; unsigned long long v; if (s->pos > s->len) return 0; v = strtoull(s->buf + s->pos, &e, s->base == 16 ? 16 : 10); if (e == s->buf + s->pos) return 0; *x = v; s->pos = (size_t)(e - s->buf); return 1; }").
ccllib_sstream_in_fn(read_double, "int @{N}_read_double(@N *s, double *x) { char *e; double v; if (s->pos > s->len) return 0; v = strtod(s->buf + s->pos, &e); if (e == s->buf + s->pos) return 0; *x = v; s->pos = (size_t)(e - s->buf); return 1; }").
ccllib_sstream_in_fn(read_float, "int @{N}_read_float(@N *s, float *x) { char *e; float v; if (s->pos > s->len) return 0; v = (float)strtod(s->buf + s->pos, &e); if (e == s->buf + s->pos) return 0; *x = v; s->pos = (size_t)(e - s->buf); return 1; }").
ccllib_sstream_in_fn(read_char, "int @{N}_read_char(@N *s, char *x) { if (s->pos >= s->len) return 0; *x = s->buf[s->pos++]; return 1; }").
ccllib_sstream_in_fn(get, "int @{N}_get(@N *s) { return s->pos < s->len ? (unsigned char)s->buf[s->pos++] : -1; }").
ccllib_sstream_in_fn(getline, "char *@{N}_getline(@N *s, char *b, size_t n) {
    size_t k = 0;
    if (s->pos >= s->len || n == 0) return 0;
    while (s->pos < s->len && k + 1 < n && s->buf[s->pos] != '\\n') b[k++] = s->buf[s->pos++];
    if (s->pos < s->len && s->buf[s->pos] == '\\n') s->pos++;
    b[k] = 0;
    return b;
}").
ccllib_sstream_in_fn(read, "size_t @{N}_read(@N *s, char *b, size_t n) { size_t k = s->len - s->pos; if (k > n) k = n; if (k) memcpy(b, s->buf + s->pos, k); s->pos += k; return k; }").
