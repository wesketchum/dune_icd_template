%%
%% DUNEICD.cls
%%
%% A simplified LaTeX class for DUNE Interface (Control) Documents.
%% The layout follows the DUNE Interface Document Word template
%% (e.g. EDMS 3449868, FD Slow Controls -- DAQ), with metadata-command
%% conventions borrowed from the DUNE DAQ PRR specification classes
%% (DUNEDAQSpecDoc / TDAQGenDoc).
%%
%% Class options:
%%   letterpaper (default) | a4paper
%%   draft        -- adds a DRAFT watermark
%%   linenumbers  -- adds line numbers (useful for review circulation)
%%
%% Document metadata commands (set in the preamble):
%%   \DocTitle{...}        full document title (cover page)
%%   \ShortDocTitle{...}   short title used in page headers
%%   \DocDescription{...}  one/two sentence description on the cover
%%   \DocIdentifier{...}   document identifier line (free text, optional)
%%   \EDMSDocId{...}       EDMS ID number
%%   \EDMSDocUrl{...}      EDMS URL
%%   \DocVersion{...}      revision number
%%   \CreationDate{...}    created date
%%   \ModifiedDate{...}    last modified date
%%   \DocAuthors{...}      "Prepared by" list
%%   \DocCheckedBy{...}    "Checked by" list
%%   \DocApprovedBy{...}   "To be approved by" list
%%   \DistributionList{...} optional distribution list
%%
%% Cover page:            \makeICDcover
%% Revision history:      \begin{revisionhistory} \revEntry{1.0}{date}{who}{what} \end{revisionhistory}
%% Item table:            \begin{icdtable}{col2 header} \icdrow{1}{desc}{resp}{status} \end{icdtable}
%%
%% Appendices: use plain LaTeX \appendix followed by \section{...}, not a
%% hand-rolled "APPENDIX A" heading with a manual \addcontentsline -- the
%% article class's \appendix already gives correct lettering (A, B, ...),
%% ToC entries, and \ref/\label support out of the box.
%%
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{DUNEICD}[2026/07/13 v1.0 DUNE Interface Control Document]

\newif\if@icddraft\@icddraftfalse
\newif\if@icdlineno\@icdlinenofalse
\DeclareOption{draft}{\@icddrafttrue}
\DeclareOption{linenumbers}{\@icdlinenotrue}
\DeclareOption{letterpaper}{\PassOptionsToClass{letterpaper}{article}}
\DeclareOption{a4paper}{\PassOptionsToClass{a4paper}{article}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ExecuteOptions{letterpaper}
\ProcessOptions\relax

\LoadClass[11pt]{article}

%-------------------------------------------------------------------------
% Packages
%-------------------------------------------------------------------------
\RequirePackage[margin=2.5cm,includeheadfoot,headheight=16pt]{geometry}
\RequirePackage{graphicx}
\RequirePackage[table,dvipsnames]{xcolor}
\RequirePackage{array}
\RequirePackage{tabularx}
\RequirePackage{longtable}
\RequirePackage{booktabs}
\RequirePackage{enumitem}
\RequirePackage[parfill]{parskip}
\RequirePackage{mathptmx}          % Times text+math, close to the Word original
\RequirePackage[scaled=0.92]{helvet}
\RequirePackage[T1]{fontenc}
\RequirePackage{fancyhdr}
\RequirePackage{lastpage}
\RequirePackage{caption}
\captionsetup{font=small,labelfont=bf}
\RequirePackage{hyperref}
\hypersetup{
  colorlinks=true,
  allcolors=blue,
  bookmarksnumbered=true,
  linktocpage=true,
}
\if@icddraft
  \RequirePackage{draftwatermark}
  \SetWatermarkLightness{0.92}
\fi
\if@icdlineno
  \RequirePackage{lineno}
  \AtBeginDocument{\linenumbers}
\fi

%-------------------------------------------------------------------------
% Metadata commands
%-------------------------------------------------------------------------
\def\@DocTitle{Interface Document Title}
\newcommand{\DocTitle}[1]{\def\@DocTitle{#1}}
\def\@ShortDocTitle{ICD}
\newcommand{\ShortDocTitle}[1]{\def\@ShortDocTitle{#1}}
\def\@DocDescription{}
\newcommand{\DocDescription}[1]{\def\@DocDescription{#1}}
\def\@DocIdentifier{}
\newcommand{\DocIdentifier}[1]{\def\@DocIdentifier{#1}}
\def\@EDMSDocId{}
\newcommand{\EDMSDocId}[1]{\def\@EDMSDocId{#1}}
\def\@EDMSDocUrl{}
\newcommand{\EDMSDocUrl}[1]{\def\@EDMSDocUrl{#1}}
\def\@DocVersion{1.0}
\newcommand{\DocVersion}[1]{\def\@DocVersion{#1}}
\def\@CreationDate{\today}
\newcommand{\CreationDate}[1]{\def\@CreationDate{#1}}
\def\@ModifiedDate{\today}
\newcommand{\ModifiedDate}[1]{\def\@ModifiedDate{#1}}
\def\@DocAuthors{}
\newcommand{\DocAuthors}[1]{\def\@DocAuthors{#1}}
\def\@DocCheckedBy{}
\newcommand{\DocCheckedBy}[1]{\def\@DocCheckedBy{#1}}
\def\@DocApprovedBy{}
\newcommand{\DocApprovedBy}[1]{\def\@DocApprovedBy{#1}}
\def\@DistributionList{}
\newcommand{\DistributionList}[1]{\def\@DistributionList{#1}}

%-------------------------------------------------------------------------
% Page style
%-------------------------------------------------------------------------
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\sffamily \@ShortDocTitle}
\fancyhead[R]{\small\sffamily EDMS \@EDMSDocId\ -- Rev.\ \@DocVersion}
\fancyfoot[C]{\small\sffamily Page \thepage\ of \pageref*{LastPage}}
\renewcommand{\headrulewidth}{0.4pt}
\renewcommand{\footrulewidth}{0pt}

\fancypagestyle{plain}{%
  \fancyhf{}%
  \fancyfoot[C]{\small\sffamily Page \thepage\ of \pageref*{LastPage}}%
  \renewcommand{\headrulewidth}{0pt}%
}

%-------------------------------------------------------------------------
% Cover page
%-------------------------------------------------------------------------
\newcommand{\makeICDcover}{%
  \thispagestyle{empty}%
  \begingroup
  \renewcommand{\arraystretch}{1.3}%
  % --- Banner: logo + document type/title + identifiers -----------------
  \noindent
  \begin{tabularx}{\textwidth}{|c|>{\centering\arraybackslash}X|}
    \hline
    \raisebox{-0.45\height}{\includegraphics[width=3.2cm]{Logos/DUNElogo_color}} &
    {\large DUNE Interface Document:} \newline {\large\bfseries \@DocTitle} \\
    \hline
  \end{tabularx}

  \vspace{-1pt}
  \noindent
  \begin{tabularx}{\textwidth}{|X|X|X|X|}
    \hline
    Document identifier: & \@DocIdentifier & Created: \@CreationDate & Pages: \pageref*{LastPage} \\
    \hline
    \textbf{EDMS ID \@EDMSDocId} & & Modified: \@ModifiedDate & Rev.\ No.: \@DocVersion \\
    \hline
  \end{tabularx}

  \vspace{1.5cm}
  % --- Title block ------------------------------------------------------
  \begin{center}
    {\large DUNE Interface Document:}\\[0.5em]
    {\LARGE\bfseries\itshape \@DocTitle}\\[1.5em]
    \begin{minipage}{0.85\textwidth}
      \centering \@DocDescription
    \end{minipage}\\[1.5em]
    \ifx\@EDMSDocUrl\@empty\else \url{\@EDMSDocUrl}\\[1em] \fi
  \end{center}

  \vfill
  % --- Signature block --------------------------------------------------
  \noindent
  \begin{tabularx}{\textwidth}{|X|X|X|}
    \hline
    Prepared by: & Checked by: & To be approved by: \\
    \begin{minipage}[t]{\linewidth}\bfseries\@DocAuthors\end{minipage} &
    \begin{minipage}[t]{\linewidth}\bfseries\@DocCheckedBy\end{minipage} &
    \begin{minipage}[t]{\linewidth}\bfseries\@DocApprovedBy\end{minipage} \\[0.5em]
    \hline
    \ifx\@DistributionList\@empty
      \multicolumn{3}{|l|}{Distribution List} \\
    \else
      \multicolumn{3}{|l|}{Distribution List: \@DistributionList} \\
    \fi
    \hline
  \end{tabularx}
  \endgroup
  \clearpage
  \setcounter{page}{2}%
}

%-------------------------------------------------------------------------
% Revision history
%-------------------------------------------------------------------------
\newenvironment{revisionhistory}{%
  \section*{Revision History}%
  \addcontentsline{toc}{section}{Revision History}%
  \renewcommand{\arraystretch}{1.3}%
  \begin{longtable}{|>{\centering\arraybackslash}p{1.7cm}|>{\centering\arraybackslash}p{2.4cm}|>{\centering\arraybackslash}p{2.4cm}|p{\dimexpr\textwidth-8.5cm\relax}|}
    \hline
    \textit{Revision} & \textit{Date} & \textit{Author} & \multicolumn{1}{c|}{\textit{History of changes}} \\
    \hline
    \endhead
}{%
  \end{longtable}%
}
\newcommand{\revEntry}[4]{#1 & #2 & #3 & #4 \\ \hline}

%-------------------------------------------------------------------------
% Item / responsibility / status tables
%-------------------------------------------------------------------------
% A 4-column longtable of the shape used repeatedly across ICDs for
% "items to be provided", "action items", "open issues", etc: a narrow
% item-number column, a wide description column, and two narrower
% responsibility/status columns. The second column header is the only
% thing that varies between uses ("Item Description", "Activity", ...);
% pass it as the environment argument.
%
%   \begin{icdtable}{Item Description}
%     \icdrow{1}{DAQ barracks and related outfitting}{I\&I}{Planned}
%     \icdrow{2}{...}{...}{...}
%   \end{icdtable}
\newenvironment{icdtable}[1]{%
  \renewcommand{\arraystretch}{1.3}%
  \begin{longtable}{|>{\centering\arraybackslash}p{1.6cm}|p{\dimexpr\textwidth-9.1cm\relax}|p{3.2cm}|p{2.3cm}|}
    \hline
    \textbf{Item \#} & \textbf{#1} & \textbf{Responsibility} & \textbf{Status} \\
    \hline
    \endhead
}{%
  \end{longtable}%
}
\newcommand{\icdrow}[4]{\textbf{#1} & #2 & #3 & #4 \\ \hline}

%-------------------------------------------------------------------------
% Convenience
%-------------------------------------------------------------------------
% Inline marker for open points, e.g. \tbd{to be confirmed with I&I}
\newcommand{\tbd}[1]{\textcolor{red}{\textbf{TBD:} #1}}
% Compact bullet lists, matching the dense lists of the Word original
\newenvironment{item_dense}{%
  \begin{itemize}[itemsep=1pt,parsep=0pt,topsep=2pt]%
}{\end{itemize}}
\newenvironment{enum_dense}{%
  \begin{enumerate}[itemsep=1pt,parsep=0pt,topsep=2pt]%
}{\end{enumerate}}

\setcounter{secnumdepth}{3}
\setcounter{tocdepth}{3}

\endinput
