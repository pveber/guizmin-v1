open Core.Std

open Guizmin_utils

type path = string list
type item =
  | Item : 'a Guizmin.pipeline * string * path -> item
let item ?(descr = "") path pipeline = Item (pipeline, descr, path)

type t = item list

let find_duplicate_paths repo =
  List.(
    map repo ~f:(function Item (_,_,x) -> x)
    |! find_a_dup
  )

let fail_on_duplicate_paths items = match find_duplicate_paths items with
| None -> ()
| Some p ->
    let path = String.concat ~sep:"/" p in
    failwithf "Path %s is present several times in the repo!" path ()

let create ?(np = 0) ?(wipeout = false) ?log ~base ~repo_base items =
  let log = match log with
    | None -> Guizmin_utils.null_logger
    | Some oc -> Guizmin_utils.logger stdout "INFO"
  in
  fail_on_duplicate_paths items ;
  if Sys.file_exists repo_base <> `Yes then sh "mkdir -p %s" repo_base ;
  if wipeout then sh "rm -rf %s/*" repo_base ;
  List.iter items ~f:(
    function Item (pipeline,_,rel_path)  ->
      let abs_path = repo_base ^ "/" ^ (String.concat ~sep:"/" rel_path) in
      (* Ensure the pipeline's built if asked to be so *)
      if np > 0 then (
	log "Building %s" abs_path ;
	Guizmin.build ~base ~np pipeline
      ) ;
      let cache_path = Guizmin.path ~base pipeline in

      (* Create link if needed *)
      let create_link =
	if Sys.file_exists abs_path = `Yes then Unix.(
	  if (lstat abs_path).st_kind <> S_LNK || readlink abs_path <> cache_path
	  then (
	    unlink abs_path ;
	    true
	  )
	  else false
	)
	else true
      in
      if create_link then (
	bash [
          sp "mkdir -p %s" (Filename.dirname abs_path) ;
          sp "ln -s `readlink -f %s` %s" cache_path abs_path
	]
      )
  )
