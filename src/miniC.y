%{
    #define _GNU_SOURCE
    #include <stdio.h>
    #include <string.h>
    #include <stdbool.h>
    #include <stdlib.h>
    #include <assert.h>
    #include "listaSimbolos.h"
    #include "listaCodigo.h"
    #include "expresionInfo.h"
    
    extern int yylex();
    extern int yylineno;
    int errores = 0;
    void yyerror(const char* msg);
    Lista l;
    int strCounter = 0;
    int etiqCounter = 0;
    bool enDeclaraciones = false;
    bool print = false;
    char registros[10];

    char* obtenerReg();
    void liberaReg(char* reg);
    
    // Funciones definidas por nosotros
    void imprimirLS(Lista l);
    void insertaIden(Tipo tipo, char* nombre, int valor);
    bool existeIden(char* nombre);
    void buscarIden(char* nombre, bool variable);
    void declarar_str(char* nombre);
    char* siguienteEtiqueta();

    void imprimirLC(ListaC codigo);

    ExpresionInfo creaExpresion(ListaC codigo, int valor);
    void liberaExpresion(ExpresionInfo info);
    ExpresionInfo expression_num(char* arg);
    ExpresionInfo expression_id(char* arg);
    ExpresionInfo expression_binop(ExpresionInfo expr1, ExpresionInfo expr2, char* oper);
    ExpresionInfo expression_ternop(ExpresionInfo expr1, ExpresionInfo expr2, ExpresionInfo expr3);
    ExpresionInfo expression_neg(ExpresionInfo expr);
    ExpresionInfo expression_logical_op(ExpresionInfo expr1, ExpresionInfo expr2, char* op);
    ExpresionInfo expression_logical_neg(ExpresionInfo expr);
    ExpresionInfo statement_asig(char* id, ExpresionInfo expr);
    ExpresionInfo print_item_str(char* str);
    ExpresionInfo print_item_expr(ExpresionInfo expr);
    ExpresionInfo statement_if(ExpresionInfo cond, ExpresionInfo expr);
    ExpresionInfo statement_if_else(ExpresionInfo cond, ExpresionInfo expr1, ExpresionInfo expr2);
    ExpresionInfo read_id(char* id);
    ExpresionInfo statement_while(ExpresionInfo cond, ExpresionInfo expr);
    ExpresionInfo statement_do_while(ExpresionInfo cond, ExpresionInfo expr);
    ExpresionInfo statement_for(char* varIter, ExpresionInfo exprMin, ExpresionInfo exprMax, ExpresionInfo expr);

    void imprimirRP(int n);
%}

// Incluye en el tab.h lo que haya aquí
%code requires {
    #include "listaCodigo.h"
    #include "expresionInfo.h"
}

// Definición de tipos de datos de simbolos de la gramática
%union {
    char* cadena;
    /* Si se quieren evaluar las constantes en tiempo de compilación, se puede usar una estructura
       para almacenar el valor de la constante. */
    ExpresionInfo info; 
}

/* Tipos de datos para no terminales */
%type <info> arithExpression logicExpression expression statement statement_list print_item print_list read_list

%define parse.error verbose

// No terminales de la gramática

%token          PYCOMA  ";"
%token          COMA    ","
%token          SUMA    "+"
%token          RESTA   "-"
%token          MULT    "*"
%token          DIV     "/"
%token          ASIG    "="
%token          PARI    "("
%token          PARD    ")"
%token          LLAVEI  "{"
%token          LLAVED  "}"
%token          TERN    "?"
%token          DOSP    ":"
%token          VAR     "var"
%token          CONST   "const"
%token          INT     "int"
%token          IF      "if"
%token          ELSE    "else"
%token          WHILE   "while"
%token          PRINT   "print"
%token          READ    "read"
%token <cadena> ID      "id"
%token <cadena> NUM     "num"
%token <cadena> STRING  "str"

%token          DO      "do"
%token          LT      "<"
%token          LE      "<="
%token          GT      ">"
%token          GE      ">="
%token          EQ      "=="
%token          NE      "!="

%token          NOT     "!"

%token          FOR     "for"

// Precedencia de operadores, las de más abajo tienen más precedencia
%left SUMA RESTA // cuando entra a + a, directamente se reduce al encontrarse otro +
%left MULT DIV
%precedence UMINUS

// La gramatica contiene un conflicto d/r por IF/IF-ELSE
// Bison lo resuelve bien por defecto (d en lugar de r)
%expect 1 // Significa que hay un conflicto d/r

%%

program         :  inicializar ID "(" ")" "{" {enDeclaraciones = true;} declarations {enDeclaraciones = false;} statement_list "}"      {
                        imprimirRP(0);
                        if (errores == 0) {
                            imprimirLS(l);
                            imprimirLC($9->codigo);
                        }
                        liberaLS(l);
                    }
                ;

inicializar     : %empty {
                        l = creaLS();
                        memset(registros, 0, sizeof(char)*10);
                    }
                ;

declarations    : declarations VAR tipo var_list ";"                    {imprimirRP(1);}
                | declarations CONST tipo const_list ";"                {imprimirRP(2);}
                | %empty                                                {imprimirRP(3);}
                ;

tipo            : INT                                                   {imprimirRP(4);}                 
                ;
var_list        : ID                                                    {
                        imprimirRP(5);
                        insertaIden(VARIABLE, $1, 0);
                    }
                | var_list "," ID                                       {
                        imprimirRP(6);
                        insertaIden(VARIABLE, $3, 0);
                    }
                ;
const_list      : ID "=" expression                                     {
                        imprimirRP(7);
                        insertaIden(CONSTANTE, $1, $3->valor);
                        if (errores == 0) {
                            char* res = recuperaResLC($3->codigo);
                            liberaReg(res);
                            liberaExpresion($3);
                        }
                    }
                | const_list "," ID "=" expression                      {
                        imprimirRP(8);
                        insertaIden(CONSTANTE, $3, $5->valor);
                        if (errores == 0) {
                            char* res = recuperaResLC($5->codigo);
                            liberaReg(res);
                            liberaExpresion($5);
                        }
                    }
                ;
statement_list  : statement_list statement                              {
                        imprimirRP(9);
                        if (errores == 0) {
                            $$ = $1;
                            concatenaLC($$->codigo, $2->codigo);
                            liberaExpresion($2);
                        }
                    }
                | %empty                                                {
                        if (errores == 0) $$ = creaExpresion(creaLC(), 0);
                    }
                ;
statement       : ID "=" expression ";"                                 {
                        imprimirRP(10);
                        buscarIden($1, true);
                        if (errores == 0) $$ = statement_asig($1, $3);
                    }
                | "{" statement_list "}"                                {
                        imprimirRP(11);
                        if (errores == 0) $$ = $2;
                    }
                | IF "(" expression ")" statement ELSE statement        {
                        imprimirRP(12);
                        if (errores == 0) $$ = statement_if_else($3, $5, $7);
                    }
                | IF "(" expression ")" statement                       {
                        imprimirRP(13);
                        if (errores == 0) $$ = statement_if($3, $5);
                    }
                | WHILE "(" expression ")" statement                    {
                        imprimirRP(14);
                        if (errores == 0) $$ = statement_while($3, $5);
                    }
                | PRINT "(" print_list ")" ";"                          {
                        imprimirRP(15);
                        if (errores == 0) $$ = $3;
                    }
                | READ "(" read_list ")" ";"                            {
                        imprimirRP(16);
                        if (errores == 0) $$ = $3;
                    }
                | DO statement WHILE "(" expression ")" ";"             {
                        imprimirRP(32);
                        if (errores == 0) $$ = statement_do_while($5, $2);
                    }
                | FOR "(" ID "," expression "," expression ")" statement {
                        imprimirRP(33);
                        buscarIden($3, true);
                        if(errores == 0) $$ = statement_for($3, $5, $7, $9);
                }
                | error ";" {
                    $$ = creaExpresion(creaLC(), 0);
                    printf("Error detectado en statement\n");
                    yyerrok;
                }
                ;
print_list      : print_item                                            {
                        imprimirRP(17);
                        if (errores == 0) $$ = $1;
                    }       
                | print_list "," print_item                             {
                        imprimirRP(18);
                        if (errores == 0) {
                            $$ = $1;
                            concatenaLC($$->codigo, $3->codigo);
                            liberaExpresion($3);
                        }
                    }   
                ;
print_item      : expression                                            {
                        imprimirRP(19);
                        if (errores == 0) $$ = print_item_expr($1);
                    }  
                | STRING                                                {
                        imprimirRP(20);
                        if(!existeIden($1)) declarar_str($1);
                        if (errores == 0) $$ = print_item_str($1);
                    }
                ;
read_list       : ID                                                    {
                        imprimirRP(21);
                        buscarIden($1, true);
                        if (errores == 0) $$ = read_id($1);
                    }
                | read_list "," ID                                      {
                        imprimirRP(22);
                        buscarIden($3, true);
                        if (errores == 0) {
                            $$ = $1;
                            ExpresionInfo aux = read_id($3);
                            concatenaLC($$->codigo, aux->codigo);
                            liberaExpresion(aux);
                        } 
                    }
                ;

expression      : arithExpression
                | logicExpression
                ;
                
arithExpression : arithExpression "+" arithExpression                             {
                        imprimirRP(23);
                        if (errores == 0) $$ = expression_binop($1, $3, "add");                        
                    }
                | arithExpression "-" arithExpression                             {
                        imprimirRP(24);
                        if (errores == 0) $$ = expression_binop($1, $3, "sub");                        
                    }
                | arithExpression "*" arithExpression                             {
                        imprimirRP(25);
                        if (errores == 0) $$ = expression_binop($1, $3, "mul");
                    }
                | arithExpression "/" arithExpression                             {
                        imprimirRP(26);
                        if (errores == 0) $$ = expression_binop($1, $3, "div");
                    }
                | "(" logicExpression "?" arithExpression ":" arithExpression ")"      {
                        imprimirRP(27);
                        if (errores == 0) $$ = expression_ternop($2, $4, $6);
                    }
                | "-" arithExpression %prec UMINUS                           {
                        imprimirRP(28);
                        if (errores == 0) $$ = expression_neg($2);
                    }
                | "(" arithExpression ")"                                    {
                        imprimirRP(29);
                        if (errores == 0) $$ = $2;
                    }
                | ID                                                    {
                        imprimirRP(30);
                        buscarIden($1, false); 
                        if (errores == 0) $$ = expression_id($1);
                    }
                | NUM                                                   {
                        imprimirRP(31);
                        if (errores == 0) $$ = expression_num($1);
                    }
                ;

logicExpression : arithExpression "<" arithExpression                             {
                        imprimirRP(33);
                        if (errores == 0) $$ = expression_logical_op($1, $3, "slt");
                    }
                | arithExpression "<=" arithExpression                            {
                        imprimirRP(34);
                        if (errores == 0) $$ = expression_logical_op($1, $3, "sle");
                    }
                | arithExpression ">" arithExpression                             {
                        imprimirRP(35);
                        if (errores == 0) $$ = expression_logical_op($1, $3, "sgt");
                    }
                | arithExpression ">=" arithExpression                            {
                        imprimirRP(36);
                        if (errores == 0) $$ = expression_logical_op($1, $3, "sge");
                    }
                | arithExpression "==" arithExpression                            {
                        imprimirRP(37);
                        if (errores == 0) $$ = expression_logical_op($1, $3, "seq");
                    }
                | arithExpression "!=" arithExpression                            {
                        imprimirRP(38);
                        if (errores == 0) $$ = expression_logical_op($1, $3, "sne");
                    }
                | "!" arithExpression                                        {
                        imprimirRP(39);
                        if (errores == 0) $$ = expression_logical_neg($2);
                    }
                ;

%%

void yyerror(const char* msg) {
    fprintf(stderr, "Error en la línea %d: %s\n", yylineno, msg);
    errores++;
}

bool existeIden(char* nombre) {
    return buscaLS(l, nombre) != finalLS(l);
}

void insertaIden(Tipo tipo, char* nombre, int valor) {
    // Comprobamos primero si existe un id con el mismo nombre en la lista de simbolos. Si lo hay, devolver error.
    if (existeIden(nombre)) {
        char* errorMsg;
        asprintf(&errorMsg, "identificador %s redeclarado", nombre);
        yyerror(errorMsg);
    }
    else {
        Simbolo aux = {nombre, tipo, valor};
        insertaLS(l, finalLS(l), aux);
    }
}

void imprimirLS(Lista l) {
    printf("\t.data\n");
    PosicionLista p = inicioLS(l);
    while (p != finalLS(l)) {
        Simbolo aux = recuperaLS(l,p);
        switch (aux.tipo) {
            case VARIABLE:
            case CONSTANTE:
                printf("_%s: .word %d\n", aux.nombre, aux.valor); // _ para evitar conflictos con palabras reservadas
                break;
            case CADENA:
                printf("_str%d: .asciiz %s\n", aux.valor, aux.nombre);
                break;
        }
        p = siguienteLS(l, p);
    }
}

void buscarIden(char* nombre, bool variable) {
    PosicionLista p = buscaLS(l, nombre);
    if (p == finalLS(l)) {
        char* errorMsg;
        asprintf(&errorMsg, "identificador %s no declarado", nombre);
        yyerror(errorMsg);
    }
    else if (variable) {
        Simbolo var = recuperaLS(l, p);
        if (var.tipo != VARIABLE) {
            char* errorMsg;
            asprintf(&errorMsg, "identificador %s no es una variable", nombre);
            yyerror(errorMsg);
        }
    }
}

void declarar_str(char* nombre) {
    Simbolo aux = {nombre, CADENA, strCounter++};
    insertaLS(l, finalLS(l), aux);
}

static const char* const kRegNames[10] = {
    "$t0", "$t1", "$t2", "$t3", "$t4", "$t5", "$t6", "$t7", "$t8", "$t9"
};

char* obtenerReg(){
    for (int i = 0; i < 10; i++) {
        if (registros[i] == 0) {
            registros[i] = 1;
            return (char*)kRegNames[i];
        }
    }
    fprintf(stderr, "Error: no hay registros disponibles\n");
    exit(1);
}

void liberaReg(char* reg) {
    int idx = reg[2] - '0';
    assert(idx >= 0 && idx < 10);
    registros[idx] = 0;
}

ExpresionInfo creaExpresion(ListaC codigo, int valor) {
    ExpresionInfo info = malloc(sizeof(struct ExpresionInfoRep));
    info->codigo = codigo; 
    info->valor = valor;
    return info;
}

void liberaExpresion(ExpresionInfo info) {
    liberaLC(info->codigo);
    free(info);
}

ExpresionInfo expression_num(char* arg) {
    ListaC codigo = creaLC();
    Operacion oper = { "li", obtenerReg(), arg, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    guardaResLC(codigo, oper.res);
    ExpresionInfo info = creaExpresion(codigo, atoi(arg));
    return info;
}

ExpresionInfo expression_id(char* arg) {
    ListaC codigo = creaLC();
    Operacion oper = { "lw", obtenerReg(), NULL, NULL };
    asprintf(&oper.arg1, "_%s", arg);
    insertaLC(codigo, finalLC(codigo), oper);
    guardaResLC(codigo, oper.res);
    ExpresionInfo info = creaExpresion(codigo, 0);
    return info;
}

ExpresionInfo expression_binop(ExpresionInfo expr1, ExpresionInfo expr2, char* op) {
    ExpresionInfo info = expr1;
    concatenaLC(info->codigo, expr2->codigo);
    Operacion oper = { op, NULL, recuperaResLC(expr1->codigo), recuperaResLC(expr2->codigo) };
    oper.res = oper.arg1;
    insertaLC(info->codigo, finalLC(info->codigo), oper);

    if (enDeclaraciones) {
        if (!strcmp(op,"add")) info->valor = expr1->valor + expr2->valor;
        else if (!strcmp(op,"sub")) info->valor = expr1->valor - expr2->valor;
        else if (!strcmp(op,"mul")) info->valor = expr1->valor * expr2->valor;
        else if (!strcmp(op,"div")) {
            if (expr2->valor == 0) {
                yyerror("división por cero en evaluación de constante");
                info->valor = 0;
            } else {
                info->valor = expr1->valor / expr2->valor;
            }
        }
        else fprintf(stderr, "Error: SEGMENTATION FAULT INCOMING\n");
    } 

    liberaExpresion(expr2);
    liberaReg(oper.arg2);
    
    return info;
}

ExpresionInfo expression_ternop(ExpresionInfo expr1, ExpresionInfo expr2, ExpresionInfo expr3) {
    /*  
        codigo de expr1
        beqz resultado de expr1, etiqueta1
        codigo de expr2
        copiar resultado de expr2 a resultado de expr1
        b etiqueta2
        etiqueta1
        codigo de expr3
        copiar resultado de expr3 a resultado de expr1
        etiqueta2 
    */
    ExpresionInfo info = expr1;
    char* etiqueta1 = siguienteEtiqueta();
    char* etiqueta2 = siguienteEtiqueta();
    char* res = recuperaResLC(expr1->codigo);
    Operacion oper = { "beqz", res, etiqueta1, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    concatenaLC(info->codigo, expr2->codigo);
    oper = (Operacion) { "move", res, recuperaResLC(expr2->codigo), NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaReg(oper.arg1);
    oper = (Operacion) { "b", etiqueta2, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "etiq", etiqueta1, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    concatenaLC(info->codigo, expr3->codigo);
    oper = (Operacion) { "move", res, recuperaResLC(expr3->codigo), NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaReg(oper.arg1);
    oper = (Operacion) { "etiq", etiqueta2, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaExpresion(expr2);
    liberaExpresion(expr3);
    return info;
}

ExpresionInfo expression_neg(ExpresionInfo expr) {
    ExpresionInfo info = expr;
    Operacion oper = { "neg", NULL, recuperaResLC(expr->codigo), NULL };
    oper.res = oper.arg1;
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    guardaResLC(info->codigo, oper.res); 
    if (enDeclaraciones) info->valor = -expr->valor;
    return info;
}

ExpresionInfo expression_logical_op(ExpresionInfo expr1, ExpresionInfo expr2, char* op) {
    /*  
        codigo de expr1
        codigo de expr2
        op resultado final, resultado de expr1, resultado de expr2
    */
    ExpresionInfo info = expr1;
    concatenaLC(info->codigo, expr2->codigo);
    char* res1 = recuperaResLC(expr1->codigo);
    char* res2 = recuperaResLC(expr2->codigo);
    Operacion oper = { op, res1, res1, res2 };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    guardaResLC(info->codigo, res1); 
    if (enDeclaraciones) {
        if (!strcmp(op,"slt")) info->valor = expr1->valor < expr2->valor;
        else if (!strcmp(op,"sle")) info->valor = expr1->valor <= expr2->valor;
        else if (!strcmp(op,"sgt")) info->valor = expr1->valor > expr2->valor;
        else if (!strcmp(op,"sge")) info->valor = expr1->valor >= expr2->valor;
        else if (!strcmp(op,"seq")) info->valor = expr1->valor == expr2->valor;
        else if (!strcmp(op,"sne")) info->valor = expr1->valor != expr2->valor;
    }
    liberaExpresion(expr2);
    liberaReg(res2);
    return info;
}

ExpresionInfo expression_logical_neg(ExpresionInfo expr) {
    /* 
        codigo de expr
        beqz res, etiqueta1
        li res, 0
        b etiqueta2
        etiqueta 1
        li res, 1
        etiqueta2
    */
    ExpresionInfo info = expr;
    char* etiqueta1 = siguienteEtiqueta();
    char* etiqueta2 = siguienteEtiqueta();
    char* res = recuperaResLC(expr->codigo);
    Operacion oper = { "beqz", res, etiqueta1, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "li", res, "0", NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "b", etiqueta2, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "etiq", etiqueta1, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "li", res, "1", NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "etiq", etiqueta2, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    return info;
}

ExpresionInfo statement_asig(char* id, ExpresionInfo expr) {
    ExpresionInfo info = expr;
    char* _id = NULL;
    asprintf(&_id, "_%s", id);
    Operacion oper = { "sw", recuperaResLC(expr->codigo), _id, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaReg(oper.res);
    return info;
}

ExpresionInfo statement_if(ExpresionInfo cond, ExpresionInfo expr) {
    /*  
        codigo de cond
        beqz resultado de cond, etiqueta1
        codigo de expr
        etiqueta1
    */
    ExpresionInfo info  = cond;
    char* etiqueta = siguienteEtiqueta();
    char* res = recuperaResLC(cond->codigo);
    Operacion oper = { "beqz", res, etiqueta, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaReg(oper.res);
    concatenaLC(info->codigo, expr->codigo);
    oper = (Operacion) { "etiq", etiqueta, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaExpresion(expr);
    return info;
}

ExpresionInfo statement_if_else(ExpresionInfo cond, ExpresionInfo expr1, ExpresionInfo expr2) {
    /*  
        codigo de cond
        beqz resultado de cond, etiqueta1
        codigo de expr1
        b etiqueta2
        etiqueta1
        codigo de expr2
        etiqueta2
    */
    ExpresionInfo info = cond;
    char* etiqueta1 = siguienteEtiqueta();
    char* etiqueta2 = siguienteEtiqueta();
    char* res = recuperaResLC(cond->codigo);
    Operacion oper = { "beqz", res, etiqueta1, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaReg(res);
    concatenaLC(info->codigo, expr1->codigo);
    oper = (Operacion) { "b", etiqueta2, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "etiq", etiqueta1, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    concatenaLC(info->codigo, expr2->codigo);
    oper = (Operacion) { "etiq", etiqueta2, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaExpresion(expr1);
    liberaExpresion(expr2);
    return info;
}

ExpresionInfo print_item_str(char* str) {
    ListaC codigo = creaLC();
    Operacion oper = { "li", "$v0", "4", NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    char* _str = NULL;
    asprintf(&_str, "_str%d", recuperaLS(l, buscaLS(l, str)).valor);
    oper = (Operacion) { "la", "$a0", _str, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    oper = (Operacion) { "syscall", NULL, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    return creaExpresion(codigo, 0);
}

ExpresionInfo print_item_expr(ExpresionInfo expr) {
    ExpresionInfo info = expr;
    char* res = recuperaResLC(expr->codigo);
    Operacion oper = { "li", "$v0", "1", NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "move", "$a0", res, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    oper = (Operacion) { "syscall", NULL, NULL, NULL };
    insertaLC(info->codigo, finalLC(info->codigo), oper);
    liberaReg(res);
    return info;
}

ExpresionInfo read_id(char* id) {
    /* 
        li $v0, 5
        syscall
        sw $v0, _id
    */
    ListaC codigo = creaLC();
    Operacion oper = { "li", "$v0", "5", NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    oper = (Operacion) { "syscall", NULL, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    char* _id = NULL;
    asprintf(&_id, "_%s", id);
    oper = (Operacion) { "sw", "$v0", _id, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    return creaExpresion(codigo, 0);
}

ExpresionInfo statement_while(ExpresionInfo cond, ExpresionInfo expr){
    /*
        etiqueta1
        codigo de cond
        beqz res de cond, etiqueta2
        codigo de expr
        b etiqueta1
        etiqueta2 
    */
    // Creamos primero el codigo con la etiqueta, y luego concatenaremos con el codigo de la condicion
    ListaC codigo = creaLC();
    char* etiqueta1 = siguienteEtiqueta();
    Operacion oper = { "etiq", etiqueta1, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    concatenaLC(codigo, cond->codigo);
    char* _resCond = recuperaResLC(cond->codigo);
    char* etiqueta2 = siguienteEtiqueta();
    oper = (Operacion) { "beqz", _resCond, etiqueta2, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    concatenaLC(codigo, expr->codigo);
    oper = (Operacion) { "b", etiqueta1, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    oper = (Operacion) { "etiq", etiqueta2, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    liberaReg(_resCond);
    return creaExpresion(codigo, 0);
}

ExpresionInfo statement_do_while(ExpresionInfo cond, ExpresionInfo expr) {
    /* 
        etiqueta1
        codigo de expr
        codigo de cond
        beqz res de cond, etiqueta2
        b etiqueta 1
        etiqueta 2
    */
    ListaC codigo = creaLC();
    char* etiqueta1 = siguienteEtiqueta();
    Operacion oper = { "etiq", etiqueta1, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    concatenaLC(codigo, expr->codigo);
    concatenaLC(codigo, cond->codigo);
    char* _resCond = recuperaResLC(cond->codigo);
    char* etiqueta2 = siguienteEtiqueta();
    oper = (Operacion) { "beqz", _resCond, etiqueta2, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    oper = (Operacion) { "b", etiqueta1, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    oper = (Operacion) { "etiq", etiqueta2, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    liberaReg(_resCond);
    return creaExpresion(codigo, 0);
}

ExpresionInfo statement_for(char* varIter, ExpresionInfo exprMin, ExpresionInfo exprMax, ExpresionInfo expr){
    /*
        codigo de exprMin 
        sw resMin, _varIter // Ya se puede liberar el registro de min
        codigo de exprMax // Vas a tener un registro donde se ha guardado max
    etiqueta1
        lw  $t0, _varIter
        bgt $t0, resMax, etiqueta2 // Liberamos $t0
        codigoExpr
        lw  $t0, _varIter 
        addi $t0, $t0, 1
        sw $t0, _varIter // Liberamos $t0
        b etiqueta1
    etiqueta2
    */
    ListaC codigo = exprMin->codigo;
    char* resMin = recuperaResLC(exprMin->codigo);
    char* resMax = recuperaResLC(exprMax->codigo);
    char* etiqueta1 = siguienteEtiqueta();
    char* etiqueta2 = siguienteEtiqueta();
    char* _varIter;
    asprintf(&_varIter, "_%s", varIter);
    
    Operacion oper = { "sw",  resMin, _varIter, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    liberaReg(resMin);

    concatenaLC(codigo, exprMax->codigo);
    liberaExpresion(exprMax);

    oper = (Operacion) { "etiq", etiqueta1, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);

    char* reg = obtenerReg();
    oper = (Operacion) { "lw", reg, _varIter, NULL };
    insertaLC(codigo, finalLC(codigo), oper);

    oper = (Operacion) { "bgt", reg, resMax, etiqueta2 };
    insertaLC(codigo, finalLC(codigo), oper);
    liberaReg(reg);

    concatenaLC(codigo, expr->codigo);
    liberaExpresion(expr);

    reg = obtenerReg();
    oper = (Operacion) { "lw", reg, _varIter, NULL };
    insertaLC(codigo, finalLC(codigo), oper);

    oper = (Operacion) { "addi", reg, reg, "1" };
    insertaLC(codigo, finalLC(codigo), oper);

    oper = (Operacion) { "sw", reg, _varIter, NULL };
    insertaLC(codigo, finalLC(codigo), oper);
    liberaReg(reg);

    oper = (Operacion) { "b", etiqueta1, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);

    oper = (Operacion) { "etiq", etiqueta2, NULL, NULL };
    insertaLC(codigo, finalLC(codigo), oper);

    liberaReg(resMax);

    return creaExpresion(codigo, 0);
}

    
void imprimirLC(ListaC codigo) {
    printf("\n\t.text\n");
    printf("\t.globl main\n");
    printf("main:\n");
    PosicionListaC p = inicioLC(codigo);
    Operacion oper;
    while (p != finalLC(codigo)) {
        oper = recuperaLC(codigo,p);
        if(!strcmp(oper.op, "etiq"))
            printf("%s:\n",oper.res);
        else {
            printf("\t%s",oper.op);
            if (oper.res) printf(" %s",oper.res);
            if (oper.arg1) printf(",%s",oper.arg1);
            if (oper.arg2) printf(",%s",oper.arg2);
            printf("\n");
        }
        p = siguienteLC(codigo,p);
    }
    printf("\tli $v0, 10\n");
    printf("\tsyscall\n");
}

void imprimirRP(int n){
    char* array[] =  {
        "p->id(){declarations statement_list}",
        "declarations->declarations var tipo var_list",
        "declarations->declarations const tipo var_list",
        "declarations->lambda",
        "tipo->int",
        "var_list->id",
        "var_list->var_list , id",
        "const_list->id = expression",
        "const_list->const_list , id = expression",
        "statement_list->statement_list statement",
        "statement->id = expression;",
        "statement->{statement_list}",
        "statement->if(expression) statement else statement",
        "statement->if(expression) statement",
        "statement->while(expression) statement",
        "statement->print(print_list)",
        "statement->read(read_list)",
        "print_list->print_item",
        "print_list->print_list , print_item",
        "print_item->e",
        "print_item->str",
        "read_list->id",
        "read_list->read_list , id",
        "e->e+e",
        "e->e-e",
        "e->e*e",
        "e->e/e",
        "e->(e?e:e)",
        "e->-e",
        "e->(e)",
        "e->id",
        "e->num",
        "statement->do statement while (expression);", 
        "statement->for (id,expression,expression){statement_list}"
    };
    if (print) printf("%s\n", array[n]);
}

char * siguienteEtiqueta(){
    char* etiqueta = NULL;
    asprintf(&etiqueta, "l%d", etiqCounter++);
    return etiqueta;
}