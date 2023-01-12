{

let buffer = Buffer.create 8192

let reset_string_buffer () =
  Buffer.reset buffer

let store_string_char c =
  Buffer.add_char buffer c

let get_stored_string () =
  let s = Buffer.contents buffer in
  Buffer.reset buffer;
  s
  
}

rule lex_template = parse
| eof                          { Parser.EOF }   
| '$' '{' ([^ '}']+ as x) '}'  { Parser.STRING x }
| _ as x                       { Parser.CHAR x }

and lex_csv = parse
| eof                          { Parser.EOF }  
| ","                          { Parser.COMMA }
| "\n"                         { Parser.CRLF }
| "\r\n"                       { Parser.CRLF }
| '{' ([^ '}']* as x) '}'      { Parser.STRING x }
| '"' ([^ '"']* as x) '"'      { Parser.STRING x }
| _ as x                       { Parser.CHAR x }
