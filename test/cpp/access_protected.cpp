/* a protected member function called from outside the class and its derived classes is refused by name (0.117) */
class Base { protected: int limit = 1; void tweak() {} };
int main() { Base b; b.tweak(); return 0; }
