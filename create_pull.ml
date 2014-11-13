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

(* Run a Github function inside an Lwt evaluator *)
let run_gh fn = Lwt_main.run (Github.Monad.run (fn ()))
(* Get our API tokens from the Github cookie jar *)
let auth () = Lwt_main.run (
    Github_cookie_jar.init ()
    >>= fun jar ->
    Github_cookie_jar.get jar ~name:"infra"
    >|= function
    | None -> eprintf "Use git-jar to create an `infra` token first.\n%!"; exit (-1)
    | Some t -> t)

let pull ~user ~target_user ~repo ~base ~head ~title ~msg =

  let token = Github.Token.of_string (auth ()).auth_token in

  let head =
    if target_user = user then
      head
    else
      sprintf "%s:%s" user head in

  let pull = Github_t.({
      new_pull_title=title;
      new_pull_base=base;
      new_pull_head=head;
      new_pull_body=(Some msg);
    }) in

  Github.(Monad.(run (Pull.create ~token ~user:target_user ~repo ~pull ()))) >>= fun pull ->
  let num = pull.Github_t.pull_number in
  eprintf "created pull request number %d\n%!" num;
  return ()

module Flag = struct
  open Command.Spec
  let target_user () =
    flag "-x" ~doc:"USER Github user to open pull request against."
      (required string)
  let user () =
    flag "-u" ~doc:"USER Github user to open pull request from."
      (required string)
  let repo () =
    flag "-r" ~doc:"REPOSITORY Repository name to open pull request against."
      (required string)
  let base () =
    flag "-b" ~doc:"BRANCH Base branch of repository to pull your changes into."
      (required string)
  let head () =
    flag "-h" ~doc:"BRANCH The name of the branch where your changes are implemented.  For cross-repository pull requests in the same network, namespace head with a user like this: username:branch."
      (required string)
  let title () =
    flag "-t" ~doc:"STRING The title of the pull request" (required string)
  let message () =
    flag "-m" ~doc:"MESSAGE Pull request message" (required string)
end

let _ =
  Command.basic
    ~summary:"Show issues in paragraph order."
    Command.Spec.(empty
                  +> Flag.user ()
                  +> Flag.target_user ()
                  +> Flag.repo ()
                  +> Flag.base ()
                  +> Flag.head ()
                  +> Flag.title ()
                  +> Flag.message ()
                 )
    (fun user target_user repo base head title msg () ->
       Lwt_main.run (pull ~user ~target_user ~repo ~base ~head ~title ~msg))
  |> Command.run 
