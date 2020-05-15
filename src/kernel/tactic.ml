open Rules
open Engine
open Logic

type env = {ctx:prop list list;
            goals:prop list;
            proof:instructions list}

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

let check goal prog = is_proof (eval prog) goal

let init p = {ctx=[[]]; goals=[p]; proof=[]}

let apply p {ctx; goals; proof} =
  match goals, p with
  | [], _ -> failwith "no more subgoals"
  | g::goals, Impl (a, b) when g = b && find p ctx ->
    {ctx = ctx;
     goals = a::goals;
     proof = Axiom (top_frame ctx, p)::ElimImpl::proof}
  | _ -> failwith "Unable to use apply"

let elim p {ctx; goals; proof} =
  match goals, p with
  | [], _ -> failwith "no more subgoals"
  | g::goals, And (a, b) when a = g || b = g && find p ctx ->
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
  | _ -> failwith ("Unable to use elim " ^ (show_prop p))


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
     goals = p::(Not p)::goals;
     proof = IntroBot::ElimBot g::proof}

let exfalso {ctx; goals; proof} =
  match goals with
  | [] -> failwith "no more subgoals"
  | g::goals when find Bot ctx ->
    {ctx;
     goals;
     proof = Axiom (top_frame ctx, Bot)::ElimBot g::proof}
  | _ -> failwith "unable to use exfalso"

let assertion p {ctx; goals; proof} =
  match goals with
  | [] -> failwith "no more subgoals"
  | g::goals ->
    {ctx=(top_frame ctx)::(add_hyp p ctx);
     goals = p::g::goals;
     proof = proof}

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

let qed p e =
  if check p e.proof
  then Printf.printf "Goal %s Proved.\n" (show_prop p)
  else Printf.printf "Goal %s Failed.\n" (show_prop p)



