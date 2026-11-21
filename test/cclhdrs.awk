# cclhdrs.awk: for the ccllib gate (1.6.7), each definition of ccllib's C headers (library/ccllib/*.pl.h) a line -- a
# function's body, a struct's or a union's members --: its name, the guard it stands in, and the header. The guard is
# the innermost `#ifndef M' whose next directive is `#define M', the header's own include guard aside, and `-' where
# the definition stands in none. The reader includes such a header at each `#include <NAME.pl>', and the preprocessor
# never runs its lines (RULES.md, a macro file's C header), so a name that two headers define is defined once only
# where each definition stands in one shared guard: the gate refuses a name of two headers that stands in another
# guard or in none.
FNR == 1 { n = 0; fileguard = ""; pend = "" }
{
  line = $0
  if (line ~ /^[ \t]*#[ \t]*(if|ifdef|ifndef)([ \t]|$)/) {
    kind = "other"
    if (match(line, /^[ \t]*#[ \t]*ifndef[ \t]+[A-Za-z_][A-Za-z_0-9]*/)) {
      s = substr(line, RSTART, RLENGTH); sub(/^[ \t]*#[ \t]*ifndef[ \t]+/, "", s); kind = "ifndef:" s
    }
    stack[++n] = kind; pend = kind; next
  }
  if (line ~ /^[ \t]*#[ \t]*endif/) { if (n > 0) n--; pend = ""; next }
  if (match(line, /^[ \t]*#[ \t]*define[ \t]+[A-Za-z_][A-Za-z_0-9]*/)) {
    s = substr(line, RSTART, RLENGTH); sub(/^[ \t]*#[ \t]*define[ \t]+/, "", s)
    if (n > 0 && pend == "ifndef:" s) { if (n == 1 && fileguard == "") { fileguard = s; stack[n] = "file" } else stack[n] = "guard:" s }
    pend = ""; next
  }
  if (line ~ /^[ \t]*#/) { pend = ""; next }
  if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*\/[\/*]/ || line ~ /^[ \t]*\*/) next
  pend = ""; name = ""
  if (match(line, /^[A-Za-z_][A-Za-z_0-9 \t*]*[ \t*][A-Za-z_][A-Za-z_0-9]*\([^;]*\)[ \t]*\{/)) {
    s = substr(line, RSTART, RLENGTH); sub(/\(.*$/, "", s); sub(/^.*[ \t*]/, "", s); name = s
  } else if (match(line, /^(typedef[ \t]+)?(struct|union)[ \t]+[A-Za-z_][A-Za-z_0-9]*[ \t]*\{/)) {
    s = substr(line, RSTART, RLENGTH); sub(/[ \t]*\{$/, "", s); sub(/^.*[ \t]/, "", s); name = "tag:" s
  }
  if (name != "") {
    g = "-"
    for (i = n; i >= 1; i--) if (stack[i] ~ /^guard:/) { g = substr(stack[i], 7); break }
    f = FILENAME; sub(/^.*\//, "", f)
    print name, g, f
  }
}
