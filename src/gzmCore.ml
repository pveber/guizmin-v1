open Printf

type path = string

module Param = struct
  type t =
    | Int : string * int -> t
    | String : string * string -> t
    | Float : string * float -> t
    | Bool : string * bool -> t
    | Option : (string -> 'a -> t) * string * 'a option -> t

  let string id v = String (id, v)
  let int id v = Int (id, v)
  let float id v = Float (id, v)
  let bool id b = Bool (id, b)
  let opt f id v = Option (f, id, v)
end
type id = string * Param.t list

let mkdir s = 
  if not (Sys.file_exists s) then 
    Unix.mkdir s 0o755
  else
    assert (Sys.is_directory s)

let home_dir    = Sys.getcwd ()
let guizmin_dir = home_dir ^ "/_guizmin"
let cache_dir = guizmin_dir ^ "/cache"
let build_dir = guizmin_dir ^ "/_build"
let tmp_dir = guizmin_dir ^ "/tmp"

let _ = 
  mkdir guizmin_dir ;
  mkdir cache_dir ;
  mkdir build_dir ;
  mkdir tmp_dir

let hash x = x # hash

let path x = 
  cache_dir ^ "/" ^ (hash x)

let tmp_path x = 
  tmp_dir ^ "/" ^ (hash x)

let touch fn =
  ignore (Sys.command ("touch " ^ fn))

class dep (id : id) kind deps = 
object (self)
  method deps : dep list = deps

  method hash = 
    let content = id, kind, List.map (fun x -> x#hash) deps in
    Digest.to_hex (Digest.string (Marshal.to_string content []))

  method path = 
    cache_dir ^ "/" ^ (hash self)

  method tmp_path = 
    tmp_dir ^ "/" ^ (hash self)

  method clean = 
    Sys.remove self # path

  method built =
    Sys.file_exists self#path
end

let as_dep x = (x :> dep)

type env = {
  bash : string list -> unit ;
  stdout : out_channel ;
  stderr : out_channel ;
  np : int ; 
}

class type ['a] pipeline = object
  inherit dep
  method eval : env -> 'a
end

let eval ?(stdout = stdout) ?(stderr = stderr) ?(np = 1) x = 
  let env = { stderr ; stdout ; np ; 
              bash = fun l -> GzmUtils.bash ~stdout ~stderr l } in
  x # eval env


let load_value path = 
  let ic = open_in path in 
  let r = input_value ic in
  close_in ic ; r

let save_value v path = 
  let oc = open_out path in 
  output_value oc v ;
  close_out oc 

let value id f deps = 
object (self)
  inherit dep id `value deps
  method eval env = 
    let dest = self#path
    and tmp = self#tmp_path in
    if not self#built then (
      let r = f env in
      save_value r tmp ;
      Sys.rename tmp dest ;
      r
    )
    else (
      touch dest ;
      load_value dest
    )
end

let v0 id f = value id f []

let v1 id f x = 
  value id (fun env -> f env (x#eval env)) [ as_dep x ]

let v2 id f x y = 
  value id (fun env -> f env (x#eval env) (y#eval env)) [ as_dep x ; as_dep y ]

type 'a file_path = File of path
type 'a file = 'a file_path pipeline
type 'a dir_path  = Dir of path
type 'a dir = 'a dir_path pipeline

let path_pipeline kind cons id f children =
object (self)
  inherit dep id kind children 
  method eval env = 
    let dest = self#path
    and tmp = self#tmp_path in 
    if not self#built then (
      f env tmp ;
      Sys.rename tmp dest ;
    ) ;
    touch dest ;
    cons dest
  method clean = Sys.remove (* FIXME (path s)*)""
end

let file_cons x = File x

let file path = 
object (self)
  inherit dep ("guizmin.file.input", [ Param.string "path" path ]) `file []
  method clean = ()
  method built = Sys.file_exists path
  method eval env = 
    if not self#built then (
      fprintf env.stderr "File %s is declared as an input of a pipeline but does not exist." path ;
      assert false
    ) ;
    (* FIXME: we should also check that [path] is indeed a regular file *)
    File path
end


let f0 id f = path_pipeline `file  file_cons id f []
let f1 id f x = 
  path_pipeline 
    `file file_cons id 
    (fun env path -> f env (x#eval env) path) 
    [ as_dep x ]

let f2 id f x y = 
  path_pipeline
    `file file_cons id 
    (fun env path -> f env (x#eval env) (y#eval env) path) 
    [ as_dep x ; as_dep y ]

let f3 id f x y z = 
  path_pipeline
    `file file_cons id 
    (fun env path -> f env (x#eval env) (y#eval env) (z#eval env) path) 
    [ as_dep x ; as_dep y ; as_dep y ]

let dir path =
object (self)
  inherit dep ("guizmin.dir.input", [ Param.string "path" path ]) `dir []
  method eval env = 
    if not self#built then (
      fprintf env.stderr "Directory %s is declared as an input of a pipeline but does not exist." path ;
      assert false
    ) ;
    (* FIXME: we should also check that [path] is indeed a directory *)
    Dir path
end

let dir_cons x = Dir x

let d0 id f = 
  path_pipeline `dir dir_cons id f []

let d1 id f x = 
  path_pipeline 
    `dir dir_cons id 
    (fun env path -> f env (x#eval env) path) 
    [ as_dep x ]

let d2 id f x y = 
  path_pipeline 
    `dir dir_cons id 
    (fun env path -> f env (x#eval env) (y#eval env) path) 
    [ as_dep x ; as_dep y ]

let d3 id f x y z = 
  path_pipeline 
    `dir dir_cons id 
    (fun env path -> f env (x#eval env) (y#eval env) (z#eval env) path) 
    [ as_dep x ; as_dep y ; as_dep z ]

let select x subpath = 
object
  inherit dep ("guizmin.select", [Param.string "subpath" subpath]) `select [ as_dep x ]
  method eval env = 
    let Dir x_path = x#eval env in 
    let p = Filename.concat x_path subpath in
    if Sys.file_exists p 
    then File p
    else (
      let msg = sprintf "Tried to access %s in %s but there is no such file or directory." subpath x_path in
      failwith msg
    )
end

let merge l = 
object
  inherit dep ("guizmin.merge", []) `merge (List.map as_dep l)
  method eval env = List.map (fun x -> x#eval env) l
end

(* type _ pipeline = *)
(*     Input  : path -> (unit, 'a) pipeline *)
(*   | File   : string * param list * (unit -> unit) * 'a pipeline -> ('a, path) pipeline *)
(*   | File2  : string * param list * (unit -> unit) * 'a pipeline * 'b pipeline -> ('a * 'b, path) pipeline *)
(*   | Value  : string * param list * ('a -> 'b) * 'a pipeline -> ('a,'b) pipeline *)
(*   | Value2 : string * param list * (('a * 'b) -> 'c) * 'a pipeline * 'b pipeline -> ('a * 'b,'c) pipeline *)
(*   | Select : path * 'a pipeline -> 'b pipeline *)
(*   | Merge  : 'a pipeline list -> 'a list pipeline *)










