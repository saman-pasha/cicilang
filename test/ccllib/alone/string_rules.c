/* THE RULES OF A STRING of <string.pl> (0.291), checked from outside over walks of chance, a string held after each
   step to a model, an array of bytes and its count. THE CHARACTERS AND THE COUNT ARE THE MODEL'S, each by c_str and by
   []; A NUL STANDS AFTER THE LAST CHARACTER; THE FORM: a string with no block holds fifteen characters at most in its
   object, and one with a block no more than its capacity, which the program reads in the instance's own fields; A
   GROWTH BY A CHANGE OF THE CHARACTERS IS TO TWICE THE CAPACITY AT LEAST, so that n push_backs cost O(n); AFTER
   shrink_to_fit the capacity is the count, or the object's fifteen for a short string, whose block is gone. The steps
   are each change that the module has, its source a text, a character, or a part of the string itself (append(s, s),
   insert(s, 0, c_str(s) + 2): a source in the string that the change moves); a character is a NUL one time in eight,
   and else any byte. Every eighth step, THE SEARCHES, THE COMPARISONS AND THE PARTS are the naive models': find, rfind
   and the four of a set of characters, from places in the string and past it, over a part of the string itself and a
   text of chance; starts_with, ends_with and contains; compare, ==, < and > as unsigned bytes and then by the count;
   substr and copy, their counts cut at the end. cicilang builds this file as C and cicilang++ as C++; both print
   string_rules.expect. It has no twin */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string.pl>
#define MAX 3000
static unsigned seed = 1;
static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static size_t checks;
static void no(const char *what) { printf("NOT HELD: %s\n", what); exit(1); }
static unsigned char m[MAX], mt[MAX], txt[64];
static size_t mn, mtn, tn;
static const char *const tx = (const char *)txt;
/* a text of chance in txt, tx as the text forms take it, with no NUL: the text forms read up to their NUL */
static void text(void) {
    tn = rnd() % 40;
    for (size_t i = 0; i < tn; i++) {
        unsigned r = rnd() % 10;
        txt[i] = (unsigned char)(r < 6 ? 'a' + r % 4 : 128 + rnd() % 127);
    }
    txt[tn] = 0;
}
/* the model's change: n1 characters at pos in the place of n2 of src, src copied first as the module does */
static void mput(unsigned char *a, size_t *an, size_t pos, size_t n1, const unsigned char *src, size_t n2) {
    unsigned char tmp[MAX];
    if (n1 > *an - pos) n1 = *an - pos;
    memcpy(tmp, src, n2);
    memmove(a + pos + n2, a + pos + n1, *an - pos - n1);
    memcpy(a + pos, tmp, n2);
    *an = *an - n1 + n2;
}
static int mcmp(const unsigned char *a, size_t n, const unsigned char *b, size_t k) {
    for (size_t i = 0; i < n && i < k; i++) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
    return n < k ? -1 : n > k;
}
static void held(const string *s, const unsigned char *a, size_t an) {
    checks++;
    if (size(*s) != an) no("the count is the model's");
    if (memcmp(c_str(*s), a, an) != 0) no("the characters are the model's, by c_str");
    for (size_t i = 0; i < an; i += 1 + an / 8)
        if ((unsigned char)(*s)[i] != a[i]) no("each character is the model's, by []");
    if (c_str(*s)[an] != 0) no("a NUL stands after the last character");
    if (s->data == 0 && s->len > 15) no("a string with no block holds fifteen characters at most");
    if (s->data != 0 && s->len > s->u.cap) no("a string with a block holds no more than its capacity");
    if (capacity(*s) != (s->data ? s->u.cap : 15)) no("the capacity is the block's, or the object's fifteen");
}
static size_t mfind(const unsigned char *n, size_t k, size_t pos) {
    if (pos > mn || k > mn - pos) return npos;
    for (size_t i = pos; i + k <= mn; i++) if (memcmp(m + i, n, k) == 0) return i;
    return npos;
}
static size_t mrfind(const unsigned char *n, size_t k, size_t pos) {
    if (k > mn) return npos;
    size_t i = mn - k < pos ? mn - k : pos;
    for (;; i--) { if (memcmp(m + i, n, k) == 0) return i; if (i == 0) return npos; }
}
static size_t mfirst(const unsigned char *n, size_t k, size_t pos, int in) {
    for (size_t i = pos; i < mn; i++) if ((memchr(n, m[i], k) != 0) == in) return i;
    return npos;
}
static size_t mlast(const unsigned char *n, size_t k, size_t pos, int in) {
    if (mn == 0) return npos;
    size_t i = mn - 1 < pos ? mn - 1 : pos;
    for (;; i--) { if ((memchr(n, m[i], k) != 0) == in) return i; if (i == 0) return npos; }
}
static void searches(const string *s, const string *t) {
    size_t pos = rnd() % (mn + 4), at = mn ? rnd() % mn : 0, k = mn ? rnd() % (mn - at + 1) : 0;
    if (rnd() % 8 == 0) pos = npos;
    string part = substr(*s, at, k);
    unsigned char c = (unsigned char)(rnd() % 8 ? rnd() % 256 : 0);
    text();
    checks++;
    if (find(*s, part, pos) != mfind(m + at, k, pos)) no("find of a part of the string itself is the model's");
    if (find(*s, tx, pos) != mfind(txt, tn, pos)) no("find of a text is the model's");
    if (find(*s, (char)c, pos) != mfind(&c, 1, pos)) no("find of a character is the model's");
    if (rfind(*s, part, pos) != mrfind(m + at, k, pos)) no("rfind of a part is the model's");
    if (rfind(*s, tx, pos) != mrfind(txt, tn, pos)) no("rfind of a text is the model's");
    if (find_first_of(*s, tx, pos) != mfirst(txt, tn, pos, 1)) no("find_first_of is the model's");
    if (find_first_not_of(*s, tx, pos) != mfirst(txt, tn, pos, 0)) no("find_first_not_of is the model's");
    if (find_last_of(*s, tx, pos) != mlast(txt, tn, pos, 1)) no("find_last_of is the model's");
    if (find_last_not_of(*s, tx, pos) != mlast(txt, tn, pos, 0)) no("find_last_not_of is the model's");
    if (starts_with(*s, part) != (memcmp(m, m + at, k) == 0)) no("starts_with of a part is the model's");
    if (starts_with(*s, (char)c) != (mn > 0 && m[0] == c)) no("starts_with of a character is the model's");
    if (ends_with(*s, tx) != (tn <= mn && memcmp(m + mn - tn, txt, tn) == 0)) no("ends_with of a text is the model's");
    if (contains(*s, tx) != (mfind(txt, tn, 0) != npos)) no("contains of a text is the model's");
    int r = mcmp(m, mn, mt, mtn), q = compare(*s, *t);
    if ((q > 0) - (q < 0) != r) no("compare is the model's, by unsigned bytes and then by the count");
    if ((*s == *t) != (r == 0) || (*s < *t) != (r < 0) || (*s > *t) != (r > 0)) no("==, < and > go by compare");
    size_t n2 = rnd() % (mn + 3), a2 = mn ? rnd() % (mn + 1) : 0, cut = n2 > mn - a2 ? mn - a2 : n2;
    q = compare(*s, a2, n2, tx);
    if ((q > 0) - (q < 0) != mcmp(m + a2, cut, txt, tn)) no("compare of a part with a text cuts the part at the end");
    string u = substr(*s, a2, n2);
    if (size(u) != cut || memcmp(c_str(u), m + a2, cut) != 0) no("substr cuts its count at the end");
    char buf[MAX];
    if (copy(*s, buf, n2, a2) != cut || memcmp(buf, m + a2, cut) != 0) no("copy cuts its count at the end");
}
static void walk(unsigned start, long steps) {
    string s, t;
    seed = start;
    mn = mtn = 0;
    held(&s, m, mn);
    for (long step = 0; step < steps; step++) {
        size_t cap = capacity(s), pos = rnd() % (mn + 1), n = rnd() % 12, at = mn ? rnd() % mn : 0;
        size_t k = mn ? rnd() % (mn - at + 1) : 0;
        unsigned char c = (unsigned char)(rnd() % 8 ? rnd() % 256 : 0);
        int grows = 1, op = (int)(rnd() % 21);
        if (mn > MAX / 2) op = 6;
        switch (op) {
        case 0: push_back(s, (char)c); m[mn++] = c; break;
        case 1:
            if (mn) { if ((unsigned char)pop_back(s) != m[mn - 1]) no("pop_back gives the last character"); mn--; }
            break;
        case 2: text(); append(s, tx); mput(m, &mn, mn, 0, txt, tn); break;
        case 3: append(s, s, at, k); mput(m, &mn, mn, 0, m + at, k); break;
        case 4: text(); insert(s, pos, tx); mput(m, &mn, pos, 0, txt, tn); break;
        case 5: insert(s, pos, s, at, k); mput(m, &mn, pos, 0, m + at, k); break;
        case 6: { size_t e = n + (mn > MAX / 2 ? mn / 2 : 0); erase(s, pos, e); mput(m, &mn, pos, e, m, 0); } break;
        case 7: text(); replace(s, pos, n, tx); mput(m, &mn, pos, n, txt, tn); break;
        case 8: replace(s, pos, n, s, at, k); mput(m, &mn, pos, n, m + at, k); break;
        case 9: text(); assign(s, tx); mput(m, &mn, 0, mn, txt, tn); break;
        case 10: assign(s, s, at, k); mput(m, &mn, 0, mn, m + at, k); break;
        case 11: { size_t r = rnd() % 60; resize(s, r, (char)c); while (mn < r) m[mn++] = c; mn = r; } break;
        case 12: clear(s); mn = 0; break;
        case 13:
            shrink_to_fit(s);
            if (mn <= 15 ? s.data != 0 || capacity(s) != 15 : capacity(s) != mn)
                no("after shrink_to_fit the capacity is the count, or fifteen for a short string with no block");
            break;
        case 14: {
            size_t r = rnd() % 200;
            reserve(s, r);
            grows = 0;
            if (capacity(s) < r) no("reserve gives the capacity asked");
        } break;
        case 15: {
            unsigned char tmp[MAX];
            size_t tmpn = mn;
            swap(s, t);
            memcpy(tmp, m, mn); memcpy(m, mt, mtn); memcpy(mt, tmp, tmpn); mn = mtn; mtn = tmpn;
            grows = 0;
            held(&t, mt, mtn);
        } break;
        case 16: {
            size_t gone = erase_value(s, (char)m[at]), w = 0, was = mn;
            unsigned char d = mn ? m[at] : 0;
            for (size_t i = 0; i < mn; i++) if (m[i] != d) m[w++] = m[i];
            mn = was ? w : 0;
            if (was && gone != was - w) no("erase_value gives the count of the characters it takes away");
        } break;
        case 17: if (mn < MAX / 4) { s += s; mput(m, &mn, mn, 0, m, mn); } break;
        case 18: {
            unsigned char f[16];
            insert(s, pos, n, (char)c);
            memset(f, c, n);
            mput(m, &mn, pos, 0, f, n);
        } break;
        case 19: {
            size_t z = at;
            append(s, c_str(s) + at);
            while (z < mn && m[z]) z++;
            mput(m, &mn, mn, 0, m + at, z - at);
        } break;
        default: text(); assign(t, tx); mtn = tn; memcpy(mt, txt, tn); grows = 0; held(&t, mt, mtn); break;
        }
        held(&s, m, mn);
        if (grows && capacity(s) > cap && capacity(s) < 2 * cap)
            no("a growth by a change of the characters is to twice the capacity at least");
        if (step % 8 == 0) searches(&s, &t);
    }
}
int main(void) {
    walk(1, 4000);
    walk(7, 4000);
    walk(42, 4000);
    walk(1234, 4000);
    walk(99991, 4000);
    printf("the rules held at %zu checks, over five walks of 4000 steps\n", checks);
    return 0;
}
