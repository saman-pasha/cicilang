// the driver gate's -E text against clang's in C++: alternative tokens, digraphs and #x as written (0.228)
%:define S(a) #a
bool f(bool a, bool b) { return a and b or not a; }
int g(int a, int b) { a and_eq b; a or_eq b; a xor_eq b; return compl a bitand b bitor (a xor b) not_eq 0; }
int caf\N{LATIN SMALL LETTER E WITH ACUTE} = 1;
const char *p = S(caf\N{LATIN SMALL LETTER E WITH ACUTE}), *q = S(a and b), *r = u8"\N{LATIN SMALL LETTER E WITH ACUTE}", *s = R"x(a\nb)x";
int h() { return café + '\N{LATIN SMALL LETTER E WITH ACUTE}'; }
