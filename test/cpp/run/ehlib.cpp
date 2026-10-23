// libc++ in its exceptions configuration (0.193): what its headers throw, and what the compiled library throws, is
// caught by the program -- a vector's and a map's `at', an optional's `value', an empty function called, a variant's
// wrong alternative, a string's `substr', `stoi' -- and the destructors of the scopes left run on the way; a failed
// `dynamic_cast' to a reference throws std::bad_cast, and `typeid(*p)' of a null p std::bad_typeid
#include <cstdio>
#include <functional>
#include <map>
#include <optional>
#include <stdexcept>
#include <string>
#include <typeinfo>
#include <variant>
#include <vector>

struct Guard {
    const char *n;
    ~Guard() { std::printf("~Guard %s\n", n); }
};

struct Base {
    virtual ~Base() {}
};
struct Der : Base {};

int deep(const std::vector<int> &v, int i) {
    Guard g{"deep"};
    return v.at(i);
}

int main() {
    std::vector<int> v{1, 2, 3};
    try {
        Guard g{"at"};
        std::printf("%d\n", v.at(5));
    } catch (const std::out_of_range &) {
        std::printf("out_of_range\n");
    }
    try {
        std::printf("%d\n", deep(v, 1) + deep(v, 9));
    } catch (const std::exception &) {
        std::printf("caught through deep\n");
    }
    std::optional<int> o;
    try {
        std::printf("%d\n", o.value());
    } catch (const std::bad_optional_access &) {
        std::printf("bad_optional_access\n");
    }
    std::function<int()> f;
    try {
        std::printf("%d\n", f());
    } catch (const std::bad_function_call &) {
        std::printf("bad_function_call\n");
    }
    std::variant<int, std::string> w = 5;
    try {
        std::printf("%s\n", std::get<std::string>(w).c_str());
    } catch (const std::bad_variant_access &) {
        std::printf("bad_variant_access\n");
    }
    std::string s = "abc";
    try {
        std::printf("%s\n", s.substr(10).c_str());
    } catch (const std::out_of_range &) {
        std::printf("substr out_of_range\n");
    }
    std::map<int, int> m{{1, 2}};
    try {
        std::printf("%d\n", m.at(7));
    } catch (const std::out_of_range &) {
        std::printf("map out_of_range\n");
    }
    try {
        std::printf("%d\n", std::stoi("x"));
    } catch (const std::invalid_argument &) {
        std::printf("invalid_argument\n");
    }
    Base b;
    Base &rb = b;
    try {
        Der &d = dynamic_cast<Der &>(rb);
        std::printf("cast %p\n", (void *) &d);
    } catch (const std::bad_cast &) {
        std::printf("bad_cast\n");
    }
    Base *pb = nullptr;
    try {
        std::printf("%s\n", typeid(*pb).name());
    } catch (const std::bad_typeid &) {
        std::printf("bad_typeid\n");
    }
    return 0;
}
