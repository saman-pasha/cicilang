// A BORROW OF A STATIC OWN ARRAY'S ELEMENT USED AFTER A CALL OF A NAMESPACE'S FUNCTION THAT STORES INTO THE ARRAY (1.6.16):
// the function's writes are known in a namespace too (0.307, static_borrow_call.c); it read what the store freed
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...) noexcept; }
struct thing { int v; };
static own thing *make(int v) noexcept {
    own thing *t = (thing *)malloc(sizeof *t);
    if (t) t->v = v;
    return t;
}
static own thing *slot[2];
namespace fill { void refill() noexcept { slot[0] = make(2); } }
int main() {
    slot[0] = make(1);
    thing *b = slot[0];
    fill::refill();
    if (b) printf("%d\n", b->v);
    free(slot[0]);
    return 0;
}
