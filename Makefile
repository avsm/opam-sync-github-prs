.PHONY: all

PREFIX ?= /usr/local

all:
	corebuild -use-ocamlfind generate.native

opam-prefix:
	@opam config var bin > $@ 2>/dev/null || echo $(PREFIX) > $@

install: all opam-prefix
	mkdir -p `cat opam-prefix`
	cp generate.native `cat opam-prefix`/opam-sync-github-prs

clean:
	rm -f opam-prefix
	ocamlbuild -clean
