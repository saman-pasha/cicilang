/* a private data member named from outside its class is refused by name (0.117): `balance' is Account's */
class Account { int balance = 10; public: int get() const { return balance; } };
int main() { Account a; return a.balance; }
