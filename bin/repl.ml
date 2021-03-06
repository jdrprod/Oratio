open Tactic
open Language.Parser

let repl prop =
  let rec step ctx =
    match ctx.goals with
    | [] -> qed prop ctx
    | _ ->
      ignore (Sys.command "clear");
      ignore (debug ctx);
      print_string "> ";
      flush stdout;
      match command (read_line ()) with
      | Some f -> step (f ctx)
      | None -> step ctx
  in
  step (init prop)

let () =
  match goals (Sys.argv.(1)) with
  | Some gs ->
    List.iter repl gs
  | None -> failwith "invalid input file"

