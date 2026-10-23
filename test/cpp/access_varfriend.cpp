// A variadic friend (C++26, P2893; 0.198) befriends the classes of its pack and no other: U2 is no friend of Fr<U1>, and its
// read of the private member is refused, as clang++ refuses it (`'secret' is a private member of 'Fr<U1>'`). Until 0.198
// `friend Ts...;` was read as no friend at all and opened the class to every name.
template <class... Ts> class Fr { friend Ts...; int secret = 42; };
struct U1 { int get(Fr<U1> &f) { return f.secret; } };
struct U2 { int get(Fr<U1> &f) { return f.secret; } };
int main() { Fr<U1> fr; U1 u; U2 w; return u.get(fr) + w.get(fr); }
