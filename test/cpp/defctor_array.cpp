// AN ARRAY OF SUCH A CLASS, by its bound (1.6.55)
struct X { X() = delete; };
int main() {
  X a[2];
  return 0;
}
