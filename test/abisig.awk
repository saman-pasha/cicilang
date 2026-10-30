# abisig.awk: AN LLVM IR TEXT'S CALLING CONVENTIONS, one line a function (0.244): each defined, declared and called
# function's result and parameters -- their types and the attributes a call reads (`signext', `zeroext', `sret', `byval'
# and its alignment) -- a value, a name and every other attribute dropped; sorted and unique, so clang's IR and
# cicilang's compare line by line. The driver gate's check of the three machines' conventions (test/driver.sh):
#     awk -f test/abisig.awk file.ll | sort -u
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
# the index of the parenthesis that closes the one at i
function close_of(s, i,    d, c, k) {
  d = 0
  for (k = i; k <= length(s); k++) {
    c = substr(s, k, 1)
    if (c == "(" || c == "[" || c == "{" || c == "<") d++
    else if (c == ")" || c == "]" || c == "}" || c == ">") { d--; if (d == 0) return k }
  }
  return 0
}
# a type's text at the start of s, its brackets balanced
function lead_type(s,    c, k) {
  c = substr(s, 1, 1)
  if (c == "{" || c == "[" || c == "<") { k = close_of(s, 1); return substr(s, 1, k) }
  k = index(s, " "); return k ? substr(s, 1, k - 1) : s
}
# one parameter or argument: its type and the attributes kept
function item(s,    t, r, out, m) {
  s = trim(s)
  if (s == "...") return s
  t = lead_type(s); r = substr(s, length(t) + 1); out = t
  if (r ~ /(^| )signext( |$)/) out = out " signext"
  if (r ~ /(^| )zeroext( |$)/) out = out " zeroext"
  if (r ~ /sret\(/) out = out " sret"
  if (r ~ /byval\(/) { out = out " byval"; if (match(r, /align [0-9]+/)) out = out " " substr(r, RSTART, RLENGTH) }
  return out
}
# the items of a list, split at its top-level commas
function items(s,    d, c, k, cur, out) {
  d = 0; cur = ""; out = ""
  for (k = 1; k <= length(s); k++) {
    c = substr(s, k, 1)
    if (c == "(" || c == "[" || c == "{" || c == "<") d++
    if (c == ")" || c == "]" || c == "}" || c == ">") d--
    if (c == "," && d == 0) { out = out (out == "" ? "" : ", ") item(cur); cur = "" } else cur = cur c
  }
  if (trim(cur) != "") out = out (out == "" ? "" : ", ") item(cur)
  return out
}
# a result: its type, `signext' or `zeroext' before it kept, every other word dropped
function result(h,    n, w, k, out, attrs) {
  h = trim(h); out = ""; attrs = ""
  while (h != "") {
    w = lead_type(h)
    if (w == "signext" || w == "zeroext") attrs = attrs " " w
    else if (w !~ /^(dso_local|dso_preemptable|internal|private|linkonce_odr|linkonce|weak|weak_odr|available_externally|external|hidden|protected|default|local_unnamed_addr|unnamed_addr|noundef|nonnull|noalias|fastcc|ccc|tail|musttail|notail|dereferenceable\([0-9]+\)|align|[0-9]+)$/) out = out (out == "" ? "" : " ") w
    h = trim(substr(h, length(w) + 1))
  }
  return out attrs
}
# a define, a declare or a call: `KIND NAME RESULT (PARAMS)'
function sig(kind, s, at,    name, k, e, head) {
  match(substr(s, at), /@[-A-Za-z0-9_.$"]+\(/)
  if (RSTART == 0) return
  k = at + RSTART - 1; name = substr(s, k + 1, RLENGTH - 2)
  if (name ~ /^llvm\./) return
  e = close_of(s, k + RLENGTH - 1)
  head = substr(s, at, k - at)
  if (kind == "call") { head = trim(head); if (substr(head, length(head), 1) == ")") { sub(/\([^()]*\)$/, "", head) } }   # a variadic call's function type
  print kind " " name " " result(head) " (" items(substr(s, k + RLENGTH, e - k - RLENGTH)) ")"
}
/^define / { sig("def", $0, 8); next }
/^declare / { sig("def", $0, 9); next }
/ call / { k = index($0, " call "); sig("call", $0, k + 6); next }
