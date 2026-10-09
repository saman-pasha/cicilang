/* a private member function called from outside its class is refused by name (0.117) */
class Account { void audit() {} public: void go() { audit(); } };
int main() { Account a; a.go(); a.audit(); return 0; }
