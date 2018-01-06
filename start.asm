IDEAL
MODEL small
STACK 100h
DATASEG
; --------------------------
welcome_msg db "Welcome to the Lempel Ziv Welch compression program", 10, 13, "Choose what you want to do:", 10, 13, "$"
options_msg db "	1. Compress", 10, 13, "	2. Uncompress", 10,13, "$"
invalid_input_msg db 10, 13, "Invalid input", 10, 13, "exitting...$"

test1 db 10, 13, "option 1$"
test2 db 10, 13, "option 2$"

filename db "paka.lzw",0 ; made obsolete because of get file name
filehandle dw 10 dup(?)
ErrorMsg db "ERROR", 10, 13, "exitting...$"
Buffer db 30 dup(?)

; getting file name
f_name db 20 dup(?)
; --------------------------
CODESEG

; -------------START-SCREEN----------------
; Output: Prints the welcome message and options
proc print_start_screen
	mov dx, offset welcome_msg
	mov ah,9h
	int 21h ; print welcome
	mov dx, offset options_msg
	int 21h ; print options

	ret
endp print_start_screen
; Output: prints that the input was invalid
proc invalid_input
	mov dx, offset invalid_input_msg
	mov ah, 9h
	int 21h
	
	ret
endp invalid_input

; Input: Requested from user
; Output: which option has been chosen !!!!
proc get_start_option
	mov ah, 1h
	int 21h
	sub al, '0'
	; check if 1(compress) or 2(uncompress)
	cmp al, 1
	je compress_option
	cmp al, 2
	je uncompress_option
	; in case it is neither of them, 
	; output invalid option and exit
	jmp invalid_option

compress_option:
	mov dx, offset test1
	mov ah, 9h
	int 21h
	jmp exit_get_input

uncompress_option:
	mov dx, offset test2
	mov ah, 9h
	int 21h
	jmp exit_get_input
	
invalid_option:
	call invalid_input
	; exit app
	mov ax, 4c00h
	int 21h
	
exit_get_input:
	call newline
	ret
endp get_start_option
; ----------END-START-SCREEN-----------

; -------INPUT-FILE-PROCEDURES-------
; Input: Gets input from user and stores it in f_name
; 		 max length of file: 20 chars
; Sets the file up for opening
proc getFileName
	; make buffer
	mov [f_name], 20
	; get input
	mov dx, offset f_name
	mov ah, 0Ah
	int 21h
	; make the final byte after the file name 0
	mov bx, offset f_name
	inc bx ; number of chars entered
	mov bl, [bx]
	xor bh, bh 
	mov [f_name + bx + 2], 0 ; need byte after file name to be 0
	; for asthetics
	call newline
	ret
endp getFileName
; ------END-INPUT-FILE-PROCEDURES

; -----------FILE-PROCEDURES-----------
; open file.
; add it to filehandle
; by: Barak Gonen
proc open_file
	mov ah, 3Dh	
	xor al, al
;	lea dx, [filename]
	lea dx, [f_name + 2]
	int 21h
	jc openerror
	mov [filehandle], ax
	ret
openerror:
	mov dx, offset ErrorMsg
	mov ah, 9h
	int 21h
	; exit app
	mov ax, 4c00h
	int 21h
	
	ret
endp open_file

; Read one byte of the file
; Output: One byte of the file to
; 		  Buffer
proc read_file
	mov ah, 3Fh
	mov bx, [filehandle]
	mov cx, 1
	mov dx, offset Buffer
	int 21h

	ret
endp read_file

; close the open file
proc close_file
	mov ah, 3Eh
	mov bx, [filehandle]
	int 21h

	ret
endp close_file

; ---!!!!-----
; print the letter in Buffer
proc print_letter
	mov dl, [Buffer]
	mov ah, 2h
	int 21h
	
	ret
endp print_letter
; ----!!!!----- probably won't be used in final product
; -----END-FILE-PROCEDURES--------

proc file_work
	call open_file
	mov cx, 9
poopoo:
	push cx
	call read_file
	call print_letter
	pop cx
	loop poopoo
	; close file after we get to end
	call close_file
	
	ret
endp file_work

proc start_screen
	call print_start_screen
	call get_start_option

	ret
endp start_screen


; Output: prints newline
proc newline
	mov dl, 10
	mov ah, 2h
	int 21h
	mov dl, 13
	int 21h

	ret
endp newline
start:
	mov ax, @data
	mov ds, ax
; --------------------------
	call start_screen
	call getFileName
	call file_work
; --------------------------
	
exit:
	mov ax, 4c00h
	int 21h
END start


