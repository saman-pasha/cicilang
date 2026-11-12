// A BORROW READ AFTER A CALL THAT MAY REPLACE ITS OWNER, THROUGH A POINTER, IN C++ (0.303; the rule of 0.265 to 0.272):
// p borrows v.data through pv, and pv->grow may realloc it
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
    Buf *pv = &v;
    int *p = &pv->data[0];
    int x = 0;
    pv->grow(&x);
    printf("%d\n", *p);
    return 0;
}
