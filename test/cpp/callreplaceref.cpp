// ... AND THROUGH A LOCAL REFERENCE (0.303)
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
    int *p = &r.data[1];
    int x = 0;
    r.grow(&x);
    printf("%d\n", *p);
    return 0;
}
