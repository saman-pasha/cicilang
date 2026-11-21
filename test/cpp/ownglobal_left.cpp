// a read refused inside a member's body, its class's names in the frame (1.6.9): the reader gate's k172 reads
// ownglobal_next.cpp after it, in the same process
struct S { void println(const char *s) const {} void f() const { print(7); } };
