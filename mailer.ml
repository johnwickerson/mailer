open Format

let the : 'a option -> 'a =
  function
  | Some x -> x
  | None -> failwith "Found None, expected Some!"
   
let template_file : string option ref = ref None
let csv_file : string option ref = ref None
let output_dir : string ref = ref "."
                 
let args_spec =
  [
    ("-template", Arg.String (fun s -> template_file := Some s),
     "text file containing email template");
    ("-csv", Arg.String (fun s -> csv_file := Some s),
     "CSV file containing data to be mail-merged");
    ("-o", Arg.String (fun s -> output_dir := s),
     "Output directory for AppleScript files; default is current directory");
  ]

let usage = "Usage: mailer [options]\nOptions are:"

let tryparse parse lex buf =
  try
    parse lex buf
  with
    Parsing.Parse_error | Failure _ ->
       failwith (sprintf "Parse error at character %d.\n" (Lexing.lexeme_start buf))
  
          
let main () =
  Arg.parse args_spec (fun _ -> ()) usage;
  
  if !template_file = None then
    failwith "Template file not provided.";    
  printf "Template file is %s.\n" (the !template_file);
  let template_chan = open_in (the !template_file) in
  let template_buff = Lexing.from_channel template_chan in
  let template = tryparse Parser.templatetext Lexer.lex_template template_buff in
  
  (*
  List.iter (fun (b,s) ->
      if b then printf "Normal(%s)\n" s else printf "Macro(%s)\n" s)
    template;
   *)

  if !csv_file = None then
    failwith "CSV file not provided.";  
  printf "CSV file is %s.\n" (the !csv_file);
  let csv_chan = open_in (the !csv_file) in
  let csv_buff = Lexing.from_channel csv_chan in
  let parsed_csv = tryparse Parser.csvtext Lexer.lex_csv csv_buff in

  (* List.iter (fun row ->
      List.iter (fun entry ->
          printf "%s," entry
    ) row; printf "\n") parsed_csv;
   *)

  let headings, rows = match parsed_csv with
    | [] -> failwith "Expected at least one row in CSV file."
    | h :: t -> (h, t)
  in

  let rec lookup s = function
    | [], _ -> false, s
    | _, [] -> true, ""
    | h :: headings, e :: row ->
       if h = s then true, e else lookup s (headings, row)
  in

  let instantiate row = function
    | true, s -> true, s
    | false, s -> lookup s (headings, row)    
  in

  let print_template_item = function
    | true, s -> printf "%s" s
    | false, s -> printf "${%s}" s
  in
  
  List.iter (fun row ->
      let instance = List.map (instantiate row) template in
      printf "tell application \"Mail\"\n";
      printf "set newMessage to make new outgoing message with properties {sender:\"John Wickerson <j.wickerson@imperial.ac.uk>\"";
      List.iter print_template_item instance;
      printf "\n"
    ) rows;
  
  printf "Finished.\n"

let _ =
  main ()
