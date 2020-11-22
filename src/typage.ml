open Types
open Printer

let rec type_expr (e : expr) (env : env) (fun_env : fun_env): typ =
  match e with
  | Cst _ -> Int
  | Bool _ -> Bool
  | Add (e1, e2) | Sub (e1, e2) | Mul (e1, e2) | Div (e1, e2) ->
      let t1 = type_expr e1 env fun_env in
      let t2 = type_expr e2 env fun_env in
      if t1 = Int && t2 = Int then Int 
      else raise ( TypeError ("Operation entre un [" ^ typeToString t1 ^ "] et un [" ^ typeToString t2 ^ "]" ))
  | Lt (e1, e2) | Le (e1, e2) | Gt (e1, e2) | Ge (e1, e2) | Eq (e1, e2) | Neq (e1, e2) -> 
      let t1 = type_expr e1 env fun_env in
      let t2 = type_expr e2 env fun_env in
      if t1 = Int && t2 = Int then Bool
      else raise ( TypeError ("Comparaison entre un [" ^ typeToString t1 ^ "] et un [" ^ typeToString t2 ^ "]" ))
  | And (e1, e2) | Or (e1, e2) -> 
      let t1 = type_expr e1 env fun_env in
      let t2 = type_expr e2 env fun_env in
      if t1 = Bool && t2 = Bool then Bool
      else raise ( TypeError ("Operation logique entre un [" ^ typeToString t1 ^ "] et un [" ^ typeToString t2 ^ "]" ))
  | Not e -> 
      let t = type_expr e env fun_env in
      if t = Bool then Bool
      else raise ( TypeError ("Not avec un " ^ typeToString t))
  | Get x -> 
      begin try Hashtbl.find env x 
      with Not_found -> raise ( TypeError ("La variable [" ^ x ^ "] appelee n'existe pas" )) 
      end
  | Call (f, a) ->
      try
        let func = Hashtbl.find fun_env f in 
        let params_typ = List.fold_left (fun acc e -> (type_expr e env fun_env) :: acc) [] a in
        let btype = List.for_all2 (fun t1 (_, t2) -> t1 = t2) params_typ func.params in
        if btype then func.return
        else raise ( TypeError ("Parametre mal type"))
      with Not_found -> raise ( TypeError ("La fonction [" ^ f ^ "] appelee n'existe pas" )) 
          | Invalid_argument _ -> raise ( TypeError ("Le nombre de parametre le correspond pas avec la definition de la fonction" ))

let rec check_type_intr (i : instr) (env : env) (type_fun : typ) (fun_env : fun_env): bool =
  match i with
  | Putchar e ->
      let t = type_expr e env fun_env in 
      if t = Int then true
      else raise (TypeError ("La fonction putchar attend un [int] mais un " ^ typeToString t ^ " lui a ete donnee"))
  | Set(s, e) -> 
      Hashtbl.find env s = type_expr e env fun_env
  | If(c, b1, b2) ->
      if type_expr c env fun_env = Bool 
      then (
          let bb1 = List.for_all (fun i -> check_type_intr i env type_fun fun_env) b1 in
          let bb2 = List.for_all (fun i -> check_type_intr i env type_fun fun_env) b2 in
          if bb1 
          then
            if bb2 then true
            else raise (TypeError ("Il y a une erreur dans le block du if(" ^ exprToString c ^ ")") )
          else raise (TypeError ("Il y a une erreur dans le block (else) du if(" ^ exprToString c ^ ")") )
        )
      else raise (TypeError ("L'expression " ^ exprToString c ^ " aurait du etre un [boolean]. ") )
  | While(c, b) -> 
      if type_expr c env fun_env = Bool 
      then List.for_all (fun i -> check_type_intr i env type_fun fun_env) b
      else raise (TypeError ("L'expression" ^ exprToString c ^ "aurait du etre un [boolean]. ") )
  | Return e ->
      begin match type_expr e env fun_env, type_fun with
      | Int, Int -> true
      | Bool, Bool -> true
      | t1, t2 -> raise ( TypeError ("La fonction de type [" ^ typeToString t2 ^ "] retourne un [" ^ typeToString t1 ^ "]" ))
      end
  | Expr e -> let _ = type_expr e env fun_env in true

let rec check_type_fun (f : fun_def) (env : env) (fun_env : fun_env): bool =
  List.iter (fun (s, t) -> Hashtbl.add env s t) f.params; 
  List.iter (fun (s, t) -> Hashtbl.add env s t) f.locals; 
  let res = List.for_all (fun i -> check_type_intr i env f.return fun_env) f.code in
  List.iter (fun (s, _) -> Hashtbl.remove env s) f.params; 
  List.iter (fun (s, _) -> Hashtbl.remove env s) f.locals;
  res

let init_env (p : prog): env * fun_env = 
  let env = Hashtbl.create 100 in
  let fun_env = Hashtbl.create 100 in
  List.iter (fun (s, t) -> Hashtbl.add env s t) p.globals;
  List.iter (fun e -> Hashtbl.add fun_env e.name e) p.functions;
  env, fun_env

let check_main (fl : fun_def list): bool = 
  List.exists (fun f -> f.name = "main") fl

let rec check_type_prog (p : prog) : bool = 
  let env, fun_env = init_env p in
  if check_main p.functions 
  then List.for_all (fun f -> check_type_fun f env fun_env) p.functions
  else raise (Undefined_Symbol ("Il n'y a pas de fonction [main]"))