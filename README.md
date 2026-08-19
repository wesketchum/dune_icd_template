# DUNE ICD LaTeX Template

Shared LaTeX class, editorial-markup package, and tooling for authoring
DUNE Interface Control Documents (ICDs).

## Contents

- **`DUNEICD.cls`** -- Document class providing the ICD cover page,
  revision history table, `icdtable`/`icdrow` responsibility tables, and
  `item_dense`/`enum_dense` compact list environments.
- **`dune-icd-changes.sty`** -- Thin wrapper around the `changes` package
  for tracking editorial markup (`\added`, `\deleted`, `\replaced`,
  `\comment`), plus `addedblock`/`deletedblock` environments for marking
  whole structural blocks (headings + body) as proposed additions/deletions.
  See the comments at the top of the file for the full command reference.
- **`resolve_changes.py`** -- Standalone script that bakes editorial markup
  into plain LaTeX text: `\added`/`\deleted`/`\replaced`/`\comment` calls
  and `addedblock`/`deletedblock` environments are replaced by the text
  they resolve to, rather than just being visually hidden by compiling
  with `[final]`. Useful for producing a clean submission copy with no
  remaining markup or package dependency. Run `python3 resolve_changes.py
  --help` for usage (or see the module docstring).
- **`Logos/`** -- DUNE logo assets used on the cover page.
- **`template.tex`** -- Starting point for a new ICD document.
- **`.gitignore`** -- LaTeX build-artifact patterns.

## Usage

To start a new ICD document, copy the files in this directory into a new
project directory:

```sh
mkdir dune_icd_daq_<interface>
cp DUNEICD.cls dune-icd-changes.sty resolve_changes.py .gitignore dune_icd_daq_<interface>/
cp -r Logos dune_icd_daq_<interface>/
cp template.tex dune_icd_daq_<interface>/dune_icd_daq_<interface>.tex
```

Then edit `dune_icd_daq_<interface>.tex`: fill in the document metadata
placeholders (title, EDMS ID, authors, etc.) and write the body.

Build with:

```sh
latexmk -pdf dune_icd_daq_<interface>.tex
```

### Editorial markup workflow

While a document is in draft/review, keep the package loaded without
`[final]`:

```latex
\usepackage{dune-icd-changes}
```

Reviewers mark up proposed changes with `\added`, `\deleted`, `\replaced`,
`\comment`, and the `addedblock`/`deletedblock` environments (see
`dune-icd-changes.sty` for the full reference). `\listofchanges` at the
end of the document prints a summary of all markup.

Before an EDMS submission, resolve the markup into plain text so the
submitted document is clean and has no residual dependency on the
markup package:

```sh
python3 resolve_changes.py --drop-package-usage dune_icd_daq_<interface>.tex
```

This overwrites the file in place (pass a second path argument to write
to a different file instead). Diff or compile the result to confirm it
matches expectations before submitting.

## Copy-paste vendoring

Each ICD project vendors its own copy of these files rather than
referencing this repository directly (e.g. via a submodule). This keeps
each project buildable standalone with plain `latexmk`. When this
template repo gets a fix or improvement, re-copy the relevant file(s)
into existing projects by hand.

## Beyond ICDs

Despite the name, `DUNEICD.cls` is not actually specific to interface
documents -- the cover page, revision history table, metadata commands
(`\DocAuthors`, `\DocCheckedBy`, `\DocApprovedBy`, `\EDMSDocId`, etc.),
and `icdtable`/`icdrow` responsibility table are all generic to any
formally reviewed DUNE document. The only ICD-specific bits are cosmetic
(the class name itself and the hardcoded "DUNE Interface Document:"
banner text). `dune-icd-changes.sty` and `resolve_changes.py` have no
ICD-specific content at all. This template can reasonably be reused
as-is for other official DUNE documents that need the same cover
page/review workflow, with the "Interface Document" banner text edited
by hand in the copied `.cls` file if that wording doesn't fit.
