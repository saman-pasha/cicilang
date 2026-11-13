// A CLASS'S STATIC OWN ARRAY MEMBER, ITS ELEMENT GIVEN TO AN OWNER WITH NO MOVE (0.307): pool::slot[0] is an element of
// an own array of static storage, which the store after it frees -- over 0.306 a double free
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...) noexcept; }
struct thing { int v; };
static own thing *make(int v) noexcept {
    own thing *t = (thing *)malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
struct pool { static own thing *slot[2]; };
own thing *pool::slot[2];
int main() {
    pool::slot[0] = make(1);
    own thing *out = pool::slot[0];
    pool::slot[0] = make(2);
    if (out) printf("%d\n", out->v);
    free(out);
    free(pool::slot[0]);
    return 0;
}
