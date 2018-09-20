## Sync OCaml development versions with opam 2

This command-line tool generates an [opam2](https://opam.ocaml.org) repository
that contains a set of compiler switches that apply patches from
GitHub pull requests to OCaml.  They also contain the development
versions of the OCaml compiler with several common configure-time
variants, such as AFL support or the Flambda inliner.

For example, here is a shortened list of outputs:

```
$ opam switch list-available
ocaml-variants      4.08.0                             OCaml 4.08.0~dev
ocaml-variants      4.08.0+afl                         OCaml 4.08.0+afl~dev with AFL (fuzzing) support
ocaml-variants      4.08.0+default-unsafe-string       OCaml 4.08.0+default-unsafe-string~dev with default to unsafe strings
ocaml-variants      4.08.0+flambda                     OCaml 4.08.0+flambda~dev with flambda inlining
ocaml-variants      4.08.0+force-safe-string           OCaml 4.08.0+force-safe-string~dev with force safe string mode
ocaml-variants      4.08.0+pr24                        Switch to the SipHash hash function
ocaml-variants      4.08.0+pr100                       First class module dynlink
ocaml-variants      4.08.0+pr102                       Improved error messages
ocaml-variants      4.08.0+pr113                       Creating -unsafe dependant array/string/bigarray access primitives
ocaml-variants      4.08.0+pr126                       Automatically insert source location
```

To use it, first add the development remote:

```
opam repo add dev https://github.com/ocaml/ocaml-pr-repository.git --set-default
opam update

opam switch create 4.08.0+flambda
eval $(opam env)
ocaml -version

opam switch list-available
```

### Add a variant

The tool that generates these repositories is at <https://github.com/ocaml/opam-sync-github-prs>,
and its help can be accessed via `opam-sync-github-prs --help`.  It runs regularly to push
the results to <https://github.com/ocaml/ocaml-pr-repository>, which is what most developers
will want to use.
