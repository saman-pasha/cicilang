// ... AND THROUGH A LOCAL REFERENCE (0.303): r.data over Buf &r = v is v.data -- its member had no type to the check,
// which sees a reference as the pointer it is, so &r.data[0] took the road of an array's element and borrowed v
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void *realloc(void *, size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...); }
struct Buf {
    size_t len; own int *data;
    Buf() : len(2), data((own int *) malloc(2 * sizeof(int))) { data[0] = 7; data[1] = 8; }
    ~Buf() { free(data); }
    void grow(int *out) { data = (own int *) realloc(data, 2 * len * sizeof(int)); len *= 2; *out = 9; }
};
int main() {
    Buf v;
    Buf &r = v;
    r.grow(&r.data[0]);
    printf("%d\n", v.data[0]);
    return 0;
}
