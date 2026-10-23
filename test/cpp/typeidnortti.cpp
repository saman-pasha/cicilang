// -fno-rtti (0.191): the program's own typeid is refused, as clang++ -fno-rtti refuses it ("use of typeid requires -frtti")
#include <typeinfo>
int main() { return typeid(int) == typeid(long) ? 1 : 0; }
