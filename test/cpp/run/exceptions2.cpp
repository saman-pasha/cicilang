#include <cstdio>
#include <stdexcept>
#include <string>
#include <vector>
static int parse(const std::string &s) {
    if (s.empty()) throw std::invalid_argument("empty");
    if (s[0] == '-') throw std::runtime_error("negative: " + s);
    return (int) s.size();
}
struct Tracker { std::vector<int> v; ~Tracker() { std::printf("tracker %zu\n", v.size()); } };
static int work(int n) {
    Tracker t; std::string label = "work";
    for (int i = 0; i < n; i++) t.v.push_back(i);
    if (n > 2) throw std::out_of_range(label + " too big");
    return n;
}
int main() {
    const char *in[3] = { "abc", "", "-x" };
    for (int i = 0; i < 3; i++) {
        try { std::printf("%d\n", parse(in[i])); }
        catch (const std::invalid_argument &e) { std::printf("invalid: %s\n", e.what()); }
        catch (const std::exception &e) { std::printf("error: %s\n", e.what()); }
    }
    try { work(2); work(5); } catch (const std::logic_error &e) { std::printf("logic: %s\n", e.what()); }
    return 0;
}
