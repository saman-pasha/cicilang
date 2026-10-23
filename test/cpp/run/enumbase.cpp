// AN ENUM'S UNDERLYING TYPE NAMED THROUGH ITS NAMESPACE (0.194): `enum class Color : std::uint8_t' is one byte, its values the
// base's; the lowering met `typedef(scoped([std], uint8_t))'
#include <cstdint>
#include <cstdio>
enum class Color : std::uint8_t { R, G, B = 200 };
enum class Big : std::uint64_t { V = 1ull << 40 };
enum Plain : std::int16_t { P1 = -3 };
struct S { Color c; Big b; };
int main() {
    Color c = Color::B;
    std::printf("%d %d %d %d %d\n", (int) sizeof(Color), (int) c, (int) sizeof(Big), (int) sizeof(Plain), (int) P1);
    S s{Color::G, Big::V};
    std::printf("%d %llu %d\n", (int) s.c, (unsigned long long) s.b, (int) sizeof(S));
    return 0;
}
