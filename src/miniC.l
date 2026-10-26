/* Sección de definiciones */
%{
    #include "miniC.tab.h" 
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #define MAX_INT 2147483647L
    #define MAX_ID 32
    extern int errores;
%}

letra [a-zA-Z_]
digito [0-9]
error [^ \n\t\r;,+\-/*=(){}?:<>!a-zA-Z_0-9]


/* Opción para contabilizar líneas */
%option yylineno
%option noyywrap

%x comentarioMulti

%%

[ \n\t\r]                               { }
"/*"                                    { BEGIN(comentarioMulti); }
<comentarioMulti>"*/"                   { BEGIN(INITIAL); }
<comentarioMulti>(?s:.)                 { } /* esto reconoce también el salto de línea y byte a byte */
<comentarioMulti><<EOF>>                {   
                                            fprintf(stderr, "Error en la línea %d: Comentario sin cerrar\n", yylineno);
                                            errores++;
                                            return 0; 
                                        }                                    
"//".*\n                                { }

";"                                     { return PYCOMA; }
","                                     { return COMA; }
"+"                                     { return SUMA; }
"-"                                     { return RESTA; }
"*"                                     { return MULT; }
"/"                                     { return DIV; }
"="                                     { return ASIG; }
"("                                     { return PARI; }
")"                                     { return PARD; }
"{"                                     { return LLAVEI; }
"}"                                     { return LLAVED; }
"?"                                     { return TERN; }
":"                                     { return DOSP; }
"var"                                   { return VAR; }
"const"                                 { return CONST; }
"int"                                   { return INT; }
"if"                                    { return IF; }
"else"                                  { return ELSE; }
"while"                                 { return WHILE; }
"print"                                 { return PRINT; }
"read"                                  { return READ; }
"do"                                    { return DO; }
"for"                                   { return FOR; }
"<"                                     { return LT; }
"<="                                    { return LE; }
">"                                     { return GT; }
">="                                    { return GE; }
"=="                                    { return EQ; }
"!="                                    { return NE; }
"!"                                     { return NOT; }

\"([^"\n\\]|\\.)*\"                     { 
                                            yylval.cadena = strdup(yytext);
                                            return STRING; } // Cualquier cosa menos comillas, \n y \ (solita) o cualquier carácter de escape (\t, \r...)
({letra})({letra}|{digito})*            { 
                                            if (strlen(yytext) > MAX_ID) {
                                                fprintf(stderr, "Error en la línea %d: Identificador demasiado largo, %s\n", yylineno, yytext);
                                                errores++;                                                
                                            }
                                            yylval.cadena = strdup(yytext);
                                            return ID;                                             
                                        }
{digito}+                               { 
                                            if (atol(yytext) > MAX_INT) {
                                                fprintf(stderr, "Error en la línea %d: Entero demasiado largo, %s\n", yylineno, yytext);
                                                errores++;
                                            } 
                                            yylval.cadena = strdup(yytext);  
                                            return NUM;                                             
                                        }   

 /* Errores */
\"([^"\n\\]|\\.)*                       { 
                                            fprintf(stderr, "Error en la línea %d: Cadena sin cerrar, %s\n", yylineno, yytext);
                                            errores++;
                                        }
                                        
 /* Expresión regular para detectar errores. Importante hacer bien porque es lo que más se revisa */
{error}+                                { 
                                            fprintf(stderr, "Error en la línea %d: Token no reconocido, %s\n", yylineno, yytext); 
                                            errores++;
                                        }
%%