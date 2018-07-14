
open LengthInterface
open GraphicBase

exception ParseErrorDetail of string
exception IllegalArgumentLength of Range.t * int * int


type ctrlseq_name       = string  [@@deriving show]
type var_name           = string  [@@deriving show]
type id_name            = string  [@@deriving show]
type class_name         = string  [@@deriving show]
type type_name          = string  [@@deriving show]
type constructor_name   = string  [@@deriving show]
type module_name        = string  [@@deriving show]
type sig_var_name       = string  [@@deriving show]
type field_name         = string  [@@deriving show]
type type_argument_name = string  [@@deriving show]
type length_unit_name   = string  [@@deriving show]


type header_element =
  | HeaderRequire of string
  | HeaderImport  of string


module TypeID : sig
  type t
    [@@deriving show]
  val initialize : unit -> unit
  val fresh : type_name -> t
  val extract_name : t -> type_name
  val equal : t -> t -> bool
  val show_direct : t -> string
end = struct
  type t = int * type_name
    [@@deriving show]
  let current_id = ref 0
  let initialize () = begin current_id := 0; end
  let fresh tynm = begin incr current_id; (!current_id, tynm) end
  let extract_name (_, tynm) = tynm
  let equal (n1, _) (n2, _) = (n1 = n2)
  let show_direct (n, tynm) = (string_of_int n) ^ "(" ^ tynm ^ ")"
end


type quantifiability = Quantifiable | Unquantifiable
[@@deriving show]


module FreeID_
: sig
    type level  [@@deriving show]
    type 'a t_  [@@deriving show]
    val bottom_level : level
    val succ_level : level -> level
    val less_than : level -> level -> bool
    val get_level : 'a t_ -> level
    val set_level : 'a t_ -> level -> 'a t_
    val initialize : unit -> unit
    val fresh : 'a -> quantifiability -> level -> unit -> 'a t_
    val equal : 'a t_ -> 'a t_ -> bool
    val is_quantifiable : 'a t_ -> bool
    val set_quantifiability : quantifiability -> 'a t_ -> 'a t_
    val get_kind : 'a t_ -> 'a
    val set_kind : 'a t_ -> 'a -> 'a t_
    val map_kind : ('a -> 'b) -> 'a t_ -> 'b t_
    val show_direct : ('a -> string) -> 'a t_ -> string
    val show_direct_level : level -> string
  end
= struct
    type level = int
    [@@deriving show]

    type 'a t_ = int * 'a * quantifiability * level
    [@@deriving show]

    let bottom_level = 0

    let succ_level lev = lev + 1

    let less_than = (<)

    let get_level (_, _, _, lev) = lev

    let set_level (idmain, kd, qtfbl, _) lev = (idmain, kd, qtfbl, lev)

    let current_id = ref 0

    let initialize () =
      begin current_id := 0; end

    let fresh kd qtfbl lev () =
      begin
        incr current_id;
        (!current_id, kd, qtfbl, lev)
      end

    let equal (i1, _, _, _) (i2, _, _, _) =
      (i1 = i2)

    let is_quantifiable (_, _, qtfbl, _) =
        match qtfbl with
        | Quantifiable   -> true
        | Unquantifiable -> false

    let set_quantifiability qtfbl (idmain, kd, _, lev) = (idmain, kd, qtfbl, lev)

    let get_kind (_, kd, _, _) = kd

    let set_kind (idmain, _, qtfbl, lev) kd = (idmain, kd, qtfbl, lev)

    let map_kind f (idmain, kd, qtfbl, lev) = (idmain, f kd, qtfbl, lev)

    let show_direct f (idmain, kd, qtfbl, lev) =
      match qtfbl with
      | Quantifiable   -> (string_of_int idmain) ^ "[Q" ^ (string_of_int lev) ^ "::" ^ (f kd) ^ "]"
      | Unquantifiable -> (string_of_int idmain) ^ "[U" ^ (string_of_int lev) ^ "::" ^ (f kd) ^ "]"

    let show_direct_level = string_of_int

  end


module BoundID_
: sig
    type 'a t_  [@@deriving show]
    val initialize : unit -> unit
    val fresh : 'a -> unit -> 'a t_
    val eq : 'a t_ -> 'a t_ -> bool
    val get_kind : 'a t_ -> 'a
    val show_direct : ('a -> string) -> 'a t_ -> string
  end
= struct
    type 'a t_ = int * 'a
    [@@deriving show]

    let current_id = ref 0

    let initialize () = begin current_id := 0; end

    let fresh kd () =
      begin
        incr current_id;
        (!current_id, kd)
      end

    let eq (i1, _) (i2, _) = (i1 = i2)

    let get_kind (_, kd) = kd

    let show_direct f (i, kd) = "[" ^ (string_of_int i) ^ "::" ^ (f kd) ^ "]"

  end


module StoreIDHashTable = Hashtbl.Make(StoreID)


module EvalVarIDMap = Map.Make(EvalVarID)


type manual_type = Range.t * manual_type_main
and manual_type_main =
  | MTypeName        of (manual_type list) * module_name list * type_name
  | MTypeParam       of var_name
  | MFuncType        of manual_type list * manual_type * manual_type
  | MProductType     of manual_type list
  | MRecordType      of manual_type Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "MRecordType(...)")]
  | MHorzCommandType of manual_command_argument_type list
  | MVertCommandType of manual_command_argument_type list
  | MMathCommandType of manual_command_argument_type list
[@@deriving show]

and manual_command_argument_type =
  | MMandatoryArgumentType of manual_type
  | MOptionalArgumentType  of manual_type

type manual_kind =
  | MUniversalKind
  | MRecordKind    of manual_type Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "MRecordKind(...)")]
[@@deriving show]

type base_type =
  | EnvType
  | UnitType
  | BoolType
  | IntType
  | FloatType
  | LengthType
  | StringType
  | TextRowType
  | TextColType
  | BoxRowType
  | BoxColType
  | ContextType
  | PrePathType
  | PathType
  | GraphicsType
  | ImageType
  | DocumentType
  | MathType
  | RegExpType
[@@deriving show]


let base_type_hash_table =
  let ht = Hashtbl.create 32 in
  begin
    List.iter (fun (s, bt) -> Hashtbl.add ht s bt) [
      ("unit"        , UnitType    );
      ("bool"        , BoolType    );
      ("int"         , IntType     );
      ("float"       , FloatType   );
      ("length"      , LengthType  );
      ("string"      , StringType  );
      ("inline-text" , TextRowType );
      ("block-text"  , TextColType );
      ("inline-boxes", BoxRowType  );
      ("block-boxes" , BoxColType  );
      ("context"     , ContextType );
      ("pre-path"    , PrePathType );
      ("path"        , PathType    );
      ("graphics"    , GraphicsType);
      ("image"       , ImageType   );
      ("document"    , DocumentType);
      ("math"        , MathType    );
      ("regexp"      , RegExpType  );
    ];
    ht
  end


type 'a typ = Range.t * 'a type_main
and 'a type_main =
  | BaseType        of base_type
  | FuncType        of (('a typ) list) ref * 'a typ * 'a typ
  | ListType        of 'a typ
  | RefType         of 'a typ
  | ProductType     of ('a typ) list
  | TypeVariable    of 'a
  | SynonymType     of ('a typ) list * TypeID.t * 'a typ
  | VariantType     of ('a typ) list * TypeID.t
  | RecordType      of ('a typ) Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "RecordType(...)")]
  | HorzCommandType of ('a command_argument_type) list
  | VertCommandType of ('a command_argument_type) list
  | MathCommandType of ('a command_argument_type) list

and 'a command_argument_type =
  | MandatoryArgumentType of 'a typ
  | OptionalArgumentType  of 'a typ

and 'a kind =
  | UniversalKind
  | RecordKind of ('a typ) Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "RecordKind(...)")]

and mono_type_variable_info =
  | MonoFree of mono_kind FreeID_.t_
  | MonoLink of mono_type

and poly_type_variable_info =
  | PolyFree  of mono_type_variable_info ref
  | PolyBound of (poly_type_variable_info kind) BoundID_.t_

and mono_type = (mono_type_variable_info ref) typ

and poly_type =
  | Poly of poly_type_variable_info typ

and mono_kind = (mono_type_variable_info ref) kind

and poly_kind = poly_type_variable_info kind
[@@deriving show]


type nom_type_variable_info =
  | NomFree of nom_kind FreeID_.t_

and nom_kind = nom_type_variable_info kind

and nom_type = nom_type_variable_info typ
[@@deriving show]


module FreeID =
  struct
    include FreeID_
    type t = mono_kind FreeID_.t_
  end


module BoundID =
  struct
    include BoundID_
    type t = poly_kind BoundID_.t_
  end

(* ---- untyped ---- *)

type untyped_letrec_binding =
  UTLetRecBinding of manual_type option * var_name * untyped_abstract_tree

and untyped_input_horz_element = Range.t * untyped_input_horz_element_main
and untyped_input_horz_element_main =
  | UTInputHorzText         of string
  | UTInputHorzEmbedded     of untyped_abstract_tree * untyped_command_argument list
  | UTInputHorzContent      of untyped_abstract_tree
  | UTInputHorzEmbeddedMath of untyped_abstract_tree

and untyped_input_vert_element = Range.t * untyped_input_vert_element_main
and untyped_input_vert_element_main =
  | UTInputVertEmbedded of untyped_abstract_tree * untyped_command_argument list
  | UTInputVertContent  of untyped_abstract_tree

and 'a untyped_path_component =
  | UTPathLineTo        of 'a
  | UTPathCubicBezierTo of untyped_abstract_tree * untyped_abstract_tree * 'a

and untyped_abstract_tree =
  Range.t * untyped_abstract_tree_main
    [@printer (fun fmt (_, utastmain) -> Format.fprintf fmt "%a" pp_untyped_abstract_tree_main utastmain)]

and untyped_abstract_tree_main =
(* -- basic value -- *)
  | UTUnitConstant
      [@printer (fun fmt () -> Format.fprintf fmt "()")]
  | UTBooleanConstant      of bool
  | UTIntegerConstant      of int
  | UTFloatConstant        of float
  | UTLengthDescription    of float * length_unit_name
      [@printer (fun fmt (fl, lun) -> Format.fprintf fmt "%f%s" fl lun)]
  | UTStringEmpty
  | UTStringConstant       of string
      [@printer (fun fmt s -> Format.fprintf fmt "\"%s\"" s)]
(* -- inputs -- *)
  | UTInputHorz            of untyped_input_horz_element list
  | UTInputVert            of untyped_input_vert_element list
  | UTConcat               of untyped_abstract_tree * untyped_abstract_tree
(*
  | UTLambdaOptional       of Range.t * var_name * untyped_abstract_tree
*)
  | UTLambdaHorz           of Range.t * var_name * untyped_abstract_tree
  | UTLambdaVert           of Range.t * var_name * untyped_abstract_tree
  | UTLambdaMath           of untyped_abstract_tree
(* -- graphics -- *)
  | UTPath                 of untyped_abstract_tree * (untyped_abstract_tree untyped_path_component) list * (unit untyped_path_component) option
(* -- horizontal box list -- *)
  | UTHorz                 of HorzBox.horz_box list
  | UTHorzConcat           of untyped_abstract_tree * untyped_abstract_tree
(* -- vertical box list -- *)
  | UTVert                 of HorzBox.vert_box list
  | UTVertConcat           of untyped_abstract_tree * untyped_abstract_tree
(* -- list value -- *)
  | UTListCons             of untyped_abstract_tree * untyped_abstract_tree
  | UTEndOfList
(* -- tuple value -- *)
  | UTTupleCons            of untyped_abstract_tree * untyped_abstract_tree
  | UTEndOfTuple
(* -- record value -- *)
  | UTRecord               of (field_name * untyped_abstract_tree) list
  | UTAccessField          of untyped_abstract_tree * field_name
(* -- fundamental -- *)
  | UTContentOf            of (module_name list) * var_name
      [@printer (fun fmt (_, vn) -> Format.fprintf fmt "%s" vn)]
  | UTApply                of untyped_abstract_tree * untyped_abstract_tree
      [@printer (fun fmt (u1, u2) -> Format.fprintf fmt "(%a %a)" pp_untyped_abstract_tree u1 pp_untyped_abstract_tree u2)]
  | UTApplyOmission        of untyped_abstract_tree
  | UTApplyOptional        of untyped_abstract_tree * untyped_abstract_tree
  | UTLetRecIn             of untyped_letrec_binding list * untyped_abstract_tree
  | UTLetNonRecIn          of manual_type option * untyped_pattern_tree * untyped_abstract_tree * untyped_abstract_tree
  | UTIfThenElse           of untyped_abstract_tree * untyped_abstract_tree * untyped_abstract_tree
  | UTFunction             of (Range.t * var_name) list * untyped_pattern_branch list
  | UTOpenIn               of Range.t * module_name * untyped_abstract_tree
  | UTFinishHeaderFile
  | UTFinishStruct
(* -- pattern match -- *)
  | UTPatternMatch         of untyped_abstract_tree * untyped_pattern_branch list
  | UTConstructor          of constructor_name * untyped_abstract_tree
      [@printer (fun fmt (cn, u) -> Format.fprintf fmt "%s(%a)" cn pp_untyped_abstract_tree u)]
(* -- declaration of type and module -- *)
  | UTDeclareVariantIn     of untyped_mutual_variant_cons * untyped_abstract_tree
  | UTModule               of Range.t * module_name * manual_signature option * untyped_abstract_tree * untyped_abstract_tree
(* -- implerative -- *)
  | UTLetMutableIn         of Range.t * var_name * untyped_abstract_tree * untyped_abstract_tree
  | UTSequential           of untyped_abstract_tree * untyped_abstract_tree
  | UTWhileDo              of untyped_abstract_tree * untyped_abstract_tree
  | UTOverwrite            of Range.t * var_name * untyped_abstract_tree
(* -- lightweight itemize -- *)
  | UTItemize              of untyped_itemize
(* -- math -- *)
  | UTMath                 of untyped_math
(* -- for lightweight command definition -- *)
  | UTLexHorz              of untyped_abstract_tree * untyped_abstract_tree
  | UTLexVert              of untyped_abstract_tree * untyped_abstract_tree

and constraints = (var_name * manual_kind) list

and manual_signature_content =
  | SigType   of untyped_type_argument list * type_name
  | SigValue  of var_name * manual_type * constraints
  | SigDirect of var_name * manual_type * constraints
(*
  | SigModule of module_name * manual_signature
*)

and manual_signature = manual_signature_content list

and untyped_itemize =
  | UTItem of untyped_abstract_tree * (untyped_itemize list)

and untyped_constructor_dec = Range.t * constructor_name * manual_type

and untyped_mutual_variant_cons =
  | UTMutualVariantCons    of untyped_type_argument list * Range.t * type_name * untyped_constructor_dec list * untyped_mutual_variant_cons
  | UTMutualSynonymCons    of untyped_type_argument list * Range.t * type_name * manual_type * untyped_mutual_variant_cons
  | UTEndOfMutualVariant

and untyped_pattern_tree = Range.t * untyped_pattern_tree_main
and untyped_pattern_tree_main =
  | UTPIntegerConstant     of int
  | UTPBooleanConstant     of bool
  | UTPStringConstant      of untyped_abstract_tree
  | UTPUnitConstant
  | UTPListCons            of untyped_pattern_tree * untyped_pattern_tree
  | UTPEndOfList
  | UTPTupleCons           of untyped_pattern_tree * untyped_pattern_tree
  | UTPEndOfTuple
  | UTPWildCard
  | UTPVariable            of var_name
  | UTPAsVariable          of var_name * untyped_pattern_tree
  | UTPConstructor         of constructor_name * untyped_pattern_tree

and untyped_pattern_branch =
  | UTPatternBranch     of untyped_pattern_tree * untyped_abstract_tree
  | UTPatternBranchWhen of untyped_pattern_tree * untyped_abstract_tree * untyped_abstract_tree

and untyped_unkinded_type_argument = Range.t * var_name

and untyped_type_argument = Range.t * var_name * manual_kind

and untyped_math = Range.t * untyped_math_main

and untyped_math_main =
  | UTMChar        of string
  | UTMSuperScript of untyped_math * untyped_math
  | UTMSubScript   of untyped_math * untyped_math
  | UTMCommand     of untyped_abstract_tree * untyped_command_argument list
  | UTMList        of untyped_math list
  | UTMEmbed       of untyped_abstract_tree

and untyped_command_argument =
  | UTMandatoryArgument of untyped_abstract_tree
  | UTOptionalArgument  of untyped_abstract_tree
  | UTOmission          of Range.t
[@@deriving show { with_path = false; }]

type untyped_letrec_pattern_branch =
  | UTLetRecPatternBranch of untyped_pattern_tree list * untyped_abstract_tree

type untyped_argument =
  | UTPatternArgument  of untyped_pattern_tree
  | UTOptionalArgument of Range.t * var_name

type untyped_let_binding = manual_type option * untyped_pattern_tree * untyped_argument list * untyped_abstract_tree

(* ---- typed ---- *)

type letrec_binding =
  | LetRecBinding of EvalVarID.t * pattern_branch list

and environment = location EvalVarIDMap.t * (syntactic_value StoreIDHashTable.t) ref
  [@printer (fun fmt _ -> Format.fprintf fmt "<env>")]

and location = syntactic_value ref

and vmenv = environment * (syntactic_value array) list

and compiled_input_horz_element =
  | CompiledInputHorzText         of string
  | CompiledInputHorzEmbedded     of instruction list
  | CompiledInputHorzContent      of instruction list
  | CompiledInputHorzEmbeddedMath of instruction list

and compiled_intermediate_input_horz_element =
  | CompiledImInputHorzText         of string
  | CompiledImInputHorzEmbedded     of instruction list
  | CompiledImInputHorzContent of compiled_intermediate_input_horz_element list * vmenv
  | CompiledImInputHorzEmbeddedMath of instruction list

and compiled_input_vert_element =
  | CompiledInputVertEmbedded of instruction list
  | CompiledInputVertContent  of instruction list

and compiled_intermediate_input_vert_element =
  | CompiledImInputVertEmbedded of instruction list
  | CompiledImInputVertContent  of compiled_intermediate_input_vert_element list * vmenv

and ir_input_horz_element =
  | IRInputHorzText         of string
  | IRInputHorzEmbedded     of ir * ir list
  | IRInputHorzContent      of ir
  | IRInputHorzEmbeddedMath of ir


and ir_input_vert_element =
  | IRInputVertEmbedded of ir * ir list
  | IRInputVertContent  of ir

and 'a ir_path_component =
  | IRPathLineTo        of 'a
  | IRPathCubicBezierTo of ir * ir * 'a

and 'a compiled_path_component =
  | CompiledPathLineTo of 'a
  | CompiledPathCubicBezierTo of instruction list * instruction list * 'a

and varloc =
  | GlobalVar of location * EvalVarID.t * int ref
  | LocalVar  of int * int * EvalVarID.t * int ref

and ir =
  | IRConstant              of syntactic_value
  | IRTerminal
  | IRInputHorz             of ir_input_horz_element list
  | IRInputVert             of ir_input_vert_element list
  | IRRecord                of Assoc.key list * ir list
      [@printer (fun fmt _ -> Format.fprintf fmt "IRRecord(...)")]
  | IRAccessField           of ir * field_name
  | IRLetRecIn              of (varloc * ir) list * ir
  | IRLetNonRecIn           of ir * ir_pattern_tree * ir
  | IRContentOf             of varloc
  | IRIfThenElse            of ir * ir * ir
  | IRFunction              of int * ir_pattern_tree list * ir
  | IRApply                 of int * ir * ir list
  | IRApplyPrimitive        of instruction * int * ir list
  | IRTuple                 of int * ir list
  | IRPatternMatch          of Range.t * ir * ir_pattern_branch list
  | IRNonValueConstructor   of constructor_name * ir
  | IRLetMutableIn          of varloc * ir * ir
  | IRSequential            of ir * ir
  | IRWhileDo               of ir * ir
  | IROverwrite             of varloc * ir
  | IRModule                of ir * ir
  | IRPath                  of ir * ir ir_path_component list * (unit ir_path_component) option

and ir_pattern_branch =
  | IRPatternBranch      of ir_pattern_tree * ir
  | IRPatternBranchWhen  of ir_pattern_tree * ir * ir

and ir_pattern_tree =
  | IRPUnitConstant
  | IRPBooleanConstant      of bool
  | IRPIntegerConstant      of int
  | IRPStringConstant       of string
  | IRPListCons             of ir_pattern_tree * ir_pattern_tree
  | IRPEndOfList
  | IRPTupleCons             of ir_pattern_tree * ir_pattern_tree
  (*| IRPTupleCons            of int * ir_pattern_tree list*)
  | IRPEndOfTuple
  | IRPWildCard
  | IRPVariable             of varloc
  | IRPAsVariable           of varloc * ir_pattern_tree
  | IRPConstructor          of constructor_name * ir_pattern_tree
#include "__insttype.gen.ml"

and input_horz_element =
  | InputHorzText         of string
  | InputHorzEmbedded     of abstract_tree * abstract_tree list
  | InputHorzContent      of abstract_tree
  | InputHorzEmbeddedMath of abstract_tree

and intermediate_input_horz_element =
  | ImInputHorzText         of string
  | ImInputHorzEmbedded     of abstract_tree * abstract_tree list
  | ImInputHorzContent      of intermediate_input_horz_element list * environment
  | ImInputHorzEmbeddedMath of abstract_tree

and intermediate_input_vert_element =
  | ImInputVertEmbedded of abstract_tree * abstract_tree list
  | ImInputVertContent  of intermediate_input_vert_element list * environment

and input_vert_element =
  | InputVertEmbedded of abstract_tree * abstract_tree list
  | InputVertContent  of abstract_tree

and 'a path_component =
  | PathLineTo        of 'a
  | PathCubicBezierTo of abstract_tree * abstract_tree * 'a

and syntactic_value =
  | Nil
  | SimpleRef             of syntactic_value ref
  | UnitConstant
  | BooleanConstant       of bool
  | IntegerConstant       of int
  | FloatConstant         of float
  | LengthConstant        of length
  | StringEmpty
  | StringConstant        of string
  | RegExpConstant        of Str.regexp
      [@printer (fun fmt _ -> Format.fprintf fmt "<regexp>")]

  | Constructor           of constructor_name * syntactic_value

  | FuncWithEnvironment   of pattern_branch list * environment
  | PrimitiveWithEnvironment   of pattern_branch list * environment * int * (abstract_tree list -> abstract_tree)
  | CompiledFuncWithEnvironment of int * syntactic_value list * int * instruction list * vmenv
  | CompiledPrimitiveWithEnvironment of int * syntactic_value list * int * instruction list * vmenv * (abstract_tree list -> abstract_tree)

  | EvaluatedEnvironment  of environment

  | ListCons              of syntactic_value * syntactic_value
  | EndOfList

  | TupleCons             of syntactic_value * syntactic_value
  | EndOfTuple

  | RecordValue           of syntactic_value Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "<record-value>")]

  | Location              of StoreID.t

  | InputHorzWithEnvironment of intermediate_input_horz_element list * environment
  | CompiledInputHorzWithEnvironment    of compiled_intermediate_input_horz_element list * vmenv

  | InputVertWithEnvironment of intermediate_input_vert_element list * environment
  | CompiledInputVertWithEnvironment    of compiled_intermediate_input_vert_element list * vmenv

  | Horz                  of HorzBox.horz_box list
  | Vert                  of HorzBox.vert_box list

  | PathValue             of path list
      [@printer (fun fmt _ -> Format.fprintf fmt "<path>")]
  | GraphicsValue               of (HorzBox.intermediate_horz_box list) GraphicD.element
      [@printer (fun fmt _ -> Format.fprintf fmt "<graphics>")]
  | PrePathValue                of PrePath.t
      [@printer (fun fmt _ -> Format.fprintf fmt "<pre-path>")]
  | MathValue                   of math list
  | ImageKey                    of ImageInfo.key
      [@printer (fun fmt _ -> Format.fprintf fmt "<image-key>")]
  | LambdaHorzWithEnvironment   of EvalVarID.t * abstract_tree * environment
  | LambdaVertWithEnvironment   of EvalVarID.t * abstract_tree * environment
  | Context                     of input_context
  | DocumentValue               of HorzBox.page_size * HorzBox.page_content_scheme_func * HorzBox.page_parts_scheme_func * HorzBox.vert_box list

and abstract_tree =
  | Value                 of syntactic_value
  | FinishHeaderFile
  | FinishStruct
  | LengthDescription     of float * length_unit_name
(* -- input texts -- *)
  | InputHorz             of input_horz_element list
  | InputVert             of input_vert_element list
(* -- graphics -- *)
  | Path                        of abstract_tree * (abstract_tree path_component) list * (unit path_component) option
(* -- record value -- *)
  | Record                of abstract_tree Assoc.t
      [@printer (fun fmt _ -> Format.fprintf fmt "Record(...)")]
  | AccessField           of abstract_tree * field_name
(* -- fundamental -- *)
  | LetRecIn              of letrec_binding list * abstract_tree
  | LetNonRecIn           of pattern_tree * abstract_tree * abstract_tree
  | ContentOf             of Range.t * EvalVarID.t
  | IfThenElse            of abstract_tree * abstract_tree * abstract_tree
  | Function              of pattern_branch list
  | Apply                 of abstract_tree * abstract_tree
(* -- pattern match -- *)
  | PatternMatch          of Range.t * abstract_tree * pattern_branch list
  | NonValueConstructor   of constructor_name * abstract_tree
(* -- imperative -- *)
  | LetMutableIn          of EvalVarID.t * abstract_tree * abstract_tree
  | Sequential            of abstract_tree * abstract_tree
  | WhileDo               of abstract_tree * abstract_tree
  | Overwrite             of EvalVarID.t * abstract_tree
(* -- module system -- *)
  | Module                of abstract_tree * abstract_tree
  | BackendMathList             of abstract_tree list
  | LambdaHorz                  of EvalVarID.t * abstract_tree
  | LambdaVert                  of EvalVarID.t * abstract_tree
  | PrimitiveTupleCons    of abstract_tree * abstract_tree
#include "__attype.gen.ml"

and pattern_branch =
  | PatternBranch      of pattern_tree * abstract_tree
  | PatternBranchWhen  of pattern_tree * abstract_tree * abstract_tree

and pattern_tree =
  | PUnitConstant
  | PBooleanConstant      of bool
  | PIntegerConstant      of int
  | PStringConstant       of abstract_tree
  | PListCons             of pattern_tree * pattern_tree
  | PEndOfList
  | PTupleCons            of pattern_tree * pattern_tree
  | PEndOfTuple
  | PWildCard
  | PVariable             of EvalVarID.t
  | PAsVariable           of EvalVarID.t * pattern_tree
  | PConstructor          of constructor_name * pattern_tree

and input_context = HorzBox.context_main * syntactic_value

and math_element_main =
  | MathChar         of bool * Uchar.t list
      [@printer (fun fmt _ -> Format.fprintf fmt "<math-char>")]
      (* --
         (1) whether it is a big operator
         (2) Unicode code point (currently singular)
         -- *)
  | MathCharWithKern of bool * Uchar.t list * HorzBox.math_char_kern_func * HorzBox.math_char_kern_func
      [@printer (fun fmt _ -> Format.fprintf fmt "<math-char'>")]
      (* --
         (1) whether it is a big operator
         (2) Unicode code point (currently singular)
         (3) left-hand-side kerning function
         (4) right-hand-side kerning function
         --*)
  | MathEmbeddedText of (input_context -> HorzBox.horz_box list)

and math_element =
  | MathElement           of HorzBox.math_kind * math_element_main
  | MathVariantChar       of string
  | MathVariantCharDirect of HorzBox.math_kind * bool * HorzBox.math_variant_style
      [@printer (fun fmt _ -> Format.fprintf fmt "<math-variant-char-direct>")]
      (* --
         (1) math class
         (2) whether it is a big operator
         (3) Unicode code point for all math_char_class
         -- *)

and math_context_change =
  | MathChangeColor         of color
  | MathChangeMathCharClass of HorzBox.math_char_class

and math =
  | MathPure              of math_element
  | MathChangeContext     of math_context_change * math list
  | MathGroup             of HorzBox.math_kind * HorzBox.math_kind * math list
  | MathSubscript         of math list * math list
  | MathSuperscript       of math list * math list
  | MathFraction          of math list * math list
  | MathRadicalWithDegree of math list * math list
  | MathRadical           of HorzBox.radical * math list
  | MathParen             of HorzBox.paren * HorzBox.paren * math list
  | MathParenWithMiddle   of HorzBox.paren * HorzBox.paren * HorzBox.paren * (math list) list
  | MathUpperLimit        of math list * math list
  | MathLowerLimit        of math list * math list
[@@deriving show { with_path = false; }]
(*
type output_unit =
  | OString             of string
  | OBreakAndIndent
  | OSoftBreakAndIndent
  | ODeepen
  | OShallow
*)

(*
let poly_extend (fmono : mono_type -> mono_type) : (poly_type -> poly_type) =
  (fun (Poly(ty)) -> Poly(fmono ty))
*)

let get_range (rng, _) = rng


let overwrite_range_of_type ((_, tymain) : mono_type) (rng : Range.t) = (rng, tymain)


let lift_argument_type f = function
  | MandatoryArgumentType(ty) -> MandatoryArgumentType(f ty)
  | OptionalArgumentType(ty)  -> OptionalArgumentType(f ty)


let lift_manual_common f = function
  | MMandatoryArgumentType(mnty) -> f mnty
  | MOptionalArgumentType(mnty)  -> f mnty


(* -- 'normalize_type': eliminates 'Link(_)' -- *)
let rec normalize_mono_type (ty : mono_type) : nom_type =
  let iter = normalize_mono_type in
  let (rng, tymain) = ty in
    match tymain with
    | TypeVariable(tvinforef) ->
        begin
          match !tvinforef with
          | MonoFree(tvid)   -> (rng, TypeVariable(NomFree(FreeID.map_kind normalize_kind tvid)))
          | MonoLink(tylink) -> iter tylink
        end

    | VariantType(tylist, tyid)         -> (rng, VariantType(List.map iter tylist, tyid))
    | SynonymType(tylist, tyid, tyreal) -> (rng, SynonymType(List.map iter tylist, tyid, iter tyreal))
    | BaseType(bt)                      -> (rng, BaseType(bt))
    | ListType(tycont)                  -> (rng, ListType(iter tycont))
    | RefType(tycont)                   -> (rng, RefType(iter tycont))
    | FuncType(tyoptsr, tydom, tycod)   -> (rng, FuncType(ref (List.map iter (!tyoptsr)), iter tydom, iter tycod))
    | ProductType(tylist)               -> (rng, ProductType(List.map iter tylist))
    | RecordType(tyassoc)               -> (rng, RecordType(Assoc.map_value iter tyassoc))
    | HorzCommandType(tylist)           -> (rng, HorzCommandType(List.map (lift_argument_type iter) tylist))
    | VertCommandType(tylist)           -> (rng, VertCommandType(List.map (lift_argument_type iter) tylist))
    | MathCommandType(tylist)           -> (rng, MathCommandType(List.map (lift_argument_type iter) tylist))


and normalize_kind (kd : mono_kind) : nom_kind =
  match kd with
  | UniversalKind     -> UniversalKind
  | RecordKind(tyasc) -> RecordKind(Assoc.map_value normalize_mono_type tyasc)


let rec erase_range_of_type (ty : mono_type) : mono_type =
  let iter = erase_range_of_type in
  let rng = Range.dummy "erased" in
  let (_, tymain) = ty in
    match tymain with
    | TypeVariable(tvref) ->
        begin
          match !tvref with
          | MonoFree(tvid) -> tvref := MonoFree(FreeID.map_kind erase_range_of_kind tvid); (rng, tymain)
          | MonoLink(ty)   -> erase_range_of_type ty
        end

    | BaseType(_)                       -> (rng, tymain)
    | FuncType(tyoptsr, tydom, tycod)   -> (rng, FuncType(ref (List.map iter (!tyoptsr)), iter tydom, iter tycod))
    | ProductType(tylist)               -> (rng, ProductType(List.map iter tylist))
    | RecordType(tyasc)                 -> (rng, RecordType(Assoc.map_value iter tyasc))
    | SynonymType(tylist, tyid, tyreal) -> (rng, SynonymType(List.map iter tylist, tyid, iter tyreal))
    | VariantType(tylist, tyid)         -> (rng, VariantType(List.map iter tylist, tyid))
    | ListType(tycont)                  -> (rng, ListType(iter tycont))
    | RefType(tycont)                   -> (rng, RefType(iter tycont))
    | HorzCommandType(tylist)           -> (rng, HorzCommandType(List.map (lift_argument_type iter) tylist))
    | VertCommandType(tylist)           -> (rng, VertCommandType(List.map (lift_argument_type iter) tylist))
    | MathCommandType(tylist)           -> (rng, MathCommandType(List.map (lift_argument_type iter) tylist))


and erase_range_of_kind (kd : 'a kind) =
  match kd with
  | UniversalKind   -> UniversalKind
  | RecordKind(asc) -> RecordKind(Assoc.map_value erase_range_of_type asc)


module BoundIDHashTable = Hashtbl.Make(
  struct
    type t = BoundID.t
    let equal = BoundID.eq
    let hash = Hashtbl.hash
  end)

module FreeIDHashTable = Hashtbl.Make(
  struct
    type t = FreeID.t
    let equal = FreeID.equal
    let hash = Hashtbl.hash
  end)


let rec instantiate_aux bid_ht lev qtfbl (rng, ptymain) =
  let aux = instantiate_aux bid_ht lev qtfbl in
    match ptymain with
    | TypeVariable(ptvi) ->
        begin
          match ptvi with
          | PolyFree(tvref) ->
              (rng, TypeVariable(tvref))

          | PolyBound(bid) ->
              begin
                match BoundIDHashTable.find_opt bid_ht bid with
                | Some(tvrefnew) ->
                    (rng, TypeVariable(tvrefnew))

                | None ->
                    let kd = BoundID.get_kind bid in
                    let kdfree = instantiate_kind_aux bid_ht lev qtfbl kd in
                    let tvid = FreeID.fresh kdfree qtfbl lev () in
                    let tvref = ref (MonoFree(tvid)) in
                    begin
                      BoundIDHashTable.add bid_ht bid tvref;
                      (rng, TypeVariable(tvref))
                    end
              end
        end
    | FuncType(tyoptsr, tydom, tycod)   -> (rng, FuncType(ref (List.map aux (!tyoptsr)), aux tydom, aux tycod))
    | ProductType(tylist)               -> (rng, ProductType(List.map aux tylist))
    | RecordType(tyasc)                 -> (rng, RecordType(Assoc.map_value aux tyasc))
    | SynonymType(tylist, tyid, tyreal) -> (rng, SynonymType(List.map aux tylist, tyid, aux tyreal))
    | VariantType(tylist, tyid)         -> (rng, VariantType(List.map aux tylist, tyid))
    | ListType(tysub)                   -> (rng, ListType(aux tysub))
    | RefType(tysub)                    -> (rng, RefType(aux tysub))
    | BaseType(bty)                     -> (rng, BaseType(bty))
    | HorzCommandType(tylist)           -> (rng, HorzCommandType(List.map (lift_argument_type aux) tylist))
    | VertCommandType(tylist)           -> (rng, VertCommandType(List.map (lift_argument_type aux) tylist))
    | MathCommandType(tylist)           -> (rng, MathCommandType(List.map (lift_argument_type aux) tylist))


and instantiate_kind_aux bid_ht lev qtfbl (kd : poly_kind) : mono_kind =
    match kd with
    | UniversalKind     -> UniversalKind
    | RecordKind(tyasc) -> RecordKind(Assoc.map_value (instantiate_aux bid_ht lev qtfbl) tyasc)


let instantiate (lev : FreeID.level) (qtfbl : quantifiability) ((Poly(pty)) : poly_type) : mono_type =
  let bid_ht : (mono_type_variable_info ref) BoundIDHashTable.t = BoundIDHashTable.create 32 in
  instantiate_aux bid_ht lev qtfbl pty


let instantiate_kind (lev : FreeID.level) (qtfbl : quantifiability) (pkd : poly_kind) : mono_kind =
  let bid_ht : (mono_type_variable_info ref) BoundIDHashTable.t = BoundIDHashTable.create 32 in
  instantiate_kind_aux bid_ht lev qtfbl pkd


let lift_poly_general (p : FreeID.t -> bool) (ty : mono_type) : poly_type =
  let tvidht = FreeIDHashTable.create 32 in
  let rec iter (rng, tymain) =
    match tymain with
    | TypeVariable(tvref) ->
        begin
          match !tvref with
          | MonoLink(tyl) ->
              iter tyl

          | MonoFree(tvid) ->
              let ptvi =
                if p tvid then
                  PolyFree(tvref)
                else
                  begin
                    match FreeIDHashTable.find_opt tvidht tvid with
                    | Some(bid) ->
                        PolyBound(bid)

                    | None ->
                        let kd = FreeID.get_kind tvid in
                        let kdgen = generalize_kind kd in
                        let bid = BoundID.fresh kdgen () in
                        FreeIDHashTable.add tvidht tvid bid;
                        PolyBound(bid)
                  end
              in
                (rng, TypeVariable(ptvi))
        end

    | FuncType(tyoptsr, tydom, tycod)   -> (rng, FuncType(ref (List.map iter (!tyoptsr)), iter tydom, iter tycod))
    | ProductType(tylist)               -> (rng, ProductType(List.map iter tylist))
    | RecordType(tyasc)                 -> (rng, RecordType(Assoc.map_value iter tyasc))
    | SynonymType(tylist, tyid, tyreal) -> (rng, SynonymType(List.map iter tylist, tyid, iter tyreal))
    | VariantType(tylist, tyid)         -> (rng, VariantType(List.map iter tylist, tyid))
    | ListType(tysub)                   -> (rng, ListType(iter tysub))
    | RefType(tysub)                    -> (rng, RefType(iter tysub))
    | BaseType(bty)                     -> (rng, BaseType(bty))
    | HorzCommandType(tylist)           -> (rng, HorzCommandType(List.map (lift_argument_type iter) tylist))
    | VertCommandType(tylist)           -> (rng, VertCommandType(List.map (lift_argument_type iter) tylist))
    | MathCommandType(tylist)           -> (rng, MathCommandType(List.map (lift_argument_type iter) tylist))

  and generalize_kind kd =
    match kd with
    | UniversalKind     -> UniversalKind
    | RecordKind(tyasc) -> RecordKind(Assoc.map_value iter tyasc)
  in
    Poly(iter ty)


let generalize (lev : FreeID.level) =
  lift_poly_general (fun tvid -> not (FreeID.is_quantifiable tvid) || not (FreeID.less_than lev (FreeID.get_level tvid)))


let lift_poly =
  lift_poly_general (fun _ -> true)

(*
let copy_environment (env : environment) : environment =
  let (valenv, stenv) = env in
    (Hashtbl.copy valenv, stenv)
*)

(*
let replicate_store (env : environment) : environment =
  let (valenv, stenv) = env in
  let stenvnew = StoreIDHashTable.copy stenv in
(*
  let stenvnew = StoreIDHashTable.create 32 in
  StoreIDHashTable.iter (fun stid value -> StoreIDHashTable.add stenvnew stid value) stenv;
*)
(*
  Format.printf "Types> ==== REPLICATE ====\n";
  StoreIDHashTable.iter (fun stid value ->
    Format.printf "| %s %a\n" (StoreID.show_direct stid) pp_syntactic_value value) stenv;
  Format.printf "Types> ==== END REPLICATE ====\n";

  Format.printf "Types> ==== VALENV ====\n";
  EvalVarIDMap.iter (fun evid loc ->
    Format.printf "| %s\n" (EvalVarID.show_direct evid)) valenv;
  Format.printf "Types> ==== END VALENV ====\n";
*)
    (valenv, stenvnew)
*)

let add_to_environment (env : environment) (evid : EvalVarID.t) (rfast : location) =
  let (valenv, stenvref) = env in
    (*  Format.printf "Types> add %s \n" (EvalVarID.show_direct evid); *)
    (valenv |> EvalVarIDMap.add evid rfast, stenvref)


let find_in_environment (env : environment) (evid : EvalVarID.t) : location option =
  let (valenv, _) = env in
    valenv |> EvalVarIDMap.find_opt evid


let register_location (env : environment) (value : syntactic_value) : StoreID.t =
  let (_, stenvref) = env in
  let stid = StoreID.fresh () in
  StoreIDHashTable.add (!stenvref) stid value;
(*
  Format.printf "Types> Assign %s <--- %a\n" (StoreID.show_direct stid) pp_syntactic_value value;  (* for debug *)
*)
  stid


let update_location (env : environment) (stid : StoreID.t) (value : syntactic_value) : unit =
  let (_, stenvref) = env in
  let stenv = !stenvref in
  if StoreIDHashTable.mem stenv stid then
    StoreIDHashTable.replace stenv stid value
  else
    assert false


let find_location_value (env : environment) (stid : StoreID.t) : syntactic_value option =
  let (_, stenvref) = env in
  StoreIDHashTable.find_opt (!stenvref) stid


module MathContext
: sig
    type t
    val make : input_context -> t
    val context_for_text : t -> input_context
    val context_main : t -> HorzBox.context_main
    val convert_math_variant_char : input_context -> string -> HorzBox.math_kind * Uchar.t list
    val color : t -> color
    val set_color : color -> t -> t
    val enter_script : t -> t
    val math_char_class : t -> HorzBox.math_char_class
    val set_math_char_class : HorzBox.math_char_class -> t -> t
    val is_in_base_level : t -> bool
    val actual_font_size : t -> (HorzBox.math_font_abbrev -> FontFormat.math_decoder) -> length
    val base_font_size : t -> length
    val math_font_abbrev : t -> HorzBox.math_font_abbrev
  end
= struct
    type level =
      | BaseLevel
      | ScriptLevel
      | ScriptScriptLevel

    type t =
      {
        mc_font_abbrev    : HorzBox.math_font_abbrev;
        mc_base_font_size : length;
        mc_level_int      : int;
        mc_level          : level;
        context_for_text  : input_context;
      }

    let make (ictx : input_context) : t =
      let (ctx, _) = ictx in
        {
          mc_font_abbrev    = ctx.HorzBox.math_font;
          mc_base_font_size = ctx.HorzBox.font_size;
          mc_level_int      = 0;
          mc_level          = BaseLevel;
          context_for_text  = ictx;
        }

    let convert_math_variant_char ((ctx, _) : input_context) (s : string) =
      let open HorzBox in
      let mcclsmap = ctx.math_variant_char_map in
      let mccls = ctx.math_char_class in
      let mkmap = ctx.math_class_map in
        match mkmap |> MathClassMap.find_opt s with
        | Some(uchlstaft, mk) ->
            (mk, uchlstaft)

        | None ->
            let uchlst = InternalText.to_uchar_list (InternalText.of_utf8 s) in
            let uchlstaft =
              uchlst |> List.map (fun uch ->
                match mcclsmap |> HorzBox.MathVariantCharMap.find_opt (uch, mccls) with
                | Some(uchaft) -> uchaft
                | None         -> uch
              )
            in
              (MathOrdinary, uchlstaft)

    let context_for_text (mctx : t) =
      mctx.context_for_text
        (* temporary; maybe should update font size *)

    let context_main (mctx : t) =
      let (ctx, _) = mctx.context_for_text in
        ctx

    let color (mctx : t) =
      let (ctx, _) = mctx.context_for_text in
        ctx.HorzBox.text_color

    let set_color (color : color) (mctx : t) =
      let (ctx, v) = mctx.context_for_text in
      let ctxnew = { ctx with HorzBox.text_color = color; } in
        { mctx with context_for_text = (ctxnew, v); }

    let math_char_class (mctx : t) =
      let (ctx, _) = mctx.context_for_text in
        ctx.HorzBox.math_char_class

    let set_math_char_class mccls (mctx : t) =
      let (ctx, v) = mctx.context_for_text in
      let ctxnew = { ctx with HorzBox.math_char_class = mccls } in
        { mctx with context_for_text = (ctxnew, v) }

    let enter_script mctx =
      let levnew = mctx.mc_level_int + 1 in
      match mctx.mc_level with
      | BaseLevel         -> { mctx with mc_level = ScriptLevel;       mc_level_int = levnew; }
      | ScriptLevel       -> { mctx with mc_level = ScriptScriptLevel; mc_level_int = levnew; }
      | ScriptScriptLevel -> { mctx with                               mc_level_int = levnew; }

    let is_in_base_level mctx =
      match mctx.mc_level with
      | BaseLevel -> true
      | _         -> false

    let actual_font_size mctx (mdf : HorzBox.math_font_abbrev -> FontFormat.math_decoder) =
      let bfsize = mctx.mc_base_font_size in
      let md = mdf mctx.mc_font_abbrev in
      let mc = FontFormat.get_math_constants md in
      match mctx.mc_level with
      | BaseLevel         -> bfsize
      | ScriptLevel       -> bfsize *% mc.FontFormat.script_scale_down
      | ScriptScriptLevel -> bfsize *% mc.FontFormat.script_script_scale_down

    let base_font_size mctx =
      mctx.mc_base_font_size

    let math_font_abbrev mctx =
      mctx.mc_font_abbrev

  end


type math_context = MathContext.t

(*
(* !!!! ---- global variable ---- !!!! *)

let global_hash_env : (string, location) Hashtbl.t = Hashtbl.create 32
*)

(* -- following are all for debugging -- *)

let string_of_record_type (type a) (f : a typ -> string) (asc : (a typ) Assoc.t) =
  let rec aux lst =
    match lst with
    | []                     -> " -- "
    | (fldnm, tystr) :: []   -> fldnm ^ " : " ^ (f tystr)
    | (fldnm, tystr) :: tail -> fldnm ^ " : " ^ (f tystr) ^ "; " ^ (aux tail)
  in
    "(|" ^ (aux (Assoc.to_list asc)) ^ "|)"


let string_of_kind (type a) (f : a typ -> string) (kdstr : a kind) =
  let rec aux lst =
    match lst with
    | []                     -> " -- "
    | (fldnm, tystr) :: []   -> fldnm ^ " : " ^ (f tystr)
    | (fldnm, tystr) :: tail -> fldnm ^ " : " ^ (f tystr) ^ "; " ^ (aux tail)
  in
    match kdstr with
    | UniversalKind   -> "U"
    | RecordKind(asc) -> "(|" ^ (aux (Assoc.to_list asc)) ^ "|)"


let rec string_of_type_basic tvf tystr : string =
  let iter = string_of_type_basic tvf in
  let (rng, tymain) = tystr in
  let qstn = if Range.is_dummy rng then "%" else "" in
    match tymain with
    | BaseType(EnvType)     -> "env" ^ qstn
    | BaseType(UnitType)    -> "unit" ^ qstn
    | BaseType(BoolType)    -> "bool" ^ qstn
    | BaseType(IntType)     -> "int" ^ qstn
    | BaseType(FloatType)   -> "float" ^ qstn
    | BaseType(StringType)  -> "string" ^ qstn
    | BaseType(TextRowType) -> "inline-text" ^ qstn
    | BaseType(TextColType) -> "block-text" ^ qstn
    | BaseType(BoxRowType)  -> "inline-boxes" ^ qstn
    | BaseType(BoxColType)  -> "block-boxes" ^ qstn
(*
    | BaseType(FontType)    -> "font" ^ qstn
*)
    | BaseType(ContextType) -> "context" ^ qstn
    | BaseType(PrePathType) -> "pre-path" ^ qstn
    | BaseType(PathType)    -> "path" ^ qstn
    | BaseType(LengthType)  -> "length" ^ qstn
    | BaseType(GraphicsType) -> "graphics" ^ qstn
    | BaseType(ImageType)    -> "image" ^ qstn
    | BaseType(DocumentType) -> "document" ^ qstn
    | BaseType(MathType)     -> "math" ^ qstn
    | BaseType(RegExpType)   -> "regexp" ^ qstn

    | VariantType(tyarglist, tyid) ->
        (string_of_type_argument_list_basic tvf tyarglist) ^ (TypeID.show_direct tyid) (* temporary *) ^ "@" ^ qstn

    | SynonymType(tyarglist, tyid, tyreal) ->
        (string_of_type_argument_list_basic tvf tyarglist) ^ (TypeID.show_direct tyid) ^ "@ (= " ^ (iter tyreal) ^ ")"

    | FuncType(tyoptsr, tydom, tycod) ->
        let stropts =
          !tyoptsr |> List.map (fun ((_, tymain) as ty) ->
            let s = iter ty in
              match tymain with
              | FuncType(_, _, _)
              | ProductType(_)
              | VariantType(_ :: _, _)
                   -> "(" ^ s ^ ")? -> "

              | _ -> s ^ "? -> "
          )
        in
        let strdom = iter tydom in
        let strcod = iter tycod in
          (String.concat "" stropts) ^
          begin match tydom with
          | (_, FuncType(_, _, _)) -> "(" ^ strdom ^ ")"
          | _                      -> strdom
          end ^ " ->" ^ qstn ^ " " ^ strcod

    | ListType(tycont) ->
        let strcont = iter tycont in
        let (_, tycontmain) = tycont in
          begin match tycontmain with
          | FuncType(_, _, _)
          | ProductType(_)
          | ListType(_)
          | RefType(_)
          | VariantType(_ :: _, _)
(*          | TypeSynonym(_ :: _, _, _) *)
              -> "(" ^ strcont ^ ")"
          | _ -> strcont
          end ^ " list" ^ qstn

    | RefType(tycont) ->
        let strcont = iter tycont in
        let (_, tycontmain) = tycont in
          begin match tycontmain with
          | FuncType(_, _, _)
          | ProductType(_)
          | ListType(_)
          | RefType(_)
          | VariantType(_ :: _, _)
(*          | TypeSynonym(_ :: _, _, _) *)
              -> "(" ^ strcont ^ ")"

          | _ -> strcont
          end ^ " ref" ^ qstn

    | ProductType(tylist) ->
        string_of_type_list_basic tvf tylist

    | TypeVariable(tvi) ->
        tvf qstn tvi

    | RecordType(asc) ->
        string_of_record_type iter asc

    | HorzCommandType(tylist) ->
        let slist = List.map (string_of_command_argument_type tvf) tylist in
        "[" ^ (String.concat "; " slist) ^ "] horz-command"

    | VertCommandType(tylist)   ->
        let slist = List.map (string_of_command_argument_type tvf) tylist in
        "[" ^ (String.concat "; " slist) ^ "] vert-command"

    | MathCommandType(tylist)   ->
        let slist = List.map (string_of_command_argument_type tvf) tylist in
        "[" ^ (String.concat "; " slist) ^ "] math-command"


and string_of_command_argument_type tvf = function
  | MandatoryArgumentType(ty) -> string_of_type_basic tvf ty
  | OptionalArgumentType(ty)  -> "(" ^ (string_of_type_basic tvf ty) ^ ")?"


and string_of_type_argument_list_basic tvf tyarglist =
  match tyarglist with
  | []           -> ""
  | head :: tail ->
      let strhd = string_of_type_basic tvf head in
      let strtl = string_of_type_argument_list_basic tvf tail in
      let (_, headmain) = head in
        begin
          match headmain with
          | FuncType(_, _, _)
          | ProductType(_)
            (* | TypeSynonym(_ :: _, _, _) *) (* temporary *)
          | ListType(_)
          | RefType(_)
          | VariantType(_ :: _, _)
              -> "(" ^ strhd ^ ")"
          | _ -> strhd
        end ^ " " ^ strtl


and string_of_type_list_basic tvf tylist =
  match tylist with
  | []           -> ""
  | head :: []   ->
      let strhd = string_of_type_basic tvf head in
      let (_, headmain) = head in
        begin
          match headmain with
          | ProductType(_)
          | FuncType(_, _, _)
              -> "(" ^ strhd ^ ")"
          | _ -> strhd
        end
  | head :: tail ->
      let strhd = string_of_type_basic tvf head in
      let strtl = string_of_type_list_basic tvf tail in
      let (_, headmain) = head in
        begin
          match headmain with
          | ProductType(_)
          | FuncType(_, _, _)
              -> "(" ^ strhd ^ ")"
          | _ -> strhd
        end ^ " * " ^ strtl

let rec string_of_mono_type_basic ty =
  let tvf qstn tvref =
    match !tvref with
    | MonoLink(tyl)  -> "$(" ^ (string_of_mono_type_basic tyl) ^ ")"
    | MonoFree(tvid) -> "'" ^ (FreeID.show_direct (string_of_kind string_of_mono_type_basic) tvid) ^ qstn
  in
    string_of_type_basic tvf ty


let rec string_of_poly_type_basic (Poly(pty)) =
  let ptvf qstn ptvi =
    match ptvi with
    | PolyBound(bid) ->
        "'#" ^ (BoundID.show_direct (string_of_kind (fun ty -> string_of_poly_type_basic (Poly(ty)))) bid) ^ qstn

    | PolyFree(tvref) ->
        begin
          match !tvref with
          | MonoFree(tvid) -> "'" ^ (FreeID.show_direct (string_of_kind string_of_mono_type_basic) tvid) ^ qstn
          | MonoLink(ty)   -> string_of_mono_type_basic ty
        end
  in
    string_of_type_basic ptvf pty


and string_of_kind_basic kd = string_of_kind string_of_mono_type_basic kd

(*
let rec string_of_manual_type (_, mtymain) =
  let iter = string_of_manual_type in
  let iter_cmd = string_of_manual_command_argument_type in
  match mtymain with
  | MTypeName(mtylst, mdlnmlst, tynm) -> (String.concat " " (List.map iter mtylst)) ^ " " ^ (String.concat "." (List.append mdlnmlst [tynm]))
  | MTypeParam(tpnm)          -> "'" ^ tpnm
  | MFuncType(mtyopts, mtydom, mtycod) -> (String.concat "" (List.map iter mtyopts)) (iter mtydom) ^ " -> " ^ (iter mtycod)
  | MOptFuncType(mtydom, mtycod) -> "(" ^ (iter mtydom) ^ ")? -> " ^ (iter mtycod)
  | MProductType(mtylst)      -> (String.concat " * " (List.map iter mtylst))
  | MRecordType(mtyasc)       -> "(|" ^ (String.concat "; " (List.map (fun (fldnm, mty) -> fldnm ^ " : " ^ (iter mty)) (Assoc.to_list mtyasc))) ^ "|)"
  | MHorzCommandType(mncatylst) -> "[" ^ (String.concat "; " (List.map iter_cmd mncatylst)) ^ "] inline-cmd"
  | MVertCommandType(mncatylst) -> "[" ^ (String.concat "; " (List.map iter_cmd mncatylst)) ^ "] block-cmd"
  | MMathCommandType(mncatylst) -> "[" ^ (String.concat "; " (List.map iter_cmd mncatylst)) ^ "] math-cmd"


and string_of_manual_command_argument_type = function
  | MMandatoryArgumentType(mnty) -> string_of_manual_type mnty
  | MOptionalArgumentType(mnty)  -> "(" ^ (string_of_manual_type mnty) ^ ")?"
*)
