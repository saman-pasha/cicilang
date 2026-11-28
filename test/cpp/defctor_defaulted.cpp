// `Y() = default' DEFINED AS DELETED by a member (1.6.55)
struct X { X() = delete; };
struct Y { X x; Y() = default; };
int main() {
  Y y;
  return 0;
}
