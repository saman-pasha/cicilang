// WHAT THE SAFETY RULES OF 0.265 TO 0.267 LET C++ KEEP (0.272): a const member function and a reference to const keep
// the caller's borrow of the object's buffer; a borrow taken again after a call that may replace it is good; an
// element's address is a borrow of the buffer; a null own field that a call may fill is freed after it
#include <cstdio>
#include <cstdlib>
struct Buf {
    size_t len; own int *data;
    Buf() : len(2), data((own int *) malloc(2 * sizeof(int))) { data[0] = 7; data[1] = 8; }
    ~Buf() { free(data); }
    void grow() { data = (own int *) realloc(data, 2 * len * sizeof(int)); len *= 2; }
    size_t size() const { return len; }
};
size_t len_of(const Buf &b) { return b.len; }
void grow2(Buf &b) { b.grow(); }
struct Slot { own int *d; };
void fill(Slot &s) noexcept { if (!s.d) { s.d = (own int *) malloc(sizeof(int)); *s.d = 5; } }
int main() {
    Buf v;
    int *p = v.data;
    size_t n = v.size();
    std::printf("%d %zu\n", *p, n);
    int *q = &v.data[1];
    std::printf("%d %zu\n", *q, len_of(v));
    v.grow();
    p = v.data;
    std::printf("%d %zu\n", *p, v.size());
    grow2(v);
    q = &v.data[1];
    std::printf("%d %zu\n", *q, v.size());
    Slot s = { nullptr };
    fill(s);
    std::printf("%d\n", *s.d);
    free(s.d);
    return 0;
}
