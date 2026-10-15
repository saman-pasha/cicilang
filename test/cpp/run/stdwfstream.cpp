// The wide file streams: std::wofstream writes, std::wifstream reads back by getline and >>, std::wfstream appends.
#include <cstdio>
#include <fstream>
#include <string>
int main() {
  const char *path = "/tmp/cicilang_stdwfstream_fixture.txt";
  {
    std::wofstream out(path);
    out << L"alpha " << 42 << L'\n' << L"beta " << 3.5 << L'\n';
  }
  std::wifstream in(path);
  std::wstring line;
  std::getline(in, line);
  std::printf("%ls|", line.c_str());
  std::wstring w;
  double d = 0;
  in >> w >> d;
  std::printf("%ls %g|", w.c_str(), d);
  in.close();
  {
    std::wfstream f(path, std::ios::in | std::ios::out | std::ios::app);
    f << L"gamma\n";
  }
  std::wifstream again(path);
  int n = 0;
  while (std::getline(again, line)) n++;
  std::printf("%d\n", n);
  std::remove(path);
  return 0;
}
