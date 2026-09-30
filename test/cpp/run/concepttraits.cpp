// C++20's iterator and reference traits on libc++: indirectly_readable_traits chosen among constrained partial
// specializations, iter_value_t and iter_reference_t, common_reference over references (a decltype of a conditional),
// and a parameter whose type is a decltype over an earlier parameter.
#include <concepts>
#include <cstdio>
#include <iterator>
#include <type_traits>
#include <vector>
template <class A, class B> struct same { static constexpr int v = 0; };
template <class A> struct same<A, A> { static constexpr int v = 1; };
template <class T> struct cond { using value_type = T; };
template <class T> struct traits : cond<typename T::value_type> {};
struct It { using value_type = int; };
using CR = std::common_reference_t<int &, const int &>;
int *up(int *p) { return p; }
template <class I> I rw(I orig, decltype(up(orig)) it) { return orig + (it - orig) + 1; }
int main() {
    using W = std::vector<int>::iterator;
    std::printf("%d %d %d\n", same<traits<It>::value_type, int>::v, same<std::iter_value_t<W>, int>::v, same<std::iter_reference_t<W>, int &>::v);
    std::printf("%d\n", same<std::indirectly_readable_traits<W>::value_type, int>::v);
    std::printf("%d %d %d\n", same<std::common_reference_t<int &, const int &>, const int &>::v,
                same<std::common_reference_t<const int &, int &>, const int &>::v, (int) std::common_reference_with<int &, const int &>);
    std::printf("%d %d\n", same<std::common_reference_t<int &&, int &>, const int &>::v, same<std::common_reference_t<int, long>, long>::v);
    std::printf("%d %d %d\n", same<CR, const int &>::v, (int) std::is_same_v<CR, const int &>, (int) std::is_reference_v<CR>);
    int arr[3] = {4, 5, 6};
    std::printf("%d\n", *rw(arr, arr + 1));
    return 0;
}
