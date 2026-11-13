// AN OWN ARRAY OF A NAMESPACE, ITS ELEMENT GIVEN TO AN OWNER WITH NO MOVE (0.307): store::slot[0] is an element of the
// namespace's own array, which the store after it frees -- over 0.306 the C finding's double free, in C++
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...) noexcept; }
struct thing { int v; };
static own thing *make(int v) noexcept {
    own thing *t = (thing *)malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
namespace store { own thing *slot[2]; }
int main() {
    store::slot[0] = make(1);
    own thing *out = store::slot[0];
    store::slot[0] = make(2);
    if (out) printf("%d\n", out->v);
    free(out);
    free(store::slot[0]);
    return 0;
}
