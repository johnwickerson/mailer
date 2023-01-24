EXECUTABLE=mailer

all: parser.mly lexer.mll mailer.ml
	ocamlyacc parser.mly
	ocamllex lexer.mll
	ocamlc unix.cma str.cma parser.mli parser.ml lexer.ml mailer.ml -o ${EXECUTABLE}

install:
	mv ${EXECUTABLE} ~/bin/${EXECUTABLE}

uninstall:
	rm -f ~/bin/${EXECUTABLE}

clean:
	rm -f *.cmo
	rm -f *.cmi
	rm -f lexer.ml parser.ml parser.mli
	rm -f ${EXECUTABLE}

deepclean:
	rm -rf out-*
