// C++26's std::is_virtual_base_of (libc++ 21, over clang's __builtin_is_virtual_base_of; 0.194): a virtual base at any
// depth, cv-qualifiers aside; a plain base, the class itself and an unrelated class are none
#include <cstdio>
#include <type_traits>
struct A { int a; };
struct B : virtual A { int b; };
struct C : B { int c; };
struct D : A { int d; };
struct E : virtual B { };
struct U { };
int main() {
    std::printf("%d %d %d %d %d %d %d %d\n", (int) std::is_virtual_base_of_v<A, B>, (int) std::is_virtual_base_of_v<A, C>,
                (int) std::is_virtual_base_of_v<A, D>, (int) std::is_virtual_base_of_v<B, C>, (int) std::is_virtual_base_of_v<const A, volatile C>,
                (int) std::is_virtual_base_of_v<A, A>, (int) std::is_virtual_base_of_v<U, C>, (int) std::is_virtual_base_of<B, E>::value);
    return 0;
}
