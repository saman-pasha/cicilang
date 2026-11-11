// AN OWN FIELD OF A CONST OBJECT IS NOT ASSIGNED, IN C++ TOO (0.272; [dcl.type.cv]/4, [class.this]/1): a const member
// function's `this' points to a const object -- so the caller keeps its borrows across the call -- and the assignment is
// refused in clang's words
typedef unsigned long size_t;
extern "C" { void *malloc(size_t) noexcept; void free(void *) noexcept; }
struct Buf {
    size_t len; own int *data;
    Buf() : len(1), data((own int *) malloc(sizeof(int))) {}
    ~Buf() { free(data); }
    void bad() const { free(data); data = (own int *) malloc(sizeof(int)); }
};
int main() { Buf v; v.bad(); return 0; }
