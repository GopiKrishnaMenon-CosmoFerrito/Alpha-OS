;-------------------------------------------------------------------------------
; COMMON UTILITY MACROS



; string : Used for defining a string in assembly
%macro _string 2
%1 db %2
%endmacro

;---------------------------------
; byte : Used for defining a byte
%macro _byte 2
%1 db %2
%endmacro
;---------------------------------

;---------------------------------
;word :    Used for defining a word
%macro _short 2
%1 dw %2
%endmacro
;---------------------------------

;---------------------------------
;long : Used to define a double word
%macro _long 2
%1 dd %2
%endmacro
;---------------------------------