
module Types = Types_
open Types

type type_element =
  | EUnitConstant
  | EBooleanConstant of bool
  | EIntegerConstant of int
  | EStringConstant  of string
  | EListCons
  | EEndOfList
  | EConstructor     of string * nom_type
  | ETuple
  | EWildCard

and pattern_instance =
  | IUnitConstant
  | IIntegerConstant of int
  | IBooleanConstant of bool
  | IStringConstant  of string
  | IListCons        of pattern_instance * pattern_instance
  | IEndOfList
  | IConstructor     of string * pattern_instance * nom_type
  | ITupleCons       of pattern_instance list
  | IWildCard

and expand_type =
  | ExpandListCons
  | ExpandConstructor of string * nom_type
  | ExpandTuple       of int
  | NoExpand
[@@deriving show]


module ElementSet = Set.Make(struct
  type t = type_element
  let compare i j =
    match (i, j) with
    | (EUnitConstant, EUnitConstant)
    | (EListCons, EListCons)
    | (EEndOfList, EEndOfList)
    | (ETuple, ETuple)
    | (EWildCard, EWildCard)                       -> 0
    | (EBooleanConstant(b1), EBooleanConstant(b2)) -> compare b1 b2
    | (EIntegerConstant(i1), EIntegerConstant(i2)) -> compare i1 i2
    | (EStringConstant(s1), EStringConstant(s2))   -> compare s1 s2
    | (EConstructor(s1, _), EConstructor(s2, _))   -> compare s1 s2
    | _                                            -> 1
end)

module IntSet = Set.Make(struct
  type t = int
  let compare i j = i - j
end)

let repeat n x =
  let rec iter n acc =
    match n with
    | 0 -> acc
    | _ -> iter (n-1) (x::acc)
  in
    iter n []

let one_to_n n =
  let rec iter n acc =
    match n with
    | 0 -> acc
    | _ -> iter (n-1) (n::acc)
  in
    iter n []

let split_n lst n =
  let rec iter lst i a b =
    match lst with
    | []                 -> (List.rev a, List.rev b)
    | x :: xs when n > i -> iter xs (i+1) (x::a) b
    | x :: xs            -> iter xs (i+1) a (x::b)
  in
    iter lst 0 [] []

let is_all_wildcard mat =
  List.for_all (fun p ->
    match p with
    | PWildCard -> true
    | _         -> false
  ) (List.hd mat)

let flatten_tuple tup =
  let rec iter ast acc =
    match ast with
    | PTupleCons(hd, PEndOfTuple) -> List.rev (hd::acc)
    | PTupleCons(hd, tl)          -> iter tl (hd::acc)
    | _ -> failwith "malformed tuple(flatten_tuple)"
  in
    iter tup []

let instance_of_element ele =
  match ele with
  | EUnitConstant           -> IUnitConstant
  | EBooleanConstant(b)     -> IBooleanConstant(b)
  | EIntegerConstant(i)     -> IIntegerConstant(i)
  | EStringConstant(s)      -> IStringConstant(s)
  | EConstructor(nm, ty)    -> IConstructor(nm, IWildCard, ty)
  | EListCons               -> IListCons(IWildCard, IWildCard)
  | EEndOfList              -> IEndOfList
  | ETuple                  -> failwith "tuple is not expected"
  | EWildCard               -> IWildCard

let rec string_of_instance ins =
  match ins with
  | IListCons(IListCons(car, cdr), cdr2) ->
      "(" ^ (string_of_instance car) ^ "::" ^ (string_of_instance cdr) ^ ")::" ^ (string_of_instance cdr2)

  | IListCons(car, cdr) ->
      (string_of_instance car) ^ "::" ^ (string_of_instance cdr)

  | IConstructor(nm, iins, (_, BaseType(UnitType))) -> nm

  | IConstructor(nm, IWildCard, (_, ProductType(tylst))) ->
      nm ^ "(" ^ (String.concat ", " (repeat (List.length tylst) "_")) ^ ")"

  | IConstructor(nm, iins, (_, ProductType(_))) ->
      nm ^ string_of_instance iins

  | IConstructor(nm, iins, (_, _)) ->
      nm ^ "(" ^ string_of_instance iins ^ ")"

  | ITupleCons([i]) ->
      string_of_instance i

  | ITupleCons(ilst) ->
      let items = List.map string_of_instance ilst in
        "(" ^ (String.concat ", " items) ^ ")"

  | IEndOfList          -> "[]"
  | IUnitConstant       -> "()"
  | IIntegerConstant(i) -> string_of_int i
  | IBooleanConstant(b) -> string_of_bool b
  | IStringConstant(s)  -> s
  | IWildCard           -> "_"


let rec normalize_pat pat =
  match pat with
  | PListCons(car, cdr)  -> PListCons(normalize_pat car, normalize_pat cdr)
  | PTupleCons(car, cdr) -> PTupleCons(normalize_pat car, normalize_pat cdr)
  | PConstructor(nm, p)  -> PConstructor(nm, normalize_pat p)
  | PVariable(_)         -> PWildCard
  | PAsVariable(_, p)    -> normalize_pat p
  | _                    -> pat

let expand_mat mat i epat ty =
  let rec inner_append a b acc =
    match (a, b) with
    | (x::xs, y::ys) -> inner_append xs ys (List.append x y :: acc)
    | (x::xs, [])    -> inner_append xs [] (x :: acc)
    | ([], y::ys)    -> inner_append [] ys (y :: acc)
    | ([], [])       -> List.rev acc
  in
  let rec sub epat pat =
    match (epat, pat) with
    | (ExpandListCons, PListCons(h, t))->
      [[h]; [t]]

    | (ExpandListCons, PWildCard) ->
      [[PWildCard]; [PWildCard]]

    | (ExpandConstructor(_, _), PConstructor(_, innerpat)) ->
      [[innerpat]]

    | (ExpandConstructor(_, _), PWildCard) ->
      [[PWildCard]]

    | (ExpandTuple(_), PTupleCons(h, t)) ->
      let ftup = flatten_tuple (PTupleCons(h, t)) in
        List.map (fun pat -> [pat]) ftup

    | (ExpandTuple(arity), PWildCard) ->
        repeat arity [PWildCard]

    | (_, _) -> [[pat]]
  in
    List.flatten (mat |> List.mapi (fun n col ->
      if i <> n then [col] else List.fold_left (fun a b -> inner_append a b []) [] (List.map (sub epat) col)))

let rec fold_left3 f a b c d =
  match b, c, d with
  | x::xs, y::ys, z::zs ->
      fold_left3 f (f a x y z) xs ys zs
  | _ -> a


let rec get_specialized_mat mat patinfo ele tylst =
  let rec iter fst mat =
    let (nmat, ninfo, nomatch) =
      List.fold_left (fun (cols, info, no_match) col ->
        let (newcol, newinfo, no_m) = (fold_left3 (fun (col, info, no_m) p q i ->
          let needs_append =
            match ele, p with
            | EListCons, PListCons(_, _)
            | EEndOfList, PEndOfList
            | EUnitConstant, PUnitConstant
            | ETuple, PTupleCons(_, _)
            | _, PWildCard
              -> true
            | EBooleanConstant(b1), PBooleanConstant(b2) when b1 = b2
              -> true
            | EIntegerConstant(i1), PIntegerConstant(i2) when i1 = i2
              -> true
            | EStringConstant(s1), PStringConstant(Value(StringEmpty)) when String.equal s1 ""
              -> true
            | EStringConstant(s1), PStringConstant(Value(StringConstant(s2))) when String.equal s1 s2
              -> true
            | EConstructor(nm1, _), PConstructor(nm2, _) when String.equal nm1 nm2
              -> true
            | _
              -> false
          in
            match needs_append, i with
            | true, (n, PatternBranch(_, _)) ->
                (q::col, i::info, false)
            | true, (n, PatternBranchWhen(_, _, _)) ->
                (q::col, i::info, no_m)
            | false, _ ->
                (col, info, no_m)

          ) ([], [], true) fst col patinfo
        ) in ((List.rev newcol)::cols, newinfo, no_m && no_match)) ([], [], true) mat
      in (List.rev nmat, List.rev ninfo, nomatch)
  in
    match ele, tylst with
    | EListCons, (_, ListType(lty))::_ ->
        let expnd = ExpandListCons in
        let (nmat, ninfo, nomatch) = iter (List.hd mat) mat in
          (expand_mat nmat 0 expnd tylst, ninfo, lty::tylst, expnd, nomatch)

    | EConstructor(nm, ity), (_, DataType(_, _))::rest ->
        let expnd = ExpandConstructor(nm, ity) in
        let (nmat, ninfo, nomatch) = iter (List.hd mat) mat in
          (expand_mat nmat 0 expnd tylst, ninfo, ity::rest, expnd, nomatch)

    | ETuple, (_, ProductType(ptylst))::rest ->
        let expnd = ExpandTuple(List.length ptylst) in
          (expand_mat mat 0 expnd tylst, patinfo, ptylst @ rest, expnd, false)

    | _ ->
        begin match mat with
        | x :: xs ->
            let (nmat, ninfo, nomatch) = iter x mat in
              (List.tl nmat, ninfo, List.tl tylst, NoExpand, nomatch)
        | [] -> ([], [], [], NoExpand, true)
        end


let unit_sig    = ElementSet.of_list [EUnitConstant]
let bool_sig    = ElementSet.of_list [EBooleanConstant(true); EBooleanConstant(false)]
let list_sig    = ElementSet.of_list [EListCons; EEndOfList]
let product_sig = ElementSet.of_list [ETuple]
let generic_sig = ElementSet.of_list [EWildCard]

let make_int_sig col =
  ElementSet.of_list (List.fold_left (fun acc p ->
    match p with
    | PIntegerConstant(i) ->
        EIntegerConstant(i)::EIntegerConstant(succ i)::acc
    | _ -> acc
  ) [] col)

let make_string_sig col =
  ElementSet.of_list (List.fold_left (fun acc p ->
    match p with
    | PStringConstant(Value(StringEmpty))       -> EStringConstant("")::acc
    | PStringConstant(Value(StringConstant(s))) -> EStringConstant(s)::acc
    | _                                         -> acc
  ) [EWildCard] col)

let make_variant_sig qtfbl lev tyenv (tyarglst : nom_type list) tyid =
  let constrs = Typeenv.enumerate_constructors qtfbl tyenv lev tyid in
  ElementSet.of_list (constrs |> List.map (fun (nm, tyf) ->
    EConstructor(nm, normalize_mono_type (tyf (List.map unnormalize tyarglst)))))

let rec complete_sig col qtfbl lev tyenv (ty : nom_type) =
  match snd ty with
(*
  | TypeVariable({contents= MonoLink(tylink)}) -> complete_sig col qtfbl lev tyenv tylink
*)
  | BaseType(UnitType)          -> unit_sig
  | BaseType(BoolType)          -> bool_sig
  | BaseType(IntType)           -> make_int_sig col
  | BaseType(StringType)        -> make_string_sig col
  | ListType(_)                 -> list_sig
  | ProductType(_)              -> product_sig
  | DataType(tyarglst, tyid) ->
      if is_alias tyid then
        let pty = get_actual_type tyid (assert false) (* tyarglst *) in  (* TEMPORARY *)
        let nty = normalize_mono_type (assert false) (* (unlift_poly pty) *) in  (* TEMPORARY *)
        complete_sig col qtfbl lev tyenv nty
      else
        make_variant_sig qtfbl lev tyenv tyarglst tyid

  | _ -> generic_sig

let tuplize_instance n ilst =
  let (top, btm) = split_n ilst n in
    ITupleCons(top) :: btm

let reduce_instance nm ty ilst =
  match ilst with
  | x :: rest ->
    IConstructor(nm, x, ty) :: rest
  | _ -> failwith "reduce_instance failed"

let reduce_list_instance ilst =
  match ilst with
  | car :: cdr :: rest ->
    IListCons(car, cdr) :: rest
  | _ -> failwith "reduce_list_instance failed"

let rec exhcheck_mat tylst mat patinfo qtfbl lev tyenv =
  let fold_instance expnd ele ins =
    match expnd with
    | ExpandListCons ->
      reduce_list_instance ins
    | ExpandConstructor(nm, ty) ->
      reduce_instance nm ty ins
    | ExpandTuple(arity) ->
      tuplize_instance arity ins
    | NoExpand ->
      (instance_of_element ele)::ins in
  let patinfo_extract patinfo =
    patinfo |> List.map (fun (n, _) -> n) in
  let patinfo_until_match patinfo =
    fst @@ List.fold_left (fun (acc, fin) (n, patbr) ->
      match fin, patbr with
      | false, PatternBranch(_, _) -> (n::acc, true)
      | false, PatternBranchWhen(_, _, _) -> (n::acc, false)
      | true, _ -> (acc, true)
    ) ([], false) patinfo in
  let apply_each set =
    let (nonexh, nonexh_guard, used) =
      ElementSet.fold (fun ele (a_nonexh, a_nonexh_guard, a_used) ->
        let (smat, spatinfo, stylst, expnd, no_match) = get_specialized_mat mat patinfo ele tylst in
          begin match no_match, smat with
          | true, _ ->
              let used = IntSet.of_list (patinfo_extract spatinfo) in
              let ins = (instance_of_element ele) :: (repeat (List.length tylst - 1) (IWildCard)) in
                if IntSet.is_empty used then
                  (ins::a_nonexh, a_nonexh_guard, IntSet.union used a_used)
                else
                  (a_nonexh, ins::a_nonexh_guard, IntSet.union used a_used)
          | false, [] ->
              (a_nonexh, a_nonexh_guard, IntSet.union (IntSet.of_list (patinfo_until_match spatinfo)) a_used)
          | false, _ ->
              let (nonexh, nonexh_guard, used) = exhcheck_mat stylst smat spatinfo qtfbl lev tyenv in
                ((List.map (fold_instance expnd ele) nonexh) @ a_nonexh,
                  (List.map (fold_instance expnd ele) nonexh_guard) @ a_nonexh_guard,
                    IntSet.union used a_used)
          end) set ([], [], IntSet.empty)
    in (List.rev nonexh, List.rev nonexh_guard, used)
  in
  match tylst with
  | [] -> ([], [], IntSet.empty)
  | _ ->
      if is_all_wildcard mat then
        apply_each generic_sig
      else
        apply_each (complete_sig (List.hd mat) qtfbl lev tyenv (List.hd tylst))

let non_empty lst =
  match lst with
  | [] -> false
  | _ -> true

let main (rng : Range.t) (patbrs : pattern_branch list) (ty : mono_type)
    (qtfbl : quantifiability) (lev : FreeID.level) (tyenv : Typeenv.t) : unit =
  let patbrs = patbrs |> List.map (fun patbr ->
    match patbr with
    | PatternBranch(p, a) -> PatternBranch(normalize_pat p, a)
    | PatternBranchWhen(p, a1, a2) -> PatternBranchWhen(normalize_pat p, a1, a2)
  ) in
  let mat = [patbrs |> List.map (fun patbr ->
    match patbr with
    | PatternBranch(p, _) -> p
    | PatternBranchWhen(p, _, _) -> p
  )] in
  let patid = one_to_n (List.length patbrs) in
  let patinfo = List.combine patid patbrs in
    let (nonexh, nonexh_guard, used) = exhcheck_mat [normalize_mono_type ty] mat patinfo qtfbl lev tyenv in
    let unused = IntSet.diff (IntSet.of_list patid) used in
    if (non_empty nonexh) || (non_empty nonexh_guard) || not (IntSet.is_empty unused) then
      begin
        Format.printf "! [Warning about pattern-matching] at %s\n" (Range.to_string rng);
        nonexh |> List.iter (function [ins] ->
          Format.printf "    non-exhaustive: %s\n" (string_of_instance ins)
          | _ -> ());
        nonexh_guard |> List.iter (function [ins] ->
          Format.printf "    non-exhaustive(guarded clause may match): %s\n" (string_of_instance ins)
          | _ -> ());
        IntSet.iter (fun id -> Format.printf "    pattern #%d is unused\n" id) unused;
        Format.printf "\n";
      end
    else
      ()
