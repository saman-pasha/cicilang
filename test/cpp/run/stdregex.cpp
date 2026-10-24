#include <cstdio>
#include <regex>
#include <string>
// std::regex: match, search, replace, iterate
int main() {
  std::regex r("([a-z]+)@([a-z]+)\\.com");
  std::smatch m;
  std::string s = "mail: alice@example.com, bob@test.com";
  if (std::regex_search(s, m, r)) std::printf("%s %s %s\n", m[0].str().c_str(), m[1].str().c_str(), m[2].str().c_str());
  std::printf("%d\n", (int) std::regex_match("abc123", std::regex("[a-c]+[0-9]+")));
  std::printf("%s\n", std::regex_replace(s, r, "<$1 at $2>").c_str());
  int n = 0;
  for (std::sregex_iterator it(s.begin(), s.end(), r), end; it != end; ++it) n++;
  std::printf("%d\n", n);
  std::regex ic("HELLO", std::regex::icase);
  std::printf("%d\n", (int) std::regex_search("say hello", ic));
  return 0;
}
