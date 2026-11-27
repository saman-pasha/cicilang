/* staticrecords.c -- records that carry a pointer, answered by a function whose every return is static storage, and
   local records copied from static storage, and local records filled with static values and returned (1.6.35), built
   as C and as C++: each was `no owner behind: 't'' at the caller, where clang builds it. */
#include <stdio.h>
#include <string.h>

struct tok { const char *s; int n; };
struct named { char name[8]; const char *tag; };

static struct tok toks[] = { { "alpha", 1 }, { "beta", 2 }, { "gamma", 3 } };
static struct tok fallback = { "none", 0 };
static struct named names[] = { { "one", "first" }, { "two", "second" } };

/* an element of a static table */
static struct tok pick(int i) { return toks[i]; }
/* a global record, or an element, by a condition */
static struct tok pick_or(int i) { if (i < 0 || i > 2) return fallback; return toks[i]; }
/* a call of another such function */
static struct tok next_of(int i) { return pick(i + 1); }
/* a static local's record */
static struct tok counter(void) { static struct tok c = { "count", 7 }; return c; }
/* a local record filled with static values, in order and by designators */
static struct tok made(int n) { struct tok t = { "made", n }; return t; }
static struct tok sized(int n) { struct tok t = { .s = n > 2 ? "big" : "small", .n = n }; return t; }

int main(void) {
    struct tok a = pick(0), b = pick_or(9), c = next_of(1), d = counter();
    struct tok e;
    e = pick(1);
    struct tok f = toks[2];
    struct tok g = f;
    const char *s = g.s;
    struct tok m = made(4), z = sized(1);
    struct named h = names[1];
    char *own_copy = h.name;   /* an array member is the local's own storage */
    own_copy[0] = 'T';
    printf("%s %d %s %d %s %d %s %d %s %s %s %s\n", a.s, a.n, b.s, b.n, c.s, c.n, d.s, d.n, e.s, s, h.name, h.tag);
    printf("%s %d %s %d\n", m.s, m.n, z.s, z.n);
    return (int) strlen(names[1].name) - 3;
}
