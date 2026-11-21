// A REFERENCE BOUND TO A COMMA OVER AN OBJECT (1.6.13) borrows the object: `Buf &w = (g(), v); w.grow();' may replace
// v's buffer, as `Buf &w = v;' does, and the borrow p taken before is not read after
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void *realloc(void *, size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...); }
struct Buf {
    size_t len; own int *data;
    Buf() : len(2), data((own int *) malloc(2 * sizeof(int))) { data[0] = 7; data[1] = 8; }
    ~Buf() { free(data); }
    void grow() { data = (own int *) realloc(data, 2 * len * sizeof(int)); len *= 2; }
    size_t size() const { return len; }
};
int g() noexcept { return 0; }
int main() {
    Buf v;
    int *p = v.data;
    Buf &w = (g(), v); w.grow();
    printf("%d\n", *p);
    return 0;
}
