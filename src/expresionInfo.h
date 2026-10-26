#ifndef EXPRESION_INFO_H
#define EXPRESION_INFO_H

#include "listaCodigo.h"

typedef struct ExpresionInfoRep {
    ListaC codigo; // Lista de código de ensamblador
    int valor; // Valor de la constante (si es una constante)
} * ExpresionInfo; 

#endif