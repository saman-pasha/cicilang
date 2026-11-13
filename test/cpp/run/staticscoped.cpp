// OWN ARRAYS OF STATIC STORAGE IN C++ (0.307): a namespace's own array, named by its qualified name, and a class's
// static own array member are own arrays to the check, as one at file scope is -- an element taken by move(), which
// empties its slot, a store that frees the old element, an element handed to free. Valgrind finds no error and
// nothing lost
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...) noexcept; }
struct thing { int v; };
static own thing *make(int v) noexcept {
    own thing *t = (thing *)malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
namespace store { own thing *slot[2]; }
struct pool { static own thing *slot[2]; };
own thing *pool::slot[2];
int main() {
    store::slot[0] = make(1);
    own thing *out = move(store::slot[0]);
    store::slot[0] = make(2);
    store::slot[0] = make(3);
    printf("%d %d\n", out ? out->v : 0, store::slot[0] ? store::slot[0]->v : 0);
    free(out);
    pool::slot[1] = make(4);
    own thing *in = move(pool::slot[1]);
    pool::slot[1] = make(5);
    printf("%d %d\n", in ? in->v : 0, pool::slot[1] ? pool::slot[1]->v : 0);
    free(in);
    free(store::slot[0]);
    free(pool::slot[1]);
    return 0;
}
