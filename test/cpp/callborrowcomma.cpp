// A BORROW HANDED TO A CALL THAT MAY REPLACE ITS OWNER, THE CALL'S OBJECT A COMMA (1.6.13): `(g(), v)' is v in C++, so
// callborrow.cpp's refusal holds through it
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void *realloc(void *, size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...); }
struct Buf {
    size_t len; own int *data;
    Buf() : len(2), data((own int *) malloc(2 * sizeof(int))) { data[0] = 7; data[1] = 8; }
    ~Buf() { free(data); }
    void grow(int *out) { data = (own int *) realloc(data, 2 * len * sizeof(int)); len *= 2; *out = 9; }
};
int g() noexcept { return 0; }
int main() {
    Buf v;
    (g(), v).grow(&v.data[0]);
    printf("%d\n", v.data[0]);
    return 0;
}
