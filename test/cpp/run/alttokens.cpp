%:include <cstdio>
%:include <vector>
%:define TWICE(x) ((x) bitor (x))
// C++'s alternative tokens ([lex.digraph]/2): `and' `or' `not' `bitand' `bitor' `xor' `compl' `and_eq' `or_eq' `xor_eq'
// `not_eq' are their punctuators, in an expression, an operator's name, a macro's body and `#if'; the digraphs, and
// `<::' before a name `<' then `::' ([lex.pptoken]/3.2)
struct V {
  int v;
  bool operator not_eq(const V &o) const { return v not_eq o.v; }
  V operator compl() const { return V{compl v}; }
};
int main() <%
  std::vector<::V> vs = {{1}, {2}};
  int a<:2:> = <%5, 6%>;
  bool t = a<:0:> == 5 and not (a<:1:> == 7) or false;
  int m = 12;
  m and_eq 10;
  m or_eq 1;
  m xor_eq 4;
  std::printf("%d %d %d %d %d %d\n", (int) t, m, compl 0, TWICE(2), (int) (vs<:0:> not_eq vs<:1:>), (compl vs<:1:>).v);
  std::printf("%d %d\n", 6 bitand 3, 6 xor 3);
  %:if 1 and not 0
  std::printf("pp\n");
  %:endif
  return 0;
%>
