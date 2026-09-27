// A scoped name that is a TYPE of its class, written as a template argument in an EXPRESSION: the reader gives the
// value form, and the desugaring must take the class's typedef -- is_same<iterator_traits<int *>::iterator_category,
// random_access_iterator_tag>::value in libc++'s move_iterator, on the program's own classes here.
#include <cstdio>
template <class T> struct Traits { typedef T *pointer; typedef int tag; static const int value = 7; };
template <class A, class B> struct Same { static const bool v = false; };
template <class A> struct Same<A, A> { static const bool v = true; };
int main() {
    printf("%d %d %d %d\n", (int) Same<Traits<char>::pointer, char *>::v, (int) Same<Traits<char>::tag, int>::v,
           (int) Same<Traits<char>::tag, char>::v, Traits<char>::value);
    return 0;
}
