#!/usr/bin/env python3
"""
resolve_changes.py -- bake dune-icd-changes markup into plain LaTeX text.

Rewrites the .tex source: \\added/\\deleted/\\replaced/\\comment calls and
addedblock/deletedblock environments are replaced by the text they resolve
to.

Resolution rules (matching changes.sty's own [final] behavior):
    \\added[id]{text}          -> text
    \\deleted[id]{text}        -> (removed)
    \\replaced[id]{new}{old}   -> new
    \\comment[id]{text}        -> (removed)
    \\begin{addedblock}[...] BODY \\end{addedblock}   -> BODY
    \\begin{deletedblock}[...] BODY \\end{deletedblock} -> (removed)

Usage:
    python3 resolve_changes.py input.tex [output.tex]

If output.tex is omitted, input.tex is overwritten in place.
"""
import re
import sys

INLINE_COMMANDS = {"added": 1, "deleted": 1, "replaced": 2, "comment": 1}
BLOCK_ENVIRONMENTS = {"addedblock", "deletedblock"}


def find_matching_brace(text, open_pos):
    """text[open_pos] must be '{'. Return index just past the matching '}'."""
    assert text[open_pos] == "{"
    depth = 1
    i = open_pos + 1
    n = len(text)
    while depth > 0:
        if i >= n:
            raise ValueError(f"Unbalanced braces starting at {open_pos}")
        c = text[i]
        if c == "\\" and i + 1 < n:
            i += 2
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return i


def skip_optional_arg(text, i):
    """If text[i] == '[', skip a bracketed optional arg (brace-aware so a
    nested '{...}' -- e.g. reason={a, b} -- can't fool the ']' search).
    Returns the index just past the ']', or i unchanged if no '[' there.
    """
    n = len(text)
    j = i
    while j < n and text[j] in " \t\n":
        j += 1
    if j >= n or text[j] != "[":
        return i
    depth = 1
    k = j + 1
    while depth > 0:
        if k >= n:
            raise ValueError(f"Unbalanced optional-arg brackets starting at {j}")
        c = text[k]
        if c == "\\" and k + 1 < n:
            k += 2
            continue
        if c == "{":
            # skip a whole brace group verbatim so any ']' inside is ignored
            k = find_matching_brace(text, k)
            continue
        if c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
        k += 1
    return k


def parse_required_arg(text, i):
    """text[i:] must start (after optional whitespace) with '{...}'.
    Returns (arg_content, index_just_past_closing_brace).
    """
    n = len(text)
    j = i
    while j < n and text[j] in " \t\n":
        j += 1
    if j >= n or text[j] != "{":
        raise ValueError(f"Expected '{{' at position {j}: ...{text[max(0,j-30):j+30]}...")
    end = find_matching_brace(text, j)
    return text[j + 1 : end - 1], end


CMD_NAME_RE = re.compile(r"[A-Za-z]+")


def resolve_inline_commands(text):
    out = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == "%":
            # LaTeX comment: copy verbatim to end of line untouched, so
            # markup commands mentioned in comments/docs aren't resolved.
            eol = text.find("\n", i)
            if eol == -1:
                eol = n
            else:
                eol += 1
            out.append(text[i:eol])
            i = eol
            continue
        if c == "\\":
            # Escaped special char (\%, \{, \}, \$, \&, ...): copy both
            # chars verbatim so e.g. a literal "\%" isn't mistaken on the
            # next iteration for the start of a LaTeX comment.
            if i + 1 < n and not (text[i + 1].isalpha()):
                out.append(text[i : i + 2])
                i += 2
                continue
            m = CMD_NAME_RE.match(text, i + 1)
            name = m.group(0) if m else ""
            if name in INLINE_COMMANDS:
                # word boundary: next char after the command name must not
                # continue an identifier (e.g. don't match "addedblock").
                end_of_name = i + 1 + len(name)
                if end_of_name < n and (text[end_of_name].isalpha() or text[end_of_name] == "*"):
                    out.append(c)
                    i += 1
                    continue
                nargs = INLINE_COMMANDS[name]
                pos = skip_optional_arg(text, end_of_name)
                args = []
                for _ in range(nargs):
                    arg, pos = parse_required_arg(text, pos)
                    args.append(arg)
                if name in ("added",):
                    out.append(args[0])
                elif name == "deleted":
                    pass
                elif name == "replaced":
                    out.append(args[0])
                elif name == "comment":
                    pass
                i = pos
                continue
        out.append(c)
        i += 1
    return "".join(out)


BEGIN_RE_TEMPLATE = r"\\begin\{%s\}"
END_RE_TEMPLATE = r"\\end\{%s\}"


def mask_comments(text):
    """Same-length string with LaTeX comment text (unescaped % to end of
    line) blanked out, so regex searches for real markup ignore mentions
    of it inside comments/documentation. Newlines are preserved so offsets
    still line up 1:1 with the original text.
    """
    out = list(text)
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == "\\" and i + 1 < n:
            i += 2
            continue
        if c == "%":
            j = i
            while j < n and text[j] != "\n":
                out[j] = " "
                j += 1
            i = j
            continue
        i += 1
    return "".join(out)


def resolve_block_environments(text):
    for env in BLOCK_ENVIRONMENTS:
        begin_re = re.compile(BEGIN_RE_TEMPLATE % re.escape(env))
        end_re = re.compile(END_RE_TEMPLATE % re.escape(env))
        while True:
            mask = mask_comments(text)
            m = begin_re.search(mask)
            if not m:
                break
            begin_start, begin_end = m.span()
            body_start = skip_optional_arg(text, begin_end)
            end_m = end_re.search(mask, body_start)
            if not end_m:
                raise ValueError(f"Unmatched \\begin{{{env}}} at position {begin_start}")
            body = text[body_start : end_m.start()]
            if env == "deletedblock":
                replacement = ""
            else:
                replacement = body
            text = text[:begin_start] + replacement + text[end_m.end() :]
    return text


PREAMBLE_LINE_PATTERNS = [
    re.compile(r"^\s*%?\s*\\usepackage(\[[^\]]*\])?\{dune-icd-changes\}.*$"),
    re.compile(r"^\s*%?\s*\\definechangesauthor.*$"),
    re.compile(r"^\s*%?\s*\\listofchanges.*$"),
]


def strip_changes_package_usage(text):
    """Optional cleanup pass (not run by default -- see --drop-package-usage):
    drop \\usepackage{dune-icd-changes}, \\definechangesauthor, and
    \\listofchanges lines (commented or not) so the resolved document has no
    remaining dependency on the changes/dune-icd-changes packages.
    """
    lines = text.split("\n")
    kept = [ln for ln in lines if not any(p.match(ln) for p in PREAMBLE_LINE_PATTERNS)]
    return "\n".join(kept)


def resolve(text, drop_package_usage=False):
    text = resolve_block_environments(text)
    text = resolve_inline_commands(text)
    if drop_package_usage:
        text = strip_changes_package_usage(text)
    return text


def main():
    args = sys.argv[1:]
    drop_package_usage = "--drop-package-usage" in args
    args = [a for a in args if a != "--drop-package-usage"]
    if len(args) not in (1, 2):
        print(__doc__)
        print("\nOptions:\n  --drop-package-usage  Also remove \\usepackage{dune-icd-changes},"
              "\n                        \\definechangesauthor, and \\listofchanges lines."
              "\n\nIf output.tex is omitted, input.tex is overwritten in place.")
        sys.exit(1)
    src_path = args[0]
    dst_path = args[1] if len(args) == 2 else src_path
    with open(src_path, "r") as f:
        text = f.read()
    resolved = resolve(text, drop_package_usage=drop_package_usage)
    with open(dst_path, "w") as f:
        f.write(resolved)
    print(f"Wrote resolved file: {dst_path}")


if __name__ == "__main__":
    main()
