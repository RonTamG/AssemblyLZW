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
opening_error_msg db "Opening error", 10, 13, "exitting...$"
Buffer dw 30 dup(?)

; getting file name
f_name db 20 dup(?)

output_filehandle dw 10 dup(?)
output_file_name db "output.txt",0
opening_error_msg_out db "Output open error$" ;;;; remove
blah db "BA"
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
	jc open_error
	mov [filehandle], ax
	ret
open_error:
	mov dx, offset opening_error_msg
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


proc open_output
	mov ah, 3Dh	
	mov al, 1h
;	lea dx, [filename]
	lea dx, [output_file_name]
	int 21h
	jc opening_error
	mov [output_filehandle], ax
	ret
opening_error:
	mov dx, offset opening_error_msg_out
	mov ah, 9h
	int 21h
	; exit app
	mov ax, 4c00h
	int 21h
	
	ret
endp open_output
proc close_output
	mov ah, 3Eh
	mov bx, [output_filehandle]
	int 21h

	ret
endp close_output
proc write_byte
	mov ah, 40h ; write to file
	mov bx, [output_filehandle]
	mov cx, 2
	mov dx, offset Buffer
	int 21h

	ret
endp write_byte
; -----END-FILE-PROCEDURES--------
	
proc file_work
	call open_file
	call open_output
	mov cx, 9
poopoo:
	push cx
	call read_file
	call write_byte
	pop cx
	loop poopoo
	; close file after we get to end
	call close_file
	call close_output
	
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
	call open_output
	mov [Buffer], "AB"
	call write_byte
	call close_output
; --------------------------

exit:
	mov ax, 4c00h
	int 21h
END start


