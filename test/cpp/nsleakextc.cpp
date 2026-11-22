// A FUNCTION OF AN `extern "C"' BLOCK IS WALKED (1.6.16), in a namespace or at file scope: its leak is refused
namespace io { extern "C" { int c_side(int x) { int *p = new int(x); return *p + 1; } } }
int main() { return c_side(1) == 2 ? 0 : 1; }
