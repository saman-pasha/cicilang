// Two member templates of one name and one parameter list, told apart by a SFINAE default alone and DEFINED OUT OF
// CLASS (libc++ 18's __split_buffer::__construct_at_end and vector::insert): each declaration takes the definition whose
// template parameters agree with its own -- compared in the class's words, the declaration's guard written over the
// class's typedef and the definition's over the template's parameter; and the defaults come from the declaration.
#include <cstdio>
#include <type_traits>
template <class T> struct Buf {
    typedef T value_type;
    int n;
    template <class I, std::enable_if_t<std::is_pointer<I>::value && std::is_same<value_type, int>::value, int> = 0> void fill(I a, I b);
    template <class I, std::enable_if_t<!std::is_pointer<I>::value && std::is_same<value_type, int>::value, int> = 0> void fill(I a, I b);
    void go() { int xs[2]; fill(xs, xs + 2); }
};
template <class T> template <class I, std::enable_if_t<std::is_pointer<I>::value && std::is_same<T, int>::value, int>> void Buf<T>::fill(I a, I b) { n = (int) (b - a); }
template <class T> template <class I, std::enable_if_t<!std::is_pointer<I>::value && std::is_same<T, int>::value, int>> void Buf<T>::fill(I a, I b) { n = b - a + 100; }
int main() {
    Buf<int> b; int xs[3];
    b.fill(xs, xs + 3); printf("%d\n", b.n);
    b.fill(2, 5); printf("%d\n", b.n);
    b.go(); printf("%d\n", b.n);
    return 0;
}
