(*
 * Copyright (c) 2018 Anil Madhavapeddy <anil@recoil.org>
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

open Bos
open Rresult
open Printf

module O = Ocaml_version
module OO = Ocaml_version.Opam
module O2 = Ocaml_version.Opam.V2

let subst k v buf =
  let re = Str.regexp_string ("%%"^k^"%%") in
  Str.global_replace re v buf

let subst_tmpl f vs =
  match Ifiles.read f with
  | None -> Error (`Msg "internal error: crunch file not found")
  | Some c -> List.fold_left (fun a (k,v) -> subst k v a) c vs |> fun r -> Ok r

let opam_variant ~descr ~version ~url ~extra_flags ~available =
  subst_tmpl "variant-opam"
   [ "DESCR", descr; "VERSION", version; "URL", url; "FLAGS", extra_flags; "AVAILABLE", available ] 
 
let write dir file c =
  let f = Fpath.(dir / file) in
  OS.Dir.create ~path:true dir >>= fun _ ->
  eprintf "Writing %s\n%!" (Fpath.to_string f);
  OS.File.write f c

let gen_pr ~output_dir pull =
  let open Github_t in
  let pr = sprintf "pr%d" pull.pull_number in
  let descr = String.escaped pull.pull_title in
  let source_user = pull.pull_user.user_login in
  let head = pull.pull_head.branch_ref in
  let url =
    match pull.pull_head.branch_repo with
    | Some repo -> sprintf "git+https://github.com/%s.git#%s" repo.repository_full_name head
    | None -> sprintf "git+https://github.com/%s/ocaml.git#%s.tar.gz" source_user head
  in
  let version = O.(to_string Sources.trunk) in
  opam_variant ~descr ~version ~url ~extra_flags:"" ~available:"" >>= fun opam ->
  let ov = O.(with_variant Sources.trunk (Some pr)) in
  write Fpath.(output_dir / "packages" / (O2.name ov)) "opam" opam

let gen_base ~output_dir ov =
  let version = O.to_string ov in
  let version_succ = O.(to_string (with_patch ov (match patch ov with None -> Some 0 | Some v -> Some (v+1) ))) in
  subst_tmpl "base-opam" [ "VERSION", version; "VERSION_SUCC", version_succ ] >>= fun opam ->
  let name = sprintf "ocaml.%s" O.(to_string ov) in
  let odir = Fpath.(output_dir / "packages") in
  write Fpath.(odir / name) "opam" opam >>= fun () ->
  match Ifiles.read "gen_ocaml_config.ml.in" with
  | None -> Error (`Msg "internal error: crunch file not found")
  | Some c -> write Fpath.(odir / "files") "gen_ocaml_config.ml.in" c

let rec iter fn l =
  match l with
  | hd::tl -> fn hd >>= fun () -> iter fn tl
  | [] -> Ok ()

let gen_variants ~output_dir base_ov vs =
  let module C = O.Configure_options in
  let base_version = O.to_string base_ov in
  let ov = O.with_variant base_ov (match vs with [] -> None | _ -> Some (String.concat "+" (List.map C.to_string vs))) in
  let full_version = O.to_string ov in
  let tag = O.Sources.git_tag ov in
  let url = Printf.sprintf "git+https://github.com/ocaml/ocaml.git#%s" tag in
  let descr = Printf.sprintf "OCaml %s~dev%s%s" full_version (match vs with  [] -> "" |_ -> " with ") (String.concat " and " (List.map C.to_description vs)) in
  let extra_flags = String.concat " " (List.map C.to_configure_flag vs) in
  let available = if List.mem `Frame_pointer vs then "os = \"linux\"" else "" in
  opam_variant ~descr ~version:base_version ~url ~extra_flags ~available >>= fun opam ->
  write Fpath.(output_dir / "packages" / ("ocaml-variants." ^ full_version)) "opam" opam

let gen_repo ~output_dir =
  let file = {|
opam-version: "2.0"
upstream: "https://github.com/ocaml/ocaml-pr-repository/tree/master/"
|} in
  write output_dir "repo" file

let gen user repo output_dir =
  let open Github in
  let output_dir = Fpath.v output_dir in
  let trunk = O.Sources.trunk in
  let pulls = Pull.for_repo ~user ~repo ~state:`Open () in
  let prs = Lwt_main.run (Monad.run (pulls |> Stream.to_list)) in
  gen_repo ~output_dir >>= fun () ->
  iter (gen_pr ~output_dir) prs >>= fun () ->
  iter (gen_base ~output_dir) O.Releases.dev >>= fun () ->
  iter (gen_variants ~output_dir trunk) (O.compiler_variants trunk)

open Cmdliner

let github_user =
  let doc = "GitHub repository username" in
  Arg.(value & opt string "ocaml" & info ["u";"github-user"] ~doc)

let github_repo =
  let doc = "GitHub repository" in
  Arg.(value & opt string "ocaml" & info ["r"; "github-repo"]  ~doc)

let output_dir =
  let doc = "Output directory to generate the PRs into." in
  Arg.(value & opt string "packages" & info ["o"] ~docv:"OUTPUT_DIR" ~doc)

let cmd =
  let doc = "generate OCaml compiler packages for opam2" in
  let man = [
    `S "DESCRIPTION";
    `P "$(tname) fetches the open pull requests for the OCaml compiler and generates opam packages that correspond to each open pull request.";
    `S "BUGS";
    `P "Report them via e-mail to <platform@lists.ocaml.org>, or \
        on the issue tracker at <https://github.com/avsm/opam-sync-github-prs>" ]
  in
  Term.(term_result (const gen $ github_user $ github_repo $ output_dir)),
  Term.info "opam-sync-github-pr" ~version:"1.0.0" ~doc ~man

let () =
  match Term.eval cmd
  with `Error _ -> exit 1 | _ -> exit 0
