;//////////////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////

;Name		: Bootloader (Stage 0)
;Summary	: Loads the stage 1 Bootloader into the RAM
;			  

BITS 16 						; Real Mode


jmp 	short bootloader_start  ; Jump to the bootloader_start routine after skipping data ( ! Processing data is really dangerous) 


nop 							; Consumes one cycle ( Old Style)



;/////////////////////////////////////////////////////////////////////
;--------------------------------------------------------------------
;////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////

;Name		: Disk Description Table
;Summary	: Contains Information for the Valid Floppy Disk ( MS-DOS based)
;Caution 	: *** Please do not edit any of the fields without knowing what you are trying to do 
;			  Doing so may result in corruption of floppy image resulting in reformat ( The baby Boot is gone!) ****


OEMLabel			db "ALPHAOS "	; Disk label
BytesPerSector		dw 512			; Bytes per sector
SectorsPerCluster	db 1			; Sectors per cluster
ReservedForBoot		dw 1			; Reserved sectors for boot record
NumberOfFats		db 2			; Number of copies of the FAT
RootDirEntries		dw 224			; Number of entries in root dir
									; (224 * 32 = 7168 = 14 sectors to read)
LogicalSectors		dw 2880			; Number of logical sectors
MediumByte			db 0F0h		    ; Medium descriptor byte
SectorsPerFat		dw 9			; Sectors per FAT
SectorsPerTrack		dw 18			; Sectors per track (36/cylinder)
Sides				dw 2		    ; Number of sides/heads
HiddenSectors		dd 0			; Number of hidden sectors
LargeSectors		dd 0			; Number of LBA sectors
DriveNo				dw 0		    ; Drive No: 0
Signature			db 41		    ; Drive signature: 41 for floppy
VolumeID			dd 00000000h	; Volume ID: any number
VolumeLabel			db "ALPHAOS    "; Volume Label: any 11 chars 9 (Dont mess with the spaces !!)
FileSystem			db "FAT12   "	; File system type: don't change!


	



;/////////////////////////////////////////////////////////////////////
;--------------------------------------------------------------------
;////////////////////////////////////////////////////////////////////

; Note: Initialization of segment registers ( Tiny Memory Model < Not necessarily same> ) is neccessary for working of the code.

bootloader_start:  					; Code Responsible for loading the first phase of OS ( Alpha Interface Manager) into the RAM
	
	mov		ax,07C0H 				; BIOS puts the bootloader here in memory 07C0:0000
	mov		ds,ax					; Load the data segment with where we are
	mov 	ax,ds    				; Segment Registers cannot be directly loaded with a immediate value!!
	mov 	es,ax					; Make the DS=ES=CS 
	add 	ax,288					; Move 512 bytes ahead ( Consist of bootloader)
	cli 							; Clear the Interrupts flag ( Better to disable it <in case hardware interrupts occurr>.)
	mov 	ss,ax					; Load the Stack Segment After the code < Possible  problem here >
	mov 	sp,4096					; Load the Stack  ( 1A48 Thats was theoritically end of 1st Stage bootloader <needs changes>)
	sti 							; Restore the Interrupts
	;-------------------------------------------------------------------------------------------------------
	; Dont care about this section. ( For Older BIOS)
	cmp 	dl,0					; For a few earlier creepy bios
	je 		.ok
	mov 	[bootdev],dl			; Get the new bootdevice number
	mov 	ah,8
	int 	13H
	jc 		floppy_faliure
	and 	cx,3FH
	mov 	[SectorsPerTrack],cx
	movzx 	dx,dh
	add 	dx,1
	mov 	[Sides],dx 	
	;--------------------------------------------------------------------------------------------------------
	; Lets get started !!
	.ok:							; If everything went OK
	call  	reset_floppy  			; Reset the floppy controller ( Seek to Track 0 .)
	jnc		floppy_success  		; Failed to reset  the floppy_controller
	call 	floppy_faliure			; Print out the error message on screen
	jmp 	$						; Halt the screen
	ret  							; Code never reaches here (Instruction is just for completition purposes)

floppy_success:
	
	
	call 	load_dir 				; Load the directory table into the memory
	call 	search_kernel 			; Search for Kernel Address (First Logical Cluster ) in the root directory
	call 	load_fat 				; Load file allocation table into the memory ( Overwritten at where the directory was to save space)
  	call 	read_fat 				; Load the Alpha Interface Manager into the memory for Execution
  	mov 	bx,ds					; A small trick to make the jump literally successful !!
 	shl 	bx,4
 	add 	bx,buffer
 	add 	bx,1200H 			  	; Size of FAT (9*512=4608(1200H))
 	jmp 	bx  				    ; Jumps to 9000 ( Calculation : 7E00(Bootloader Ends here)+1200=9000)
 	
		

; Input : AX contains the cluster number to be accessed
; Input : BX contains the address of buffer
load_data:
	push 	ax						; Save the value of ax and bx register
	push 	bx
	add 	ax,31					; Data starts from logical sector 33 i.e (33+FAT_ENTRY_NUMBER(ax)-2(Reserved))
	call 	calc_disk_param   		; Convert logical sector value in CTS
	mov 	ah,02H					 
	mov 	al,1 					
	pop 	bx 	
	int 	13H	 					; Refer to Ralf-Brown Files for more info on int 13H
	pop 	ax 						; Get back the orignal value of ax ( Logical Sector Value)
	ret

calc_disk_param:
	push 	ax 						; Logical Sector ( Taken as input)
	mov 	bx,36 					; Total sectors in one cylinder
	div 	bl						; Divide to get the track number
	mov 	ch,al 					; Move the track number as a parameter
	pop 	ax						; Get the logical sector once again
	push 	ax						; Restack it for future purpose
	mov 	bx,18					; For Head Purposes ( Code could be optimized !!!!)
	div 	bl						; Get the quotient
	mov 	dl,al					; Copy the quotient for future purposes
	cbw 							; Zero down the ah ( Copy sign bit of al into ah - 0 by default)
	and 	ax,1					; 0 down all the bits except the last one to check for even or odd
	mov 	dh,1					; In case it would be  odd
	cmp 	al,0 					; Check whether even or odd ( Even : Side 0 ; Odd : Side 1)
	jne 	.skip					; Odd case so dont change dh (1)
	mov 	dh,0 					; In case last bit was 0 (even)
	.skip: 	
	mov 	al,dl 					
	mov 	ah,00
    mov     bx,18
	imul 	ax,bx					
	mov 	bx,ax 					
	pop 	ax 						; Get Logical Sector
	sub 	ax,bx
	inc 	ax						; Physical Sectors start with one
	mov 	cl,al	 				; Sector Number				
	mov 	dl,byte [DriveNo]		; Drive Number ( 0 - Floppy )
	ret

floppy_faliure:
	mov 	si,disk_error         	; Store Disk Error Message into si
	call 	print 					; Print the message onto the console
	ret

	
reset_floppy:
	push 	ax						; Save the state of ax register
	push 	dx						; Save the state of  dx register
	mov 	ah,00H 					; Code to reset_drive
	mov 	dl, byte[bootdev] 		; BootDevice Number ( 0 : Floppy , 40: Hardddisk and floppy)
	stc 							; Set the carry flag
	int 	13H						; Reset the floppy_controller
	pop 	dx						; Restore the previous state of DX
	pop 	ax						; Restore the previous state of AX
	ret  	


;/////////////////////////////////////////////////////////////////////
;--------------------------------------------------------------------
;////////////////////////////////////////////////////////////////////


;//////////////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////

;Name		: Bootloader Utility Routines
;Summary	: Provides a set of utility procedures 


print:
	push 	ax				; Save the value of ax register for future use
	.repeat:				; Loop routine to read each character and print on the screen
	 lodsb 					; Load a byte
	 cmp 	al,00H          ; Could be a newline as well ( Change the value to 10)		
	 je 	.done
	 mov 	ah,0EH			;  Subfunction code to print the character in teletype mode
	 int 	10H				;  Video Routine to print
	 jmp 	.repeat		
	 .done:
	 pop 	ax				; Get the value of ax back
	 ret  					



load_fat:
	push 	ax			    ; Save the value of ax for future use
	mov 	ax,1			; Logical Sector 1	
	call 	calc_disk_param ; Calculate the disk parameters
	mov 	ah,02H			; Function code to read sector
	mov 	al,9			; 10 Sectors to be read
	lea   	bx,[buffer]	    ; Overwrite the directory with the FAT to save space
	
	int 	13H				; Read the requested sectors
	pop 	ax				; Get back the value of ax
	ret

; IN : AX contains the logical  cluster number  for the first cluster
read_fat:
	mov 	di,4608 		; Address Where KERNEL will be stored( Pointer to Kernel)
	
	.routine:
	; Load the kernel data from the logical cluster of fat
	lea 	bx,[buffer+di] 	;For loading each sector
	call 	load_data 		; Load the data into the input buffer as specified above
	add 	di,512 			; 1 Sector= 512 bytes
  
  	; For Next Cluster Calculation
  	; Can you improve it?
	mov 	cx,0xFFF0 						;  Value Tests the end of cluster ( Not always true. The papers say something else)
	mov 	bx,ax			
	mov 	dx,ax
	imul 	bx,3
	shr 	bx,1
	cmp 	ax,2
	je 		.done
	mov 	ax,[buffer+bx]
	cmp 	ax,cx
	je 		.done
	mov 	cx,0x0FFF
	je 		.done
	and 	dx,0000000000000001B
	cmp 	dx,0 				; Given Cluster Number is even
	je 		.even_entry			; Clear from the name itself ( Refer to site for more info)
	jmp 	.odd_entry
	
	.even_entry:
		
		and  ax,0000111111111111B ; Get the last three words
		jmp .routine 			  
	.odd_entry:
		shr    ax,4
		jmp  .routine
	.done:
		ret

	
load_dir:
	mov 	ax,19 				; Directory Table starts at Logical Sector 19
	call 	calc_disk_param 	; Convert logical sector to CTS
	mov 	ah,02H				
	mov 	al,10
	lea 	bx,[buffer]			; Address of INPUT Buffer
	int 	13H					; Read the data from disk
	ret


search_kernel:

	mov 	bx,0
	lea 	di,[kernel_filename]	; Load kernel_file name for comparision
	mov 	dx,buffer 				; Address of the RootDirectory

	add 	dx,208					; There are total 208 directories 
	mov 	cx,16 					; Each Record consists of 16 Directory Entries
	.repeat:
 	
 		lea 	di,[kernel_filename] ;  I love this statement more than anything XD
 		inc 	cx
 		lea 	si,[buffer+bx]
 		
 		call 	compare_string		; Compare both the strings to check for equality
		je 		.found				; If found then provide the address of the sector
 		cmp 	cx,dx  				; Check whether we have read all the directories
 		je 		.not_found			; Not found the record ? Jump to not_found routine
 		add 	bx,32				; Traverse to the next record (32 bytes long is one record)
 		add 	cx,16				; 16 Directory Entries for one record
 		jmp 	.repeat				; Loop again 

 	.found:
 		
 		mov  	ax,word [buffer+bx+26] 	; Move the location  of correct record to the ax register 	
 		lea 	si,[kernel_filename] 	; Only for testing purpose to indicate that the kernel will be loaded into the system
 		call 	print					; Print the message to the user
 		jmp 	.done

 	.not_found:
 		lea 	si,[file_not_found]  	; Print the message that KERNEL.BIN was not found
 		call 	print				
 		jmp 	.done  				; Return

 	.done:
 		ret 						; Return  from the function


; Input:
; String 1 : SI 
; String 2 : DI
; CX 	   : Contains the number of bytes to compare
compare_string:
	push 		cx					; Save the state of cx

	mov 		cx,6				; Compare 6 characters ( Comment this line and change the value  of cx in your caller)
	cld 							; Direction from left to  right
	REPE 		cmpsb 				; Compare String
	pop 		cx					; Restore the previous state of cx
	ret


;/////////////////////////////////////////////////////////////////////
;--------------------------------------------------------------------
;////////////////////////////////////////////////////////////////////












;//////////////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////

;Name		: Additional DATA
;Summary	: Required for printing and other purposes


; Now i tried to do something ugly with assembly. Please bear with me !

%include "E:\My Personal OS\Common_Utility.asm"  	   ; Change the path or else forget making it work		
_string 			{kernel_filename},{"KERNEL  BIN",0};kern_filename_len db $-kern_filename; Length of Kernel Filename
_string 			{disk_error},{"Floppy error ! Press any key...",0}
_string 			{file_not_found},{"KERNEL.BIN not found!",0}
_byte 				{bootdev},{0}	    ; Device Number 


;//////////////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////

;Name		: Boot Signature
;Summary	: Detection code for BIOS to load this as a bootloader


times 510-($-$$) db 0 	; Pad the remaining bytes as 0
dw 0xAA55 				; Boot Signature for Detection (The MAGIC NUMBER)

buffer: 				; Address where the DIR AND FAT get loaded 

; Here the real OS begins . Dont write anything here (After this everything is lost)

;/////////////////////////////////////////////////////////////////////
;--------------------------------------------------------------------
;////////////////////////////////////////////////////////////////////
