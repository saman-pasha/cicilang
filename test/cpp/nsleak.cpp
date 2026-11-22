// A NAMESPACE'S FUNCTION IS WALKED (1.6.16): its leak is refused as a function's at file scope is -- the check took the
// units' top level alone, and this was compiled
namespace ns {
int first(int x) {
    int *p = new int(x);
    if (x > 0) return *p;
    delete p;
    return 0;
}
}
int main() { return ns::first(0); }
