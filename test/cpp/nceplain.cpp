int g() { return 3; }
static_assert(g() == 3);
int main() { return g(); }
