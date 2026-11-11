// A RESULT TIED TO AN OBJECT WITH OWN FIELDS IS A BORROW OF THEM, IN C++ TOO (0.272): at's result is tied to its reference
// parameter, a place in v's buffer, which the call that may replace the buffer ends
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void *realloc(void *, size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...); }
struct Buf {
    size_t len; own int *data;
    Buf() : len(2), data((own int *) malloc(2 * sizeof(int))) { data[0] = 7; data[1] = 8; }
    ~Buf() { free(data); }
    void grow() { data = (own int *) realloc(data, 2 * len * sizeof(int)); len *= 2; }
    size_t size() const { return len; }
};
int *at(Buf &b, size_t i) tie b { return &b.data[i]; }
int main() {
    Buf v;
    int *p = at(v, 1);
    v.grow();
    printf("%d\n", *p);
    return 0;
}
