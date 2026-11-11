// ... and through a reference to const, spelled as clang spells it, 'const Buf &' (0.272)
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void *realloc(void *, size_t) noexcept; void free(void *) noexcept; int printf(const char *, ...); }
struct Buf {
    size_t len; own int *data;
    Buf() : len(2), data((own int *) malloc(2 * sizeof(int))) { data[0] = 7; data[1] = 8; }
    ~Buf() { free(data); }
    void grow() { data = (own int *) realloc(data, 2 * len * sizeof(int)); len *= 2; }
    size_t size() const { return len; }
};
void bad_set(const Buf &b) { free(b.data); b.data = (own int *) malloc(sizeof(int)); }
int main() { Buf v; bad_set(v); return 0; }
