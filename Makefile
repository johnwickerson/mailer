EXECUTABLE=mailer

all: parser.mly lexer.mll mailer.ml
	ocamlyacc parser.mly
	ocamllex lexer.mll
	ocamlc parser.mli parser.ml lexer.ml mailer.ml -o ${EXECUTABLE}

clean:
	rm -f *.cmo
	rm -f *.cmi
	rm -f ${EXECUTABLE}

