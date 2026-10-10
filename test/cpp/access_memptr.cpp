// refused: the address of a private member, taken outside its class ([class.access]/4)
#include <cstdio>
class Account { int balance = 5; public: int get() const { return balance; } };
int main() { int Account::*pm = &Account::balance; Account a; std::printf("%d\n", a.*pm); return 0; }
