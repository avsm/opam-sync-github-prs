.PHONY: all

PREFIX ?= /usr/local

all:
	corebuild -j 4 -use-ocamlfind generate.native create_pull_request.native

opam-prefix:
	@opam config var bin > $@ 2>/dev/null || echo $(PREFIX) > $@

install: all opam-prefix
	mkdir -p `cat opam-prefix`
	cp generate.native `cat opam-prefix`/opam-sync-github-prs
	cp create_pull_request.native `cat opam-prefix`/opam-github-pull-request

clean:
	rm -f opam-prefix
	ocamlbuild -clean
