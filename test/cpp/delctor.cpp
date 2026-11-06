// A DELETED CONSTRUCTOR OF A CLASS TEMPLATE'S INSTANCE IN A NAMESPACE, its class as clang spells it and its reason (0.257)
namespace ns { template <class T> struct W { W(int) = delete("no int"); W(long) {} }; }
int main() { ns::W<char> w(1); return 0; }
