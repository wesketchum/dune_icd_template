#!/usr/bin/env python3
"""Convert a DUNEICD LaTeX document to Word.

By default the dune-icd-changes markup is resolved first, as
resolve_changes.py does, so the .docx is a clean copy with no tracked
changes and no comments.

With --tracked, the markup becomes Word tracked changes instead, attributed
to the names in \\definechangesauthor:

    \\added / \\deleted / \\replaced    -> tracked insertions and deletions
    \\comment / \\ToDo                  -> Word comments (left out with
                                         --no-comments)
    addedblock / deletedblock          -> every paragraph inside tracked

Usage:
    python3 icd_to_docx.py doc.tex [-o out.docx] [--reference-doc style.docx]
                           [--tracked [--no-comments]]

    --reference-doc  take Word styles (fonts, headings, margins) from an
                     existing .docx, e.g. the EDMS Word original
    --tracked        keep the markup as Word tracked changes and comments
    --no-comments    with --tracked: tracked changes only, no Word comments

Output defaults to doc_clean.docx, or doc_tracked.docx with --tracked.

Needs pandoc (3.x) and icd_changes_to_docx.lua next to this script.
The cover page is rebuilt as a plain title block and metadata table; check
it against the EDMS cover before submitting a Word version.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
LUA_FILTER = os.path.join(HERE, "icd_changes_to_docx.lua")

# Pandoc-readable stand-ins for the DUNEICD class macros.
CLASS_MACROS = r"""
\newcommand{\tbd}[1]{\textbf{TBD:} #1}
\newcommand{\textminus}{−}
\newcommand{\revEntry}[4]{#1 & #2 & #3 & #4 \\ \hline}
\newcommand{\icdrow}[4]{\textbf{#1} & #2 & #3 & #4 \\ \hline}
\newenvironment{icdtable}[1]{\begin{longtable}{|l|l|l|l|}\hline \textbf{Item \#} & \textbf{#1} & \textbf{Responsibility} & \textbf{Status} \\ \hline}{\end{longtable}}
\newenvironment{revisionhistory}{\section*{Revision History}\begin{longtable}{|l|l|l|l|}\hline \textit{Revision} & \textit{Date} & \textit{Author} & \textit{History of changes} \\ \hline}{\end{longtable}}
"""

META_COMMANDS = ["DocTitle", "ShortDocTitle", "DocDescription", "DocIdentifier",
                 "EDMSDocId", "EDMSDocUrl", "DocVersion", "CreationDate",
                 "ModifiedDate", "DocAuthors", "DocCheckedBy", "DocApprovedBy",
                 "DistributionList"]

DROP_LINES = re.compile(r"^\s*\\(listofchanges|listofToDos|tableofcontents|clearpage)\b.*$",
                        re.M)


def brace_arg(text, start):
    """Return (content, end) of the balanced {...} group at text[start]."""
    assert text[start] == "{"
    depth = 0
    i = start
    while i < len(text):
        c = text[i]
        if c == "\\":
            i += 2
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1:i], i + 1
        i += 1
    raise ValueError("unbalanced braces at offset %d" % start)


def strip_comments(text):
    return re.sub(r"(?<!\\)%.*$", "", text, flags=re.M)


def read_metadata(tex):
    body = strip_comments(tex)
    meta = {}
    for name in META_COMMANDS:
        m = re.search(r"\\%s\s*\{" % name, body)
        if m:
            meta[name], _ = brace_arg(body, m.end() - 1)
    authors = {}
    for m in re.finditer(r"\\definechangesauthor\s*\[([^\]]*)\]\s*\{([^}]*)\}", body):
        opts, ident = m.group(1), m.group(2).strip()
        n = re.search(r"name\s*=\s*\{([^}]*)\}", opts) or re.search(r"name\s*=\s*([^,]*)", opts)
        authors[ident] = n.group(1).strip() if n else ident
    return meta, authors


def cover_block(meta):
    """LaTeX that pandoc can read, standing in for \\makeICDcover."""
    def cell(key):
        return meta.get(key, "").replace(r"\\", "; ")
    rows = [
        ("EDMS ID", cell("EDMSDocId")),
        ("Rev. No.", cell("DocVersion")),
        ("Created", cell("CreationDate")),
        ("Modified", cell("ModifiedDate")),
        ("Prepared by", cell("DocAuthors")),
        ("Checked by", cell("DocCheckedBy")),
        ("To be approved by", cell("DocApprovedBy")),
        ("Distribution list", cell("DistributionList")),
    ]
    lines = []
    if meta.get("DocDescription"):
        lines.append(r"\begin{center}%s\end{center}" % meta["DocDescription"])
    if meta.get("EDMSDocUrl"):
        lines.append(r"\begin{center}\url{%s}\end{center}" % meta["EDMSDocUrl"])
    lines.append(r"\begin{tabular}{|l|l|}\hline")
    for label, value in rows:
        if value:
            lines.append(r"\textbf{%s} & %s \\ \hline" % (label, value))
    lines.append(r"\end{tabular}")
    return "\n".join(lines)


def prepare(tex, meta, clean):
    if clean:
        sys.dont_write_bytecode = True
        sys.path.insert(0, HERE)
        import resolve_changes
        tex = resolve_changes.resolve_block_environments(tex)
        tex = resolve_changes.resolve_inline_commands(tex)
    tex = DROP_LINES.sub("", tex)
    # pandoc cannot define environments whose names contain "_".
    for dense, plain in (("item_dense", "itemize"), ("enum_dense", "enumerate")):
        tex = re.sub(r"\\(begin|end)\{%s\}" % dense, r"\\\1{%s}" % plain, tex)
    tex = tex.replace(r"\makeICDcover", cover_block(meta))
    # Class macros go just before \begin{document}, so pandoc defines them.
    return tex.replace(r"\begin{document}", CLASS_MACROS + "\n" + r"\begin{document}", 1)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("tex")
    ap.add_argument("-o", "--output")
    ap.add_argument("--reference-doc")
    ap.add_argument("--tracked", action="store_true",
                    help="keep markup as Word tracked changes and comments")
    ap.add_argument("--no-comments", action="store_true",
                    help="with --tracked, leave out \\comment and \\ToDo")
    a = ap.parse_args()
    if a.no_comments and not a.tracked:
        ap.error("--no-comments only applies with --tracked")
    clean = not a.tracked

    with open(a.tex) as f:
        tex = f.read()
    meta, authors = read_metadata(tex)
    out = a.output or os.path.splitext(a.tex)[0] + ("_clean" if clean else "_tracked") + ".docx"

    title = re.sub(r"\\[a-zA-Z]+\s*|[{}~]", " ", meta.get("DocTitle", "")).replace("--", "\u2013")
    pandoc_meta = {
        "title": "DUNE Interface Document: " + " ".join(title.split()),
        "changes_authors": authors,
        "changes_date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "latex_macros": CLASS_MACROS,
        "drop_comments": a.no_comments,
    }

    src_dir = os.path.dirname(os.path.abspath(a.tex))
    with tempfile.TemporaryDirectory() as tmp:
        prepared = os.path.join(tmp, "doc.tex")
        with open(prepared, "w") as f:
            f.write(prepare(tex, meta, clean))
        meta_file = os.path.join(tmp, "meta.json")
        with open(meta_file, "w") as f:
            json.dump(pandoc_meta, f)
        cmd = ["pandoc", "-f", "latex+raw_tex", "-t", "docx", prepared,
               "--metadata-file", meta_file, "--lua-filter", LUA_FILTER,
               "--resource-path", src_dir, "--toc", "--number-sections", "-o", os.path.abspath(out)]
        if a.reference_doc:
            cmd += ["--reference-doc", os.path.abspath(a.reference_doc)]
        r = subprocess.run(cmd, cwd=src_dir, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("pandoc failed:\n" + r.stderr)
    for line in r.stderr.splitlines():
        print("pandoc: " + line, file=sys.stderr)
    print("wrote " + out)


if __name__ == "__main__":
    main()
