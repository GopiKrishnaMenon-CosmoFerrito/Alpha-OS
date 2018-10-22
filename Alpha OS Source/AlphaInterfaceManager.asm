
;//////////////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////

;Name		: AIM ( Alpha Interface Manager)
;Summary	: AIM provides a small interface that gives user the choice to select between CUI or GUI mode.



BITS 16 		; Real Mode

;////////////////////////////////////////////////////////////////////

bootloader_start:

; Initializing the data segment register for proper addressing
	mov 	ax,0x900 				; Replace the data segment address with  new one for Alpha Interface manager
	mov 	ds,ax
	
	
	call 	clear_screen 			; Clear the screen before printing
	call 	set_cursor_size 		; Set the size of the cursor  
	call 	get_cursor 				; Get the current cursor location
	
	add 	dh,2					; Row 
	add 	dl,30 					; Set the name of the operating system to the center of the screen
	call 	set_cursor				; Set the cursor to the requested location
	
	lea 	si,[WELCOME_SCREEN]		; Set the name ALPHA OS
	call 	print_string  			; Print the name to the screen
	call 	get_cursor 				; Get the cursor location for modification
	add 	dh,18					; 15th Row
	mov 	dl,1					; 1st column ( Small  Padding)
	call 	set_cursor   			; Set the location of the cursor
	lea 	si,[INSTRUCTIONS]		; Instructions to be followed at the bottom of the screen
	call 	print_string			; Print the instructions onto the screen
	call    LIST_CONTROL 			; Start list control 
	


LIST_CONTROL:
	
	mov 	bl,	[BACKGROUND_COLOR]					; Black background with white foreground
	mov 	cx,0
	call 	get_cursor   			; Get the current cursor position
	mov 	ax,dx  					; Save a copy of it for editing purposes

	.repeat:
		mov 	dx,0
		mov 	cl,0 					; Set the data index to zero
		lea 	si,[PROMPT]  			; Address of String 1
		call 	print_special			; Print it 
		inc 	cl 						; Increment the index of data
		lea 	si,[PROMPTA]			; Print it
		call 	print_special
		call 	get_character 			; Get the input from the user
		cmp 	al,[UP_ARROW]			
		je 		.up_arrow 					
		cmp 	al,[DOWN_ARROW]
		je 		.down_arrow 			
		cmp 	al,[ENTER_KEY]
		je 		.enter_key
		jmp 	.repeat	     			; Reaches  here if any other input is given

	.up_arrow:
		cmp  	ch,0 					; For rotating 
		je 		.up_rotate
		dec 	ch  					; Reduce the selected index
		jmp 	.repeat

	.up_rotate:
		mov 	ch,[N]  				; Set selected index to  the last index
		jmp 	.repeat

	.down_arrow:
		cmp 	ch,[N]
		je 		.down_rotate
		inc 	ch
		jmp 	.repeat
	.down_rotate:
		mov 	ch,0
		jmp 	.repeat
	.enter_key:
		; Code to load the required mode 
		
	
	ret 									; Useless ! Will never reach here


print_special:
	pusha
	add 	dh,cl 							; Add
	add  	dh,[INDENT]						; Add the indent Accordingly
	call  	set_cursor
	cmp 	cl,ch 							; Compare whether selected index and data index are same
	je 		.print_colored
	not 	bl
	je  	.prn 

	.print_colored:
		jmp .prn


	.prn:
		._rep:
		lodsb
		cmp 	al,0 								; Load the string from SI
		je 		.done
		call 	print_character
		jmp  	._rep
		.done:
		mov 	cx,80
		call 	get_cursor
		sub 	cl,dl
		mov  	al,0
		.print_0:
		 call 	print_character
		 loop 	.print_0
	popa
	ret

;Clear Screen:
; Summary:  Clears the screen by setting the standard colour mode
clear_screen:
	mov 	ax,0003H		; ah=00 (Video Mode)  al=03 (Standard Colour)
	int 	10H				; BIOS video interrupt
	ret


;Get_Cursor:
; Summary: Returns the cursor position
; Requirements: Nothing
; Output : Returns the cursor position in dx register
get_cursor:
	push 	ax
	push  	cx
	mov 	ah,03H			; Function code to get the current cursor position
	mov 	bh,00			; Current Page Number
	int 	10H				; BIOS video routine
	pop 	cx
	pop 	ax
	ret

set_cursor:					;  Requires row and column data in the dx  register
	push 	ax				; Save the previous data
	push 	bx				; Save the previous data
	mov 	ah,02H			; Request cursor positioning (Subfunction code)
	mov 	bh,00H			; Page Number
	int 	10H				; BIOS video interrupt
	pop 	bx				; Restore the previous data
	pop 	ax				; Restore the previous data
	ret



;////////////////////////////////////////////////////////////////////////////////////
;Print String:
; Summary: Prints a series of bytes onto the screen in teletype  mode.
; Requirements:
; A string loaded to SI for reading it byte by byte
;////////////////////////////////////////////////////////////////////////////////////
print_string:

	 mov 	ah,0EH		    ; Function code to set teletype Mode
    .repeat:
     lodsb     				; Get a character from the si register
     cmp 	al,0
     je 	.done		    ; If the value is 0 just return 
     cmp 	al,'$'
     je  	.newline
     int 	10H
     jmp 	.repeat

    .newline:
     call 	get_cursor
     ;inc 	dh
     mov 	dl,1
     mov 	al,10
     call 	set_cursor
     int 	10H
     jmp 	.repeat

    .done:
     ret     			    ; Return from the function to the context


;Print Character:
; Summary: Prints a character without advancing the cursor.
; Requirements:
; al : Contains the character to be printed.
; bh : Contains the Page Number
; dh : Contains the Row Number
; dl : Contains the Column Number
; bl : Contains the foreground and the background colour.
print_character:
	 pusha
	 mov 	ah,09H			; Function code to print without advancing the cursor
	 mov 	bh,0			; Page  Number 0
	 mov 	cx,01
	 int 	10H				; BIOS video routine to print the character
	 call 	get_cursor
	 inc 	dl
	 call 	set_cursor
	 popa
	 ret					; Return from the procedure

get_character:
	mov 	ah,10H
	int 	16H
	ret

set_cursor_size:
	pusha
	mov 	ah,01H
	mov 	cx,20H
	int 	10H
	popa
	ret

;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------
;///////////////////////////////////////////////////////////////////////////////////

PROMPT 				db 		"Graphical UserInterface",0
PROMPTA 			db 		"Command Line Interface",0
BACKGROUND_COLOR    db 		11110000B
UP_ARROW 			db	 	'w'
DOWN_ARROW 			db	 	's'
ENTER_KEY 			db 		'a'
INDENT 				db  	 5
N 					db 		 2
WELCOME_SCREEN 		db 		"WELCOME TO ALPHA OS",0
INSTRUCTIONS 		db 		"Interface Manager for Alpha OS is a Utlity that allows you to select working $mode in Alpha OS.For diagnosis use CLI otherwise use GUI utility",0
