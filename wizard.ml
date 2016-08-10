
module Option = struct
  let value ~default o = match o with
  | None -> default
  | Some v -> v

  let map ~f o =
    match o with
    | None -> None
    | Some v -> f v
end

type setting = { value: string;
                 var: string;
                 explanation: string list;
                 action: string option; }
type section =
    Nfs of setting list
  | Cluster of setting list
  | Biokepi_machine of setting list

type config = section list

let section_explanation s =
  match s with
  | Nfs _ -> "Configuration for the NFS server deployment"
  | Cluster _ -> "Configuration for a Ketrew cluster deployment"
  | Biokepi_machine _ ->
    "Configuration for a Biokepi.Machine.t, used to submit workflows."

let settings s =
  match s with
  | Nfs settings -> settings
  | Cluster settings -> settings
  | Biokepi_machine settings -> settings

let render_setting s =
  let nl = "\n" in
  let explanation =
    List.map (fun l -> Printf.sprintf "# %s" l) s.explanation
    |> String.concat "\n"
  in
  explanation
  ^ nl ^
  Printf.sprintf "export %s=\"%s\"\n" s.var s.value
  ^ Option.value s.action ~default:""
  ^ nl ^ nl

let render_section s =
  let settings = List.map render_setting (settings s) in
  String.concat "\n"
    (String.make 80 '#'
     :: ["## " ^ (section_explanation s) ^ "\n\n"]
     @ settings)

let is_blank s = s = ""
let is_question s = (String.trim s) = "?"

let rec ask ?default ?action ?(explanation=[]) var question () =
  let () =
    match default with
    | None ->  Printf.printf "\n%s\n%!" question
    | Some d ->
      let default = d () in
      Printf.printf "\n%s\n (default=%s)\n%!" question default
  in
  let answer = read_line () |> String.trim in
  let value =
    if is_question answer then begin
      let expl = String.concat "\n" explanation in
      print_string ("\nInfo:\n" ^ expl ^ "\n" ^ "---------");
      None
    end else if is_blank answer then
      match default with
      | None ->
        print_string "Need an answer for this one!\n";
        None
      | Some d ->
        print_string " ...Using default.\n\n";
        Some (d ())
    else Some answer
  in
  match value with
  | None -> ask ?default ?action ~explanation var question ()
  | Some value ->
    let action = Option.map ~f:(fun a -> Some (a value)) action in
    { value; var; explanation; action }


let cluster_config_questions =
  let prefix =
    let explanation = [
    "You need to choose a prefix for all the names generated by the scripts and";
    "Google tools:";
    "- This name will show up in the WebUIs of Google-cloud";
    "- Don't use more than 15 characters because GCE has some limitations on";
    "  names' lengths"; ] in
    ask ~explanation "PREFIX" "What is your deployment's prefix (< 16 chars)?";
  in
  let gcloud_zone =
    let explanation = ["GCloud zone for your cluster."] in
    let default () =  "us-east1-c" in
    let action v = Printf.sprintf "gcloud config set compute/zone %s" v in
    ask ~explanation ~action ~default
      "GCLOUD_ZONE" "Which GCloud zone are you in?" in
  let token =
    let explanation = ["An authentication token for the Ketrew server."] in
    let default () = "RANDOMSTRING" in
    ask ~explanation ~default "TOKEN" "What secure token should you use?"
  in
  [ prefix;
    gcloud_zone;
    token;
  ]

let main () =
  Cluster (List.map (fun q -> q ()) cluster_config_questions)
  |> render_section
  |> print_string

let () =
  main ()
