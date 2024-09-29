# Introduction

## Benchmarking Physics-Inspired Optimization Solvers

## Mathematical Definitions

All instances have been recast into the binary, minimization form:

```math
\begin{array}{rll}
    \displaystyle
    \min_{\mathbf{x}} & \alpha \left[ \mathbf{x}' \mathbf{Q} \, \mathbf{x} + \mathbf{\ell}' \mathbf{x} + \beta \right] \\
    \textrm{s.t.}     & \mathbf{x} \in \mathbb{B}^{n} \\
\end{array}
```

where ``\mathbf{Q} \in \mathbb{R}^{n \times n}`` is an upper triangular matrix, ``\mathbf{\ell} \in \mathbb{R}^{n}`` is a vector, ``\alpha, \beta \in \mathbb{R}`` are scalars, and ``\mathbb{B}^{n}`` is the set of binary vectors of length ``n``.

## Table of Contents

1. [Basic Usage](./1-basic.md)
