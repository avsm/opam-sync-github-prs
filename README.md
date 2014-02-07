## Sync OCaml GitHub issues with OPAM

This command-line tool generates an OPAM repository that
contains a set of compiler switches that apply patches from
GitHub pull requests to OCaml.

For example, here is a shortened list of outputs:

```
$ opam switch --all
system  C system                      System compiler (4.01.0)
--     -- 3.11.2                      Official 3.11.2 release
--     -- 3.12.1                      Official 3.12.1 release
--     -- 4.00.0                      Official 4.00.0 release
--     -- 4.00.1                      Official 4.00.1 release
--     -- 4.01.0                      Official 4.01.0 release
--     -- 4.02.0dev+pr2               Parse -.x**2. (unary -.) as -.(x**2.).  Fix PR#3414
--     -- 4.02.0dev+pr3               Extend record punning to allow destructuring.
--     -- 4.02.0dev+pr4               Fix for PR#4832 (Filling bigarrays may block out runtime)
--     -- 4.02.0dev+pr6               Warn user when a type variable in a type constraint has been instantiated.
--     -- 4.02.0dev+pr7               Extend ocamllex with actions before refilling
--     -- 4.02.0dev+pr8               Adds a .gitignore to ignore all generated files during `make world.opt'
```

You can experiment with the lexing PR by running:

```
open switch 4.02.0dev+pr7
eval `opam config env`
ocamllex ...
```

### Usage

$ opam-sync-github-prs -help

Generates an OPAM compiler remote for active GitHub OCaml PRs

  opam-sync-github-prs 

=== flags ===

  [-compiler-version string]  OCaml compiler version
  [-github-repo string]       GitHub repository
  [-github-user string]       GitHub username
  [-output-dir string]        Directory containing the OPAM repository
  [-build-info]               print info about this build and exit
  [-version]                  print the version of this build and exit
  [-help]                     print this help text and exit
                              (alias: -?)
```
