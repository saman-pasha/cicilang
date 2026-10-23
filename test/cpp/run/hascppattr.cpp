#include <cstdio>
#define Q(x) (long) __has_cpp_attribute(x)
#if __has_cpp_attribute(nodiscard) >= 201907L
#define ND "nd"
#else
#define ND "no"
#endif
int main() {
    std::printf("%ld %ld %ld %ld %ld %ld\n", Q(nodiscard), Q(no_unique_address), Q(fallthrough), Q(__likely__), Q(maybe_unused), Q(nonsense));
    std::printf("%s %d %d\n", ND, (int) __has_builtin(__builtin_expect), (int) (__has_cpp_attribute(deprecated) > 0));
}
