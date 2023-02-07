(*
MIT License

Copyright (c) 2022 by John Wickerson.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*)

(** A mail-merge tool for Mac OS X *)

open Format

let the : 'a option -> 'a =
  function
  | Some x -> x
  | None -> failwith "Found None, expected Some!"
   
let template_file : string option ref = ref None
let csv_file : string option ref = ref None
let email_subject : string ref = ref ""
let default_sender_name = "John Wickerson"
let sender_name : string ref = ref default_sender_name
let default_sender_email = "j.wickerson@imperial.ac.uk"
let sender_email : string ref = ref default_sender_email
let cc_list : string list ref = ref []
let bcc_list : string list ref = ref []
let dry_run : bool ref = ref false
let only_first_row : bool ref = ref false
                               
let args_spec =
  [
    ("-template", Arg.String (fun s -> template_file := Some s),
     "text file containing email body (required)");
    ("-csv", Arg.String (fun s -> csv_file := Some s),
     "CSV file containing data to be mail-merged (required)");
    ("-subject", Arg.Set_string email_subject,
     "email subject (default is blank)");
    ("-sendername", Arg.Set_string sender_name,
     sprintf "sender name (default is \"%s\")" default_sender_name);
    ("-senderemail", Arg.Set_string sender_email,
     sprintf "sender email (default is \"%s\")" default_sender_email);
    ("-cc", Arg.String (fun s -> cc_list := s :: !cc_list),
     "Add a cc recipient (can be used multiple times)");
    ("-bcc", Arg.String (fun s -> bcc_list := s :: !bcc_list),
     "Add a bcc recipient (can be used multiple times)");
    ("-dryrun", Arg.Set dry_run,
     "Generate the Applescripts but don't actually execute them (default is false)");
    ("-onlyfirstrow", Arg.Set only_first_row,
     "Only process the first row of the CSV file, useful when testing (default is false)");
  ]

let usage = "Usage: mailer [options]\nOptions are:"

let tryparse parse lex buf =
  try
    parse lex buf
  with
    Parsing.Parse_error | Failure _ ->
       failwith (sprintf "Parse error at character %d.\n" (Lexing.lexeme_start buf))

let replace_in_file f from into =
  let ic = open_in f in
  let out_file = f ^ ".tmp" in
  let oc = open_out out_file in
  begin try
      while true do
        let s = input_line ic in
        let s = Str.global_replace (Str.regexp_string from) into s in
        output_string oc (s ^ "\n")
      done     
    with
      End_of_file -> close_out oc
  end;
  out_file
  
          
let main () =
  Arg.parse args_spec (fun _ -> ()) usage;
  
  if !template_file = None then (
    Arg.usage args_spec usage;
    failwith "Template file not provided.";
  );
  let template_chan = open_in (the !template_file) in
  let template_buf = Lexing.from_channel template_chan in
  let template = tryparse Parser.templatetext Lexer.lex_template template_buf in
  
  if !csv_file = None then (
    Arg.usage args_spec usage;
    failwith "CSV file not provided.";
  );
  let csv_file_mod =
    (* Replace two consecutive double-quotes ("") with a single backtick (`) in CSV file.
       This is because of how Apple Numbers exports CSV files. *)
    replace_in_file (the !csv_file) "\"\"" "`"
  in
  let csv_chan = open_in csv_file_mod in
  let csv_buf = Lexing.from_channel csv_chan in
  let parsed_csv = tryparse Parser.csvtext Lexer.lex_csv csv_buf in

  (* First row of CSV file is assumed to contain column headings. *)
  let headings, rows = match parsed_csv with
    | [] -> failwith "Expected at least one row in CSV file."
    | h :: t -> (h, t)
  in

  (* Find the entry for the column named `s` in the given `row`. *)
  let lookup s row = 
    let rec lookup s = function
      | [], _ -> false, s
      | _, [] -> true, ""
      | h :: headings, e :: row ->
         if h = s then true, e else lookup s (headings, row)
    in
    lookup s (headings, row)
  in

  (* Return a list of all the email addresses in the given `row`. These are identified
     by columns that have a name beginning with "email". *)
  let lookup_emails row =
    let rec lookup_emails = function
      | [], _ -> []
      | _, [] -> []
      | h :: headings, e :: row ->
         (if Str.string_match (Str.regexp_string "email") h 0 then [e] else []) @
           lookup_emails (headings, row)
    in
    lookup_emails (headings, row)
  in

  (* Return a list of all the file attachments in the given `row`. These are identified
     by columns that have a name beginning with "attach". An example of a valid file
     path is "Macintosh HD:Users:jpw48:git:langproc-2019-private:lab:scripts:a09.txt". *)
  let lookup_attachments row =
    let rec lookup_attachments = function
      | [], _ -> []
      | _, [] -> []
      | h :: headings, e :: row ->
         (if Str.string_match (Str.regexp_string "attach") h 0 then [e] else []) @
           lookup_attachments (headings, row)
    in
    lookup_attachments (headings, row)
  in

  let instantiate row = function
    | true, s -> true, s
    | false, s -> lookup s row    
  in

  let template_item_to_string oc = function
    | true, s -> fprintf oc "%s" s
    | false, s -> fprintf oc "${%s}" s
  in

  (* Produce a timestamp of the form "YYYYMMDD-HHMMSS" *)
  let timestamp =
    let t = Unix.gmtime (Unix.time ()) in
    sprintf "%04d%02d%02d-%02d%02d%02d"
      (1900 + t.Unix.tm_year) (1 + t.Unix.tm_mon) t.Unix.tm_mday
      t.Unix.tm_hour t.Unix.tm_min t.Unix.tm_sec
  in

  (* Make a timestamped output directory to hold the generated applescripts. *)
  let output_dir = "out-" ^ timestamp in
  Sys.mkdir output_dir 0o755;
  
  let do_row i row =
    let scpt_file = Filename.concat output_dir (sprintf "mailer_%d.scpt" i) in
    let oc = open_out scpt_file in
    let ocf = formatter_of_out_channel oc in
    let instance = List.map (instantiate row) template in
    let recipient_emails = lookup_emails row in
    let attachments = lookup_attachments row in
    
    fprintf ocf "tell application \"Mail\"\n";
    fprintf ocf "  set newMessage to make new outgoing message with properties {";
    fprintf ocf "sender:\"%s <%s>\", " !sender_name !sender_email;
    fprintf ocf "subject:\"%s\", " !email_subject;
    fprintf ocf "content:\"";
    List.iter (template_item_to_string ocf) instance;
    fprintf ocf "  \"}\n";
    fprintf ocf "  tell newMessage\n";
    fprintf ocf "    set visible to true\n";
    List.iter (fun recipient_email ->
        fprintf ocf "    make new to recipient at end of to recipients with ";
        fprintf ocf "properties {address:\"%s\"}\n" recipient_email;
      ) recipient_emails;
    List.iter (fun cc ->
        fprintf ocf "    make new cc recipient at end of cc recipients with ";
        fprintf ocf "properties {address:\"%s\"}\n" cc;
      ) !cc_list;
    List.iter (fun bcc ->
        fprintf ocf "    make new bcc recipient at end of bcc recipients with ";
        fprintf ocf "properties {address:\"%s\"}\n" bcc;
      ) !bcc_list;

    List.iter (fun a ->
        fprintf ocf "    make new attachment with ";
        fprintf ocf "      properties {file name:\"%s\" as alias}" a;
        fprintf ocf "      at after the last word of the last paragraph\n")
      attachments;
    
    fprintf ocf "  end tell\n";
    (*fprintf ocf "activate\n";*)
    fprintf ocf "end tell\n";
    close_out oc;
    
    (* Run the generated applescript. *)
    if not !dry_run then
      let _ = Sys.command (sprintf "osascript %s" scpt_file) in ()
  in
  
  if !only_first_row then
    do_row 0 (List.hd rows)
  else
    List.iteri do_row rows;
  
  printf "Finished.\n"

let _ =
  main ()
