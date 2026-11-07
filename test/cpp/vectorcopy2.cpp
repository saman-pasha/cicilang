#include <vector>
struct NC { int k; NC(int x) : k(x) {} NC(const NC &) = delete; NC(NC &&) = default; };
int main() { std::vector<NC> v; v.emplace_back(1); NC a(2); v.push_back(a); return (int)v.size(); }
