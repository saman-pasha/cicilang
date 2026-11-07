constexpr double dz(double x) { return 1.0 / x; }
static_assert(dz(0.0) > 0);
int main() { return 0; }
