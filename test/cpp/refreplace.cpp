// ... and an lvalue bound to a reference parameter that is not const is handed by its address ([dcl.init.ref]/5; 0.272):
// grow2(v) may replace v's buffer as C's grow(&v) may
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void *realloc(void *, size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...); }
struct Buf {
    size_t len; own int *data;
    Buf() : len(2), data((own int *) malloc(2 * sizeof(int))) { data[0] = 7; data[1] = 8; }
    ~Buf() { free(data); }
    void grow() { data = (own int *) realloc(data, 2 * len * sizeof(int)); len *= 2; }
    size_t size() const { return len; }
};
void grow2(Buf &b) { b.grow(); }
int main() {
    Buf v;
    int *p = v.data;
    grow2(v);
    printf("%d\n", *p);
    return 0;
}
