// A FUNCTION OF AN ANONYMOUS NAMESPACE IS WALKED (1.6.16): its leak is refused
namespace {
int twice(int x) { int *p = new int(x); return *p * 2; }
}
int main() { return twice(2) == 4 ? 0 : 1; }
