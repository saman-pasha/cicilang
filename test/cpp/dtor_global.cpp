// ... A FILE-SCOPE OBJECT (1.6.55)
struct X { ~X() = delete; };
X g;
int main() {
  return 0;
}
