// An rvalue binds no `W &' ([over.ics.ref]/3): the free operator is no candidate, and no other is (1.6.6)
struct W { int x; };
W &operator+=(W &a, int b) { a.x += b; return a; }
int main() {
    W w = W{} += 1;
    return w.x;
}
