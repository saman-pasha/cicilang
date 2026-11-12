// WHAT THE RULES OF 0.303 KEEP (0.303): a borrow through a pointer to ANOTHER object is no borrow of the one a call may
// replace, and a borrow read again after the call, through the pointer or the reference, is a new one
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void *realloc(void *, size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...); }
struct Buf {
    size_t len; own int *data;
    Buf() : len(2), data((own int *) malloc(2 * sizeof(int))) { data[0] = 7; data[1] = 8; }
    ~Buf() { free(data); }
    void grow(int *out) { data = (own int *) realloc(data, 2 * len * sizeof(int)); len *= 2; *out = 9; }
};
int main() {
    Buf v, w;
    Buf *pw = &w;
    Buf &rv = v;
    int x = 0;
    v.grow(&pw->data[0]);
    w.grow(&x);
    rv.grow(&x);
    int *p = &rv.data[1];
    printf("%d %d %d %d\n", v.data[0], w.data[0], x, *p);
    return 0;
}
