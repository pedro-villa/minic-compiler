#include <stdio.h>
#include <stdlib.h>

extern char *yytext;
extern int yylex();
extern FILE *yyin;  
extern int yyparse();
extern int errores;

int main (int argc, char **argv){
    if (argc != 2) {
        printf("Uso: %s fichero\n", argv[0]);
        exit(1);
    }
    
    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        printf("No se puede abrir %s\n", argv[1]);
        exit(2);
    }

    // int token; 
    // while ((token = yylex()) != 0) {
    //     printf("Token %d:\t%s\n", token, yytext); 
    // }
    int res = yyparse(); // Devuelve 0 si todo va bien
    fclose(yyin);
    return (res != 0 || errores != 0) ? 1 : 0;
}