// A returned member, global or reference is copied ([class.copy.elision]/3: only a local or a parameter is implicitly
// movable), a returned local is moved or elided
#include <cstdio>
#include <string>
struct W { std::string s = "kept"; std::string get() { return s; } std::string &ref() { return s; } };
std::string g = "global";
std::string fromglobal() { return g; }
std::string fromref(std::string &r) { return r; }
std::string fromptr(std::string *p) { return *p; }
std::string fromlocal() { std::string l = "local"; return l; }
int main() {
    W w; std::string a = w.get(); std::string b = w.get();
    std::printf("%s %s %s\n", a.c_str(), b.c_str(), w.s.c_str());
    std::string c = fromglobal(); std::string d = fromglobal();
    std::printf("%s %s %s\n", c.c_str(), d.c_str(), g.c_str());
    std::string x = "refd"; std::string e = fromref(x); std::string f = fromptr(&x);
    std::printf("%s %s %s %s\n", e.c_str(), f.c_str(), x.c_str(), fromlocal().c_str());
}
