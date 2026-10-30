/* the driver gate's -E text against clang's: literals, digraphs and #x as written (0.228) */
%:define S(a) #a
%:define X(a) S(a)
int a<:2:> = <%1, 2%>;
int caf\u00e9 = 7;
const char *p = S(caf\u00e9), *q = "caf\u00e9", *r = "\x41", *s = S("\x41"), *t = S(a <: b), *u = X(S(caf\U000000E9));
const char *w = u8"\u00e9", *y = "a\tb" "\101";
int c = '\x41' + L'\u00e9' + 'ab', d = 0x1F + 010 + 1e3 + 0x1p4;
int e = caf\u00e9 + café;
