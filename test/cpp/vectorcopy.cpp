#include <vector>
struct NC { NC() = default; NC(const NC &) = delete; NC(NC &&) = default; };
int main() { std::vector<NC> v; NC a; v.push_back(a); return (int)v.size(); }
