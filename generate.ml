(*
 * Copyright (c) 2014 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

open Core.Std
open Lwt

let make_compiler_spec ~version ~output_dir pull =
  let open Github_t in
  let suffix = sprintf "+pr%d" pull.pull_number in
  let name = version ^ suffix in
  let descr = pull.pull_title in
  let subdir = sprintf "%s/compilers/%s/%s/" output_dir version name in
  let source_user = pull.pull_user.user_login in
  let head = pull.pull_head.branch_ref in
  let source_url =
    match pull.pull_head.branch_repo with
      Some repo -> 
        sprintf "https://github.com/%s/archive/%s.tar.gz"
         repo.repo_full_name head
    | None ->
         sprintf "https://github.com/%s/ocaml/archive/%s.tar.gz" source_user head
  in
  printf "Generating: %s\n%!" subdir;
  Unix.mkdir_p subdir;
  let open Out_channel in
  with_file (subdir ^ name ^ ".descr") ~f:(fun t -> output_string t descr);
  with_file (subdir ^ name ^ ".comp")
    ~f:(fun t ->
        [
          "opam-version: \"1\"";
          sprintf "version: \"%s\"" version;
          sprintf "src: \"%s\"" source_url;
          "build: [";
          "  [\"./configure\" \"-prefix\" prefix \"-with-debug-runtime\"]";
          "  [make \"world\"]";
          "  [make \"world.opt\"]";
          "  [make \"install\"]";
          "]";
          "packages: [ \"base-unix\" \"base-bigarray\" \"base-threads\" ]";
          "env: [[CAML_LD_LIBRARY_PATH = \"%{lib}%/stublibs\"]]"
        ] |> output_lines t 
      )

let all_pulls ~user ~repo =
  let open Github in
  let open Monad in
  let rec loop page reqs =
    Pull.for_repo ~page ~user ~repo ~state:`Open () >>= function
    | [] -> return (List.concat reqs)
    | rs -> loop (page + 1) (rs :: reqs)
  in loop 1 []

let get_pulls user repo version output_dir () =
  let open Github in
  let pulls = all_pulls ~user ~repo in
  Lwt_main.run (Monad.run pulls);
  |> List.iter ~f:(make_compiler_spec ~version ~output_dir)

let _ =
  Command.basic
    ~summary:"Generates an OPAM compiler remote for active GitHub OCaml PRs"
    Command.Spec.(
      empty
      +> flag "-github-user" (optional_with_default "ocaml" string) ~doc:"string GitHub username"
      +> flag "-github-repo" (optional_with_default "ocaml" string) ~doc:"string GitHub repository"
      +> flag "-compiler-version" (optional_with_default "4.02.0dev" string) ~doc:"string OCaml compiler version"
      +> flag "-output-dir" (optional_with_default "." string) ~doc:"string Directory containing the OPAM repository"
    ) get_pulls
  |> Command.run
