% Lanza la corrida completa del Sistema V13 (comprueba antes que el disco G: este conectado)
clc; close all;
assert(isfile('G:\tesis-base de datos\INbreast Release 1.0\INbreast.csv'), 'Disco G: no conectado');
assert(isfolder('F:\2021 tesis avances 2\data\manifest-1616439774456'), 'Disco F: (CMMD) no conectado');
SISTEMA_V13_UNIFICADO
