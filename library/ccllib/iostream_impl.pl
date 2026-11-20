%% what ccllib's iostream modules share (phase 1d): the type text of a stream and the C texts of its functions.
%% ostream.pl, istream.pl, fstream.pl and stringstream.pl load this file by a directive; no program includes it.
%%
%% A stream's state is the same in every instance: the FILE (or, for a stringstream, the buffer), the base of an
%% integer (10, 16, 8), the floating format (fixed or scientific), boolalpha, the width and fill of the next value,
%% the precision and whether the program set it, and whether a read failed. A manipulator is a function of the
%% instance, `setw(cout, 6)', because C has no `<<' that takes one: C++'s `cout << setw(6)' waits for a reader form
%% that a macro cannot give.
%%
%% `o << x' AND `i >> x' GIVE THE STREAM (1.6.3), as C++'s operators give it: each `_write_<word>' and `_read_<word>'
%% gives the stream's address, tied to it, so `cout << "a" << 1 << endl' is three calls, each on the stream that the
%% one before it gave (the reader takes a pointer to an instance on the left of `<<' and `>>' as it is). A read that
%% finds no value gives a null pointer and marks the stream failed: `while (cin >> x)' ends where the input does, a
%% read after it in the chain reads nothing, as C++'s sentry does, and `fail(i)', `good(i)' and `clear(i)' answer and
%% put back the state. Through 1.6.0 each gave an int, 1, so `cout << "a" << 1' shifted that int by 1, `<< endl'
%% shifted it by a pointer, and `a' alone was written.
:- ensure_loaded(library(ccllib/ccllib)).

%% THE TYPE. `err' is kept for a stream that names its file by a default; the file of a fstream is its own after
%% open, and a stringstream's buffer is its own.
ccllib_stream_type(N, Items) :-
    ccl_c_items("typedef struct @N { long long f; int err; int base, fixed, sci, boolalpha; long width, prec; int fillch; int fail, precset; } @N;",
                ['N' = name(N)], Items).

%% -- what every kind has: the file it writes to or reads from, and the tests of its state. good where no read failed,
%% the file has no error and no read met its end; fail where a read failed or the file has an error; clear puts both
%% back (1.6.3: good was true after a failed read)
ccllib_stream_common_fn('_f', D, "static FILE *@{N}__f(const @N *o) { return o->f ? ccllib_file_of(o->f) : @D; }").
ccllib_stream_common_fn(good, _, "int @{N}_good(const @N *o) { return @{N}__f(o) && !ferror(@{N}__f(o)) && !feof(@{N}__f(o)) && !o->fail; }").
ccllib_stream_common_fn(bad, _, "int @{N}_bad(const @N *o) { return ferror(@{N}__f(o)) != 0; }").
ccllib_stream_common_fn(fail, _, "int @{N}_fail(const @N *o) { return o->fail || ferror(@{N}__f(o)) != 0; }").
ccllib_stream_common_fn(clear, _, "void @{N}_clear(@N *o) { o->fail = 0; clearerr(@{N}__f(o)); }").
ccllib_stream_common_fn(flush, _, "void @{N}_flush(@N *o) { fflush(@{N}__f(o)); }").
ccllib_stream_common_fn(eof, _, "int @{N}_eof(const @N *o) { return feof(@{N}__f(o)) != 0; }").

%% -- a value written: the width and the fill are applied once, then given up, as C++'s do
ccllib_stream_out_fn('_emit', _, "static void @{N}__emit(@N *o, const char *s, size_t n) {
    long w = o->width; o->width = 0;
    if (w > (long)n) for (long i = 0; i < w - (long)n; i++) fputc(o->fillch ? o->fillch : ' ', @{N}__f(o));
    if (n) fwrite(s, 1, n, @{N}__f(o));
}").
ccllib_stream_out_fn('_str', _, "static void @{N}__str(@N *o, const char *s) { @{N}__emit(o, s ? s : \"(null)\", s ? strlen(s) : 6); }").
%% an integer in its base; in hex and in oct the value's own bits, as many as its type has (1.6.3: C++'s `hex' of an
%% int's -1 is ffffffff, and was the 64 bits of a long long)
ccllib_stream_out_fn('_int', _, "static void @{N}__int(@N *o, long long x, int uns, int bits) {
    char b[64]; int n; unsigned long long u = (unsigned long long)x;
    if (bits < 64) u &= (1ULL << bits) - 1;
    if (o->base == 16) n = snprintf(b, sizeof b, \"%llx\", u);
    else if (o->base == 8) n = snprintf(b, sizeof b, \"%llo\", u);
    else if (uns) n = snprintf(b, sizeof b, \"%llu\", u);
    else n = snprintf(b, sizeof b, \"%lld\", x);
    @{N}__emit(o, b, (size_t)n);
}").
%% a floating value in the precision that the program set, else C++'s 6 (1.6.3: `fixed' with `setprecision(0)' was
%% `%f', six places); a text longer than the frame's buffer is made in a buffer of its own length, where it was cut
ccllib_stream_out_fn('_flt', _, "static void @{N}__flt(@N *o, double x) {
    char b[512]; int p = o->precset ? (int)o->prec : 6;
    const char *fm = o->fixed ? \"%.*f\" : o->sci ? \"%.*e\" : \"%.*g\";
    int n = snprintf(b, sizeof b, fm, p, x);
    if (n < 0) return;
    if ((size_t)n < sizeof b) { @{N}__emit(o, b, (size_t)n); return; }
    own char *h = (char *)malloc((size_t)n + 1);
    if (!h) abort();
    snprintf(h, (size_t)n + 1, fm, p, x);
    @{N}__emit(o, h, (size_t)n);
    free(h);
}").
%% each value's function gives the stream, tied to it (1.6.3)
ccllib_stream_out_fn(write_char, _, "@N *@{N}_write_char(@N *o, char x) tie o { char b[1]; b[0] = x; @{N}__emit(o, b, 1); return o; }").
%% a signed and an unsigned char are characters, as C++'s inserters of the two write them
%% ([ostream.inserters.character]; 1.6.3: their numbers were written)
ccllib_stream_out_fn(write_schar, _, "@N *@{N}_write_schar(@N *o, signed char x) tie o { char b[1]; b[0] = (char)x; @{N}__emit(o, b, 1); return o; }").
ccllib_stream_out_fn(write_uchar, _, "@N *@{N}_write_uchar(@N *o, unsigned char x) tie o { char b[1]; b[0] = (char)x; @{N}__emit(o, b, 1); return o; }").
ccllib_stream_out_fn(write_short, _, "@N *@{N}_write_short(@N *o, short x) tie o { @{N}__int(o, (long long)x, 0, (int)(8 * sizeof x)); return o; }").
ccllib_stream_out_fn(write_ushort, _, "@N *@{N}_write_ushort(@N *o, unsigned short x) tie o { @{N}__int(o, (long long)x, 1, (int)(8 * sizeof x)); return o; }").
ccllib_stream_out_fn(write_int, _, "@N *@{N}_write_int(@N *o, int x) tie o { @{N}__int(o, (long long)x, 0, (int)(8 * sizeof x)); return o; }").
ccllib_stream_out_fn(write_uint, _, "@N *@{N}_write_uint(@N *o, unsigned x) tie o { @{N}__int(o, (long long)x, 1, (int)(8 * sizeof x)); return o; }").
ccllib_stream_out_fn(write_long, _, "@N *@{N}_write_long(@N *o, long x) tie o { @{N}__int(o, (long long)x, 0, (int)(8 * sizeof x)); return o; }").
ccllib_stream_out_fn(write_ulong, _, "@N *@{N}_write_ulong(@N *o, unsigned long x) tie o { @{N}__int(o, (long long)x, 1, (int)(8 * sizeof x)); return o; }").
ccllib_stream_out_fn(write_llong, _, "@N *@{N}_write_llong(@N *o, long long x) tie o { @{N}__int(o, x, 0, 64); return o; }").
ccllib_stream_out_fn(write_ullong, _, "@N *@{N}_write_ullong(@N *o, unsigned long long x) tie o { @{N}__int(o, (long long)x, 1, 64); return o; }").
ccllib_stream_out_fn(write_size_t, _, "@N *@{N}_write_size_t(@N *o, size_t x) tie o { @{N}__int(o, (long long)x, 1, (int)(8 * sizeof x)); return o; }").
ccllib_stream_out_fn(write_double, _, "@N *@{N}_write_double(@N *o, double x) tie o { @{N}__flt(o, x); return o; }").
ccllib_stream_out_fn(write_float, _, "@N *@{N}_write_float(@N *o, float x) tie o { @{N}__flt(o, (double)x); return o; }").
ccllib_stream_out_fn(write_ldouble, _, "@N *@{N}_write_ldouble(@N *o, long double x) tie o { @{N}__flt(o, (double)x); return o; }").
ccllib_stream_out_fn(write_bool, _, "@N *@{N}_write_bool(@N *o, _Bool x) tie o { @{N}__str(o, x ? (o->boolalpha ? \"true\" : \"1\") : (o->boolalpha ? \"false\" : \"0\")); return o; }").
ccllib_stream_out_fn(write_ptr_char, _, "@N *@{N}_write_ptr_char(@N *o, char *x) tie o { @{N}__str(o, x); return o; }").
ccllib_stream_out_fn(write_ptr_const_char, _, "@N *@{N}_write_ptr_const_char(@N *o, const char *x) tie o { @{N}__str(o, x); return o; }").
ccllib_stream_out_fn(write_ptr_void, _, "@N *@{N}_write_ptr_void(@N *o, void *x) tie o { char b[32]; int n = snprintf(b, sizeof b, \"%p\", x); @{N}__emit(o, b, (size_t)n); return o; }").
%% `endl' and `ends' are values of types of their own (the headers'), as C++'s manipulators are functions: endl writes
%% the end of a line and flushes the stream, ends a null character, each with no width, as C++'s put (1.6.3: endl was
%% the text "\n", and a line before an abort was lost)
ccllib_stream_out_fn(write_ccllib_endl_t, _, "@N *@{N}_write_ccllib_endl_t(@N *o, ccllib_endl_t e) tie o { (void)e; fputc('\\n', @{N}__f(o)); fflush(@{N}__f(o)); return o; }").
ccllib_stream_out_fn(write_ccllib_ends_t, _, "@N *@{N}_write_ccllib_ends_t(@N *o, ccllib_ends_t e) tie o { (void)e; fputc(0, @{N}__f(o)); return o; }").
%% put and write are C++'s unformatted output: no width (1.6.3)
ccllib_stream_out_fn(put, _, "void @{N}_put(@N *o, char x) { fputc((unsigned char)x, @{N}__f(o)); }").
ccllib_stream_out_fn(write, _, "void @{N}_write(@N *o, const char *s, size_t n) { if (n) fwrite(s, 1, n, @{N}__f(o)); }").

%% -- the manipulators of <iomanip>, as functions of the stream
ccllib_stream_out_fn(setw, _, "void @{N}_setw(@N *o, long n) { o->width = n; }").
ccllib_stream_out_fn(setprecision, _, "void @{N}_setprecision(@N *o, long n) { o->prec = n; o->precset = 1; }").
ccllib_stream_out_fn(setfill, _, "void @{N}_setfill(@N *o, char c) { o->fillch = c; }").
ccllib_stream_out_fn(hex, _, "void @{N}_hex(@N *o) { o->base = 16; }").
ccllib_stream_out_fn(dec, _, "void @{N}_dec(@N *o) { o->base = 10; }").
ccllib_stream_out_fn(oct, _, "void @{N}_oct(@N *o) { o->base = 8; }").
ccllib_stream_out_fn(fixed, _, "void @{N}_fixed(@N *o) { o->fixed = 1; o->sci = 0; }").
ccllib_stream_out_fn(scientific, _, "void @{N}_scientific(@N *o) { o->sci = 1; o->fixed = 0; }").
ccllib_stream_out_fn(boolalpha, _, "void @{N}_boolalpha(@N *o) { o->boolalpha = 1; }").
ccllib_stream_out_fn(noboolalpha, _, "void @{N}_noboolalpha(@N *o) { o->boolalpha = 0; }").

%% -- a value read. The right operand is taken by its address (ccl_iop_right/5), so each takes a pointer. Each gives the
%% stream, or a null pointer where it found no value (1.6.3): the stream is then failed; a read that met no character
%% leaves the object as it was, and one whose characters are no value of the type writes zero, as C++'s do; a read on
%% a null or failed stream reads nothing. A character is read after the white space before it (1.6.3: `cin >> c' kept
%% the space)
ccllib_stream_in_fn(read_int, _, "@N *@{N}_read_int(@N *o, int *x) tie o { int r; if (!o || o->fail) return 0; r = fscanf(@{N}__f(o), \"%d\", x); if (r == 1) return o; if (r == 0) *x = 0; o->fail = 1; return 0; }").
ccllib_stream_in_fn(read_uint, _, "@N *@{N}_read_uint(@N *o, unsigned *x) tie o { int r; if (!o || o->fail) return 0; r = fscanf(@{N}__f(o), \"%u\", x); if (r == 1) return o; if (r == 0) *x = 0; o->fail = 1; return 0; }").
ccllib_stream_in_fn(read_long, _, "@N *@{N}_read_long(@N *o, long *x) tie o { int r; if (!o || o->fail) return 0; r = fscanf(@{N}__f(o), \"%ld\", x); if (r == 1) return o; if (r == 0) *x = 0; o->fail = 1; return 0; }").
ccllib_stream_in_fn(read_ulong, _, "@N *@{N}_read_ulong(@N *o, unsigned long *x) tie o { int r; if (!o || o->fail) return 0; r = fscanf(@{N}__f(o), \"%lu\", x); if (r == 1) return o; if (r == 0) *x = 0; o->fail = 1; return 0; }").
ccllib_stream_in_fn(read_llong, _, "@N *@{N}_read_llong(@N *o, long long *x) tie o { int r; if (!o || o->fail) return 0; r = fscanf(@{N}__f(o), \"%lld\", x); if (r == 1) return o; if (r == 0) *x = 0; o->fail = 1; return 0; }").
ccllib_stream_in_fn(read_ullong, _, "@N *@{N}_read_ullong(@N *o, unsigned long long *x) tie o { int r; if (!o || o->fail) return 0; r = fscanf(@{N}__f(o), \"%llu\", x); if (r == 1) return o; if (r == 0) *x = 0; o->fail = 1; return 0; }").
ccllib_stream_in_fn(read_double, _, "@N *@{N}_read_double(@N *o, double *x) tie o { int r; if (!o || o->fail) return 0; r = fscanf(@{N}__f(o), \"%lf\", x); if (r == 1) return o; if (r == 0) *x = 0; o->fail = 1; return 0; }").
ccllib_stream_in_fn(read_float, _, "@N *@{N}_read_float(@N *o, float *x) tie o { int r; if (!o || o->fail) return 0; r = fscanf(@{N}__f(o), \"%f\", x); if (r == 1) return o; if (r == 0) *x = 0; o->fail = 1; return 0; }").
ccllib_stream_in_fn(read_char, _, "@N *@{N}_read_char(@N *o, char *x) tie o { if (!o || o->fail) return 0; if (fscanf(@{N}__f(o), \" %c\", x) == 1) return o; o->fail = 1; return 0; }").
ccllib_stream_in_fn(get, _, "int @{N}_get(@N *o) { int c; if (o->fail) return -1; c = fgetc(@{N}__f(o)); if (c < 0) o->fail = 1; return c; }").
%% a line, its end taken away and a carriage return before it kept, as C++'s getline keeps it; a line of n - 1
%% characters or more is n - 1 of them in the buffer and fails the stream, unless its end comes next, as C++'s
%% ([istream.unformatted], getline: the file's end, then the line's, then the count; 1.6.3: the rest of the line was the
%% next line); a getline that reads no line leaves an empty one in the buffer, as C++'s stores its null character
ccllib_stream_in_fn(getline, _, "char *@{N}_getline(@N *o, char *b, size_t n) {
    size_t k; int c;
    if (n == 0) { o->fail = 1; return 0; }
    b[0] = 0;
    if (o->fail) return 0;
    if (!fgets(b, (int)n, @{N}__f(o))) { b[0] = 0; o->fail = 1; return 0; }
    k = strlen(b);
    if (k && b[k - 1] == '\\n') { b[--k] = 0; return b; }
    if (k + 1 < n) return b;
    c = fgetc(@{N}__f(o));
    if (c == '\\n') return b;
    if (c < 0) { if (k) return b; o->fail = 1; return 0; }
    ungetc(c, @{N}__f(o)); o->fail = 1; return 0;
}").
ccllib_stream_in_fn(read, _, "size_t @{N}_read(@N *o, char *b, size_t n) { size_t k; if (o->fail) return 0; k = fread(b, 1, n, @{N}__f(o)); if (k < n) o->fail = 1; return k; }").

%% -- a file stream: its file is opened and closed here, and an open puts its state back
ccllib_stream_file_fn(open, "int @{N}_open(@N *o, const char *path, const char *mode) { if (o->f) ccllib_file_close(o->f); o->f = ccllib_file_open(path, mode); o->fail = o->f == 0; return o->f != 0; }").
ccllib_stream_file_fn(close, "void @{N}_close(@N *o) { if (o->f) { ccllib_file_close(o->f); o->f = 0; } }").
ccllib_stream_file_fn(is_open, "int @{N}_is_open(const @N *o) { return o->f != 0; }").
ccllib_stream_file_fn(drop, "void @{N}_drop(@N *o) { if (o->f) { ccllib_file_close(o->f); o->f = 0; } }").

%% A STRING STREAM: its characters stand in one own buffer. Writing appends at the end; reading walks a place from the
%% start. `str(ss)' gives the buffer's text, a `char *' tied to the stream, where C++'s gives a string (1.6.3: it was no
%% borrow, so the safe part took its text as new memory). Its state: a failed read, and a read that met the end.
ccllib_sstream_type(N, Items) :-
    ccl_c_items("typedef struct @N { own char *buf; size_t len, cap, pos; int base, fixed, sci, boolalpha; long width, prec; int fillch; int fail, eofbit, precset; } @N;
void @{N}_drop(@N *s) { free(s->buf); }", ['N' = name(N)], Items).
ccllib_sstream_fn('_room', "static void @{N}__room(@N *s, size_t need) {
    if (need + 1 <= s->cap) return;
    size_t c = s->cap ? 2 * s->cap : 32;
    while (c < need + 1) c *= 2;
    s->buf = (char *)realloc(s->buf, c);
    if (!s->buf) abort();
    s->cap = c;
}").
%% the room for the fill and the value both (1.6.3: `setw(s, 100); s << 7' made room for one character and wrote 100)
ccllib_sstream_fn('_emit', "static void @{N}__emit(@N *s, const char *p, size_t n) {
    long w = s->width; s->width = 0;
    size_t pad = w > (long)n ? (size_t)w - n : 0;
    @{N}__room(s, s->len + pad + n);
    for (size_t i = 0; i < pad; i++) s->buf[s->len++] = (char)(s->fillch ? s->fillch : ' ');
    if (n) memcpy(s->buf + s->len, p, n), s->len += n;
    s->buf[s->len] = 0;
}").
%% a character with no width, as put writes it
ccllib_sstream_fn('_put', "static void @{N}__put(@N *s, char c) { @{N}__room(s, s->len + 1); s->buf[s->len++] = c; s->buf[s->len] = 0; }").
ccllib_sstream_fn('_str', "static void @{N}__str(@N *s, const char *p) { @{N}__emit(s, p ? p : \"(null)\", p ? strlen(p) : 6); }").
ccllib_sstream_fn('_int', "static void @{N}__int(@N *s, long long x, int uns, int bits) {
    char b[64]; int n; unsigned long long u = (unsigned long long)x;
    if (bits < 64) u &= (1ULL << bits) - 1;
    if (s->base == 16) n = snprintf(b, sizeof b, \"%llx\", u);
    else if (s->base == 8) n = snprintf(b, sizeof b, \"%llo\", u);
    else if (uns) n = snprintf(b, sizeof b, \"%llu\", u);
    else n = snprintf(b, sizeof b, \"%lld\", x);
    @{N}__emit(s, b, (size_t)n);
}").
ccllib_sstream_fn('_flt', "static void @{N}__flt(@N *s, double x) {
    char b[512]; int p = s->precset ? (int)s->prec : 6;
    const char *fm = s->fixed ? \"%.*f\" : s->sci ? \"%.*e\" : \"%.*g\";
    int n = snprintf(b, sizeof b, fm, p, x);
    if (n < 0) return;
    if ((size_t)n < sizeof b) { @{N}__emit(s, b, (size_t)n); return; }
    own char *h = (char *)malloc((size_t)n + 1);
    if (!h) abort();
    snprintf(h, (size_t)n + 1, fm, p, x);
    @{N}__emit(s, h, (size_t)n);
    free(h);
}").
ccllib_sstream_fn(write_char, "@N *@{N}_write_char(@N *s, char x) tie s { @{N}__emit(s, &x, 1); return s; }").
%% a stringstream writes each type that an ostream writes (1.6.3: a short, an unsigned short, a signed and an unsigned
%% char, a long double and a void pointer were refused by name)
ccllib_sstream_fn(write_schar, "@N *@{N}_write_schar(@N *s, signed char x) tie s { char c = (char)x; @{N}__emit(s, &c, 1); return s; }").
ccllib_sstream_fn(write_uchar, "@N *@{N}_write_uchar(@N *s, unsigned char x) tie s { char c = (char)x; @{N}__emit(s, &c, 1); return s; }").
ccllib_sstream_fn(write_short, "@N *@{N}_write_short(@N *s, short x) tie s { @{N}__int(s, (long long)x, 0, (int)(8 * sizeof x)); return s; }").
ccllib_sstream_fn(write_ushort, "@N *@{N}_write_ushort(@N *s, unsigned short x) tie s { @{N}__int(s, (long long)x, 1, (int)(8 * sizeof x)); return s; }").
ccllib_sstream_fn(write_int, "@N *@{N}_write_int(@N *s, int x) tie s { @{N}__int(s, (long long)x, 0, (int)(8 * sizeof x)); return s; }").
ccllib_sstream_fn(write_uint, "@N *@{N}_write_uint(@N *s, unsigned x) tie s { @{N}__int(s, (long long)x, 1, (int)(8 * sizeof x)); return s; }").
ccllib_sstream_fn(write_long, "@N *@{N}_write_long(@N *s, long x) tie s { @{N}__int(s, (long long)x, 0, (int)(8 * sizeof x)); return s; }").
ccllib_sstream_fn(write_ulong, "@N *@{N}_write_ulong(@N *s, unsigned long x) tie s { @{N}__int(s, (long long)x, 1, (int)(8 * sizeof x)); return s; }").
ccllib_sstream_fn(write_llong, "@N *@{N}_write_llong(@N *s, long long x) tie s { @{N}__int(s, x, 0, 64); return s; }").
ccllib_sstream_fn(write_ullong, "@N *@{N}_write_ullong(@N *s, unsigned long long x) tie s { @{N}__int(s, (long long)x, 1, 64); return s; }").
ccllib_sstream_fn(write_size_t, "@N *@{N}_write_size_t(@N *s, size_t x) tie s { @{N}__int(s, (long long)x, 1, (int)(8 * sizeof x)); return s; }").
ccllib_sstream_fn(write_double, "@N *@{N}_write_double(@N *s, double x) tie s { @{N}__flt(s, x); return s; }").
ccllib_sstream_fn(write_float, "@N *@{N}_write_float(@N *s, float x) tie s { @{N}__flt(s, (double)x); return s; }").
ccllib_sstream_fn(write_ldouble, "@N *@{N}_write_ldouble(@N *s, long double x) tie s { @{N}__flt(s, (double)x); return s; }").
ccllib_sstream_fn(write_bool, "@N *@{N}_write_bool(@N *s, _Bool x) tie s { @{N}__str(s, x ? (s->boolalpha ? \"true\" : \"1\") : (s->boolalpha ? \"false\" : \"0\")); return s; }").
ccllib_sstream_fn(write_ptr_char, "@N *@{N}_write_ptr_char(@N *s, char *x) tie s { @{N}__str(s, x); return s; }").
ccllib_sstream_fn(write_ptr_const_char, "@N *@{N}_write_ptr_const_char(@N *s, const char *x) tie s { @{N}__str(s, x); return s; }").
ccllib_sstream_fn(write_ptr_void, "@N *@{N}_write_ptr_void(@N *s, void *x) tie s { char b[32]; int n = snprintf(b, sizeof b, \"%p\", x); @{N}__emit(s, b, (size_t)n); return s; }").
ccllib_sstream_fn(write_ccllib_endl_t, "@N *@{N}_write_ccllib_endl_t(@N *s, ccllib_endl_t e) tie s { (void)e; @{N}__put(s, '\\n'); return s; }").
ccllib_sstream_fn(write_ccllib_ends_t, "@N *@{N}_write_ccllib_ends_t(@N *s, ccllib_ends_t e) tie s { (void)e; @{N}__put(s, 0); return s; }").
ccllib_sstream_fn(put, "void @{N}_put(@N *s, char x) { @{N}__put(s, x); }").
ccllib_sstream_fn(write, "void @{N}_write(@N *s, const char *p, size_t n) { if (!n) return; @{N}__room(s, s->len + n); memcpy(s->buf + s->len, p, n); s->len += n; s->buf[s->len] = 0; }").
ccllib_sstream_fn(setw, "void @{N}_setw(@N *s, long n) { s->width = n; }").
ccllib_sstream_fn(setprecision, "void @{N}_setprecision(@N *s, long n) { s->prec = n; s->precset = 1; }").
ccllib_sstream_fn(setfill, "void @{N}_setfill(@N *s, char c) { s->fillch = c; }").
ccllib_sstream_fn(hex, "void @{N}_hex(@N *s) { s->base = 16; }").
ccllib_sstream_fn(dec, "void @{N}_dec(@N *s) { s->base = 10; }").
ccllib_sstream_fn(oct, "void @{N}_oct(@N *s) { s->base = 8; }").
ccllib_sstream_fn(fixed, "void @{N}_fixed(@N *s) { s->fixed = 1; s->sci = 0; }").
ccllib_sstream_fn(scientific, "void @{N}_scientific(@N *s) { s->sci = 1; s->fixed = 0; }").
ccllib_sstream_fn(boolalpha, "void @{N}_boolalpha(@N *s) { s->boolalpha = 1; }").
ccllib_sstream_fn(noboolalpha, "void @{N}_noboolalpha(@N *s) { s->boolalpha = 0; }").
ccllib_sstream_fn(str, "char *@{N}_str(@N *s) tie s { @{N}__room(s, s->len); s->buf[s->len] = 0; return s->buf; }").
%% clear empties the stream, as ccllib's has done since 1.3.0, and puts its state back; rewind puts the read place at
%% the start and the state back
ccllib_sstream_fn(clear, "void @{N}_clear(@N *s) { s->len = 0; s->pos = 0; s->fail = 0; s->eofbit = 0; if (s->buf) s->buf[0] = 0; }").
ccllib_sstream_fn(rewind, "void @{N}_rewind(@N *s) { s->pos = 0; s->fail = 0; s->eofbit = 0; }").
ccllib_sstream_fn(good, "int @{N}_good(const @N *s) { return !s->fail && !s->eofbit; }").
ccllib_sstream_fn(fail, "int @{N}_fail(const @N *s) { return s->fail; }").
ccllib_sstream_fn(eof, "int @{N}_eof(const @N *s) { return s->eofbit; }").
ccllib_sstream_fn(flush, "void @{N}_flush(@N *s) { (void)s; }").
%% a read skips the white space before its value; where none is left -- an empty stream, one whose buffer was never
%% made, among them (1.6.3: strtoll was handed the null buffer) -- it meets the end and fails, the object as it was
ccllib_sstream_in_fn('_skip', "static int @{N}__skip(@N *s) {
    while (s->pos < s->len && (s->buf[s->pos] == ' ' || (s->buf[s->pos] >= '\\t' && s->buf[s->pos] <= '\\r'))) s->pos++;
    if (s->pos < s->len) return 1;
    s->eofbit = 1; s->fail = 1; return 0;
}").
ccllib_sstream_in_fn(read_int, "@N *@{N}_read_int(@N *s, int *x) tie s { char *e; long long v; if (!s || s->fail || !@{N}__skip(s)) return 0; v = strtoll(s->buf + s->pos, &e, s->base == 16 ? 16 : s->base == 8 ? 8 : 10); if (e == s->buf + s->pos) { *x = 0; s->fail = 1; return 0; } *x = (int)v; s->pos = (size_t)(e - s->buf); if (s->pos >= s->len) s->eofbit = 1; return s; }").
ccllib_sstream_in_fn(read_uint, "@N *@{N}_read_uint(@N *s, unsigned *x) tie s { char *e; unsigned long long v; if (!s || s->fail || !@{N}__skip(s)) return 0; v = strtoull(s->buf + s->pos, &e, s->base == 16 ? 16 : s->base == 8 ? 8 : 10); if (e == s->buf + s->pos) { *x = 0; s->fail = 1; return 0; } *x = (unsigned)v; s->pos = (size_t)(e - s->buf); if (s->pos >= s->len) s->eofbit = 1; return s; }").
ccllib_sstream_in_fn(read_long, "@N *@{N}_read_long(@N *s, long *x) tie s { char *e; long v; if (!s || s->fail || !@{N}__skip(s)) return 0; v = strtol(s->buf + s->pos, &e, s->base == 16 ? 16 : s->base == 8 ? 8 : 10); if (e == s->buf + s->pos) { *x = 0; s->fail = 1; return 0; } *x = v; s->pos = (size_t)(e - s->buf); if (s->pos >= s->len) s->eofbit = 1; return s; }").
ccllib_sstream_in_fn(read_ulong, "@N *@{N}_read_ulong(@N *s, unsigned long *x) tie s { char *e; unsigned long v; if (!s || s->fail || !@{N}__skip(s)) return 0; v = strtoul(s->buf + s->pos, &e, s->base == 16 ? 16 : s->base == 8 ? 8 : 10); if (e == s->buf + s->pos) { *x = 0; s->fail = 1; return 0; } *x = v; s->pos = (size_t)(e - s->buf); if (s->pos >= s->len) s->eofbit = 1; return s; }").
ccllib_sstream_in_fn(read_llong, "@N *@{N}_read_llong(@N *s, long long *x) tie s { char *e; long long v; if (!s || s->fail || !@{N}__skip(s)) return 0; v = strtoll(s->buf + s->pos, &e, s->base == 16 ? 16 : s->base == 8 ? 8 : 10); if (e == s->buf + s->pos) { *x = 0; s->fail = 1; return 0; } *x = v; s->pos = (size_t)(e - s->buf); if (s->pos >= s->len) s->eofbit = 1; return s; }").
ccllib_sstream_in_fn(read_ullong, "@N *@{N}_read_ullong(@N *s, unsigned long long *x) tie s { char *e; unsigned long long v; if (!s || s->fail || !@{N}__skip(s)) return 0; v = strtoull(s->buf + s->pos, &e, s->base == 16 ? 16 : s->base == 8 ? 8 : 10); if (e == s->buf + s->pos) { *x = 0; s->fail = 1; return 0; } *x = v; s->pos = (size_t)(e - s->buf); if (s->pos >= s->len) s->eofbit = 1; return s; }").
ccllib_sstream_in_fn(read_double, "@N *@{N}_read_double(@N *s, double *x) tie s { char *e; double v; if (!s || s->fail || !@{N}__skip(s)) return 0; v = strtod(s->buf + s->pos, &e); if (e == s->buf + s->pos) { *x = 0; s->fail = 1; return 0; } *x = v; s->pos = (size_t)(e - s->buf); if (s->pos >= s->len) s->eofbit = 1; return s; }").
ccllib_sstream_in_fn(read_float, "@N *@{N}_read_float(@N *s, float *x) tie s { char *e; float v; if (!s || s->fail || !@{N}__skip(s)) return 0; v = (float)strtod(s->buf + s->pos, &e); if (e == s->buf + s->pos) { *x = 0; s->fail = 1; return 0; } *x = v; s->pos = (size_t)(e - s->buf); if (s->pos >= s->len) s->eofbit = 1; return s; }").
ccllib_sstream_in_fn(read_char, "@N *@{N}_read_char(@N *s, char *x) tie s { if (!s || s->fail || !@{N}__skip(s)) return 0; *x = s->buf[s->pos++]; return s; }").
ccllib_sstream_in_fn(get, "int @{N}_get(@N *s) { if (s->fail) return -1; if (s->pos < s->len) return (unsigned char)s->buf[s->pos++]; s->eofbit = 1; s->fail = 1; return -1; }").
ccllib_sstream_in_fn(getline, "char *@{N}_getline(@N *s, char *b, size_t n) {
    size_t k = 0;
    if (n == 0) { s->fail = 1; return 0; }
    b[0] = 0;
    if (s->fail) return 0;
    if (s->pos >= s->len) { s->eofbit = 1; s->fail = 1; return 0; }
    while (s->pos < s->len && k + 1 < n && s->buf[s->pos] != '\\n') b[k++] = s->buf[s->pos++];
    b[k] = 0;
    if (s->pos < s->len && s->buf[s->pos] == '\\n') s->pos++;
    else if (s->pos >= s->len) s->eofbit = 1;
    else { s->fail = 1; return 0; }
    return b;
}").
ccllib_sstream_in_fn(read, "size_t @{N}_read(@N *s, char *b, size_t n) { size_t k; if (s->fail) return 0; k = s->len - s->pos; if (k > n) k = n; if (k) memcpy(b, s->buf + s->pos, k); s->pos += k; if (k < n) { s->eofbit = 1; s->fail = 1; } return k; }").
