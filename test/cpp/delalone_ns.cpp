// ... A NAMESPACE'S (1.6.55): `no member named 'h' in namespace 'N''
namespace N { void h() = delete; }
int main() {
  N::h();
  return 0;
}
