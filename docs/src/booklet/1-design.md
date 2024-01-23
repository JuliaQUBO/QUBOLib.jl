# Library Design

```@diagram tikz
\documentclass{standalone}
\usepackage{tikz}

\begin{document}
\begin{tikzpicture}[
    node/.style={draw, rectangle, minimum width=2cm, minimum height=1cm, font=\large},
    ]
    % Nodes
    \node (A) at (0, 0) {\texttt{build()}};
    \node (B) at (2, 0) {\texttt{build(coll.code)}};

    % Arrows
    \draw[->] (A) -- node[above] {\texttt{coll.code}} (B);
\end{tikzpicture}
\end{document}
```
