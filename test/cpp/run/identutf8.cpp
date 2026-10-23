// Identifiers past ASCII ([lex.name], C++23; clang++ reads them at C++17 too): UTF-8 and universal character names, a
// namespace's, a class's, a member's, a template's and a lambda's, the Itanium symbols their UTF-8 bytes counted in
// bytes (`_ZN3ñs6naïveEi'), the type information's name, `__func__', a parameter and a label (0.196)
#include <cstdio>
#include <cstring>
#include <typeinfo>
#include <string>
namespace ñs {
    int naïve(int x) { return x + 1; }
    struct Größe { int größe = 4; int get() const { return größe; } static int zähler; };
    int Größe::zähler = 9;
    template <class T> T doppelt(T v) { return v * 2; }
}
static int fläche(ñs::Größe grö, int ñ) { if (ñ < 0) goto zurück; return grö.get() * ñ; zurück: return -1; }
struct Ω { virtual ~Ω() {} virtual const char *wer() const { return __func__; } };
struct Ψ : Ω { const char *wer() const override { return __func__; } };
int main() {
    ñs::Größe g;
    auto λ = [](int v) { return v * 2; };
    int π = 3;
    std::printf("%d %d %d %d %d\n", ñs::naïve(1), g.get(), λ(5), π, ñs::Größe::zähler);
    std::printf("%d %.1f\n", ñs::doppelt(21), ñs::doppelt(1.25));
    std::printf("%s %zu\n", typeid(ñs::Größe).name(), std::strlen(typeid(ñs::Größe).name()));
    Ψ p; const Ω &r = p;
    std::printf("%s %s %d\n", r.wer(), typeid(r).name(), (int) (typeid(r) == typeid(Ψ)));
    std::string s = "größe"; std::printf("%zu\n", s.size());
    std::printf("%d %d %d\n", \u00f1s::na\u00efve(2), \u03c0, \u00f1s::Gr\u00f6\u00dfe::z\u00e4hler);
    std::printf("%d %d\n", fläche(g, 3), fläche(g, -1));
    return 0;
}
