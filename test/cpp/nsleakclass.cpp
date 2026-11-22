// A MEMBER OF A CLASS IN NESTED NAMESPACES IS WALKED (1.6.16): its leak at the scope's end is refused
namespace a { namespace b {
struct Counter {
    int n = 0;
    void bump(int x) { int *p = new int(x); n += *p; }
};
} }
int main() { a::b::Counter c; c.bump(2); return c.n == 2 ? 0 : 1; }
