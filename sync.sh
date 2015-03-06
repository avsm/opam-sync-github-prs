#!/bin/sh -ex

REPO=../auto-opam-repository
UPSTREAM=git://github.com/ocaml/opam-repository
GEN=`pwd`/generate.native
PULL=`pwd`/create_pull.native
V=4.03.0
if [ ! -d ${REPO} ]; then
  git clone git@github.com:bactrian/opam-repository ${REPO}
fi

BRANCH=sync-prs-`date +%s`
HRDATE=`date +%c`
cd $REPO
git pull $UPSTREAM master
git checkout -b $BRANCH

rm -rf compilers/${V}/${V}+pr*
$GEN
git add compilers
git commit -a -m 'Sync latest compiler pull requests'
git push origin $BRANCH
$PULL -h $BRANCH -m "The latest compiler pull requests for OCaml $V as of
$HRDATE" -t "Sync OCaml compiler PRs" -b master -r opam-repository -u bactrian \
  -x ocaml -k infra
