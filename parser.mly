%{

let string_of_chars chars = 
  let buf = Buffer.create 1000 in
  List.iter (Buffer.add_char buf) chars;
  Buffer.contents buf
    
%}

%token <char> CHAR
%token <string> STRING
%token COMMA CRLF EOF

%start templatetext
%start csvtext

%type <(bool * string) list> templatetext
%type <string list list> csvtext
%type <string list> csvrow
%type <string> csventry
%type <char list> chars

%%

templatetext:
  EOF                   { [] }
| chars templatetext    { (true, string_of_chars $1) :: $2 }
| STRING templatetext   { (false, $1) :: $2 }
;

csvtext:
  EOF                   { [] }
| csvrow EOF            { [$1] }
| csvrow CRLF csvtext   { $1 :: $3 }
;

csvrow:
                        { [] }
| csventry              { [$1] }
| csventry COMMA csvrow { $1 :: $3 }
;

csventry:
  chars                 { string_of_chars $1 }
| STRING                { $1 }
;

chars:
                        { [] }
| CHAR chars            { $1 :: $2 }
;

%%
