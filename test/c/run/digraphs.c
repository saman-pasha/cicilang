%:include <stdio.h>
%:define CAT(a, b) a %:%: b
%:define STR(x) %:x
/* C95's digraphs (C17 6.4.6/3): `<:' `:>' `<%' `%>' `%:' `%:%:' are `[' `]' `{' `}' `#' `##', in a directive, a macro's
   body, an array, a list and a block */
struct P <% int x, y; %>;
int main(void) <%
  int a<:3:> = <%1, 2, 3%>;
  int CAT(to, tal) = a<:0:> + a<:1:> + a<:2:>;
  struct P p = <% .x = 4, .y = 5 %>;
  printf("%d %s %d\n", total, STR(dig), p.x * p.y);
  %:if defined(CAT) && 1
  printf("directive\n");
  %:endif
  return 0;
%>
