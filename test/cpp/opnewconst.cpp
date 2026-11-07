constexpr int k() { int *p = static_cast<int *>(::operator new(sizeof(int))); *p = 4; int r = *p; ::operator delete(p); return r; }
static_assert(k() == 4);
int main() { return k(); }
