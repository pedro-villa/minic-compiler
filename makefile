CC = gcc
CFLAGS = -Wall -Wextra -Wno-unused-function -Wno-unused-result -g -Isrc
JAVA = java

# Project directories
SRCDIR = src
EXDIR  = examples
TOOLDIR = tools

SOURCES = $(SRCDIR)/miniC.tab.c $(SRCDIR)/lex.yy.c $(SRCDIR)/main.c \
          $(SRCDIR)/listaSimbolos.c $(SRCDIR)/listaCodigo.c

all: miniC

miniC: $(SOURCES) $(SRCDIR)/miniC.tab.h
	$(CC) $(CFLAGS) $(SOURCES) -o miniC

$(SRCDIR)/lex.yy.c: $(SRCDIR)/miniC.l $(SRCDIR)/miniC.tab.h
	flex -o $(SRCDIR)/lex.yy.c $(SRCDIR)/miniC.l

$(SRCDIR)/miniC.tab.c $(SRCDIR)/miniC.tab.h: $(SRCDIR)/miniC.y
	bison -d -v -o $(SRCDIR)/miniC.tab.c $(SRCDIR)/miniC.y

test: miniC
	@echo "==> Compiling functional test suite..."
	./miniC $(EXDIR)/pruebaFuncionalidades.miniC > $(EXDIR)/miniC.asm
	@echo "==> Simulating with MARS in headless mode..."
	echo "42" | $(JAVA) -jar $(TOOLDIR)/Mars4_5.jar nc $(EXDIR)/miniC.asm

clean:
	rm -f miniC miniC.exe
	rm -f $(SRCDIR)/lex.yy.c $(SRCDIR)/miniC.tab.* $(SRCDIR)/miniC.output
	rm -f $(EXDIR)/*.asm *.asm

.PHONY: all test clean
