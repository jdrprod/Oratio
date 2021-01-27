(**
   {1 Tactic}

   Tactics for interactive theorem proving.

   Each tactic is a function maping an interactive proof environement to
   another proof environement and generating instructions for the
   proof construction {! engine}.

   The program generated by succesive applications of tactics can then be
   evaluated using the {! engine} module together with the backend of your
   choice.

   The function {! qed} evaluates the construction program contained in a proof 
   environement with the {! Kernel} as a backend.
*)

open Kernel
open Logic
open Engine

open Make (Rules)

type env = {
  ctx   : prop list list;
  goals : prop list;
  proof : instructions list
}

let add_frame ctx =
  match ctx with
  | [] -> [[]]
  | f::fs -> f::f::fs

let drop_frame ctx =
  match ctx with
  | [] -> []
  | _::fs -> fs

let top_frame ctx =
  match ctx with
  | [] -> []
  | f::_ -> f

let add_hyp p ctx =
  match ctx with
  | [] -> [[p]]
  | f::fs -> (p::f)::fs

let find p ctx = List.exists ((=) p) (top_frame ctx)

let check goal prog = Kernel.Rules.is_proof (eval prog) goal

let init p = {ctx=[[]]; goals=[p]; proof=[]}

let apply p {ctx; goals; proof} =
  let rec compat a b =
    match b with
    | Atom _ -> a = b
    | Impl (_, c) -> a = c || compat a c
    | _ -> false
  in
  let rec extract a b acc =
    match b with
    | Impl (p, c) -> if a = c then p::acc else extract a c (p::acc)
    | _ -> assert false
  in
  match goals, p with
  | [], _ -> failwith "no more subgoals"
  | g::goals, Impl (_, b) when compat g b && find p ctx ->
    let gs = (extract g p []) |> List.rev in
    let cs = List.init (List.length gs) (fun _ -> top_frame ctx) in
    let ps = List.init (List.length gs) (fun _ -> ElimImpl) in
    {ctx = cs;
     goals = gs @ goals;
     proof = Axiom (top_frame ctx, p)::(ps @ proof)}
  | _ -> failwith "Unable to use apply"

let applyn n e = apply (List.nth (top_frame e.ctx) n) e

let elim p {ctx; goals; proof} =
  match goals, p with
  | [], _ -> failwith "no more subgoals"
  | g::goals, And (a, b) when (a = g || b = g) && find p ctx ->
    {ctx = drop_frame ctx;
     goals = goals;
     proof =
       Axiom (top_frame ctx, p)
       ::(if a = g then ElimAndL else ElimAndR)
       ::proof}
  | g::goals, Or (a, b) when find p ctx ->
    {ctx = (a::top_frame ctx)::(add_hyp b ctx);
     goals = g::g::goals;
     proof =
       Axiom (top_frame ctx, p)
       ::ElimOr
       ::proof}
  | g::goals, Or (a, b) ->
    {ctx = (top_frame ctx)::(a::top_frame ctx)::(b::top_frame ctx)::ctx;
     goals = p::g::g::goals;
     proof =
       ElimOr
       ::proof}
  | _, Impl _ -> apply p {ctx; goals; proof}
  | _ -> failwith ("Unable to use elim " ^ (show_prop p))

let elimn n e = elim (List.nth (top_frame e.ctx) n) e

let left {ctx; goals; proof} =
  match goals with
  | [] -> failwith "no more subgoals"
  | Or (a, b)::goals ->
    {ctx = ctx;
     goals = a::goals;
     proof = IntroOrL b::proof}
  | _ -> failwith "Unable to use left"

let right {ctx; goals; proof} =
  match goals with
  | [] -> failwith "no more subgoals"
  | Or (a, b)::goals ->
    {ctx = ctx;
     goals = b::goals;
     proof = IntroOrR a::proof}
  | _ -> failwith "Unable to use left"

let contradiction p {ctx; goals; proof} =
  match goals with
  | [] -> failwith "no more subgoals"
  | g::goals ->
    {ctx = add_frame ctx;
     goals = (Impl (p, Bot))::p::goals;
     proof = ElimImpl::ElimBot g::proof}

let exfalso {ctx; goals; proof} =
  match goals with
  | [] -> failwith "no more subgoals"
  | g::goals when find Bot ctx ->
    {ctx;
     goals;
     proof = Axiom (top_frame ctx, Bot)::ElimBot g::proof}
  | _ -> failwith "unable to use exfalso"

let intro {ctx; goals; proof} =
  match goals with
  | [] -> failwith "no more subgoals"
  | Impl (a, b)::goals ->
    {ctx = add_hyp a ctx;
     goals = b::goals;
     proof = IntroImpl a::proof}
  | And (a, b)::goals ->
    {ctx = add_frame ctx;
     goals = a::b::goals;
     proof = IntroAnd::proof}
  | Or (a, b)::goals ->
    if find a ctx then left {ctx; goals; proof}
    else if find b ctx then right {ctx; goals; proof}
    else failwith "Unable to use intro"
  | _ -> failwith "Unable to use intro"

let rec intros e =
  let e' = intro e in
  try intros e'
  with _ -> e'

let assumption {ctx; goals; proof} =
  match goals with
  | [] -> failwith "no more subgoals"
  | g::goals when find g ctx ->
    {ctx = drop_frame ctx;
     goals = goals;
     proof = Axiom (top_frame ctx, g)::proof}
  | _ -> failwith "Unable to use assumption"


let debug env =
  print_newline ();
  List.iteri (fun i p ->
      Printf.printf "   %d : %s\n" i (show_prop p)
    ) (top_frame env.ctx);
  print_endline "------------------------------";
  List.iteri (fun i p ->
      Printf.printf "[%d/%d]  %s\n" (i+1) (List.length env.goals) (show_prop p)
    ) env.goals;
  env

let help env =
  print_endline "Tactic Help";
  print_endline "-----------";
  print_endline "- intro";
  print_endline "\tUse an introduction rule matching the current goal";
  print_endline "- elim p";
  print_endline "\tTry to eliminate a proposition";
  print_endline "\tIf p is a is already in the context, its proof is not required";
  print_endline "\tIf p is not already in the context, its proof is required";
  print_endline "- elimn n";
  print_endline "\tEliminate the nth hyptothesis";
  print_endline "- apply p";
  print_endline "\tTry to eliminate the implication p";
  print_endline "- left|right";
  print_endline "\tLeft|Right elimination of a disjunction";
  print_endline "- exfalso";
  print_endline "\tTerminate the proof if Botom is found the context";
  print_endline "- contradiction p";
  print_endline "\tTerminate the proof providing proofs of (p) and (not p)";
  print_endline "- assumption";
  print_endline "\tTerminate the proof if the current goal is in the context";
  print_endline "- debug";
  print_endline "\tdisplay the current context and goals";
  ignore (read_line ());
  env

let qed p e =
  if check p e.proof
  then Printf.printf "Goal %s Proved.\n" (show_prop p)
  else Printf.printf "Goal %s Failed.\n" (show_prop p)

let log fn e = instr_dump (open_out fn) e.proof





