/* a derived class cannot name a private member of its base: refused by name (0.117) */
class Base { int secret = 3; public: int pub = 1; };
class Derived : public Base { public: int peek() { return secret; } };
int main() { Derived d; return d.peek(); }
