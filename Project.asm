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

filehandle dw 10 dup(?)
opening_error_msg db "Opening error", 10, 13, "exitting...$"
Buffer db 4 dup(?) ; char read from file

; getting file name
f_name db 20 dup(?)

output_filehandle dw 10 dup(?)
output_file_name db "output.txt",0
opening_error_msg_out db "Output open error$" ;;;; remove
; ---COMPRESSION-----
dictLength equ 4000
CompDict dd dictLength dup(?)
dictStart equ 256 ; maybe useless !!!!
dictCurrentLen dw 256
dictCurrentAddr dw ?
input_buffer db 100 dup(?)
temp_file db "iamtest.txt",0
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
;	lea dx, [f_name + 2]
	lea dx, [temp_file]
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
	mov cx, 1
	mov dx, offset Buffer
	int 21h

	ret
endp write_byte
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
	

; --------------COMPRESSION-------------
; fills dict with ascii characters as words all the way to 256
proc FillCompDict
	mov cx, dictStart
	mov bx, offset CompDict
	xor ax, ax
fill:
	mov [bx], ax
	inc ax
	add bx, 4
	loop fill

	mov [dictCurrentAddr], bx
	
	ret
endp FillCompDict

; gets params in ax [high], and dx [low]
; returns 1 if equal and 0 if not equal to double word of bx
proc CompareDouble
	
	; ax == [bx + 2] && dx == [bx]
	cmp [word ptr bx], dx
	je checkNext
	jmp notEqual
checkNext:
	cmp [word ptr bx + 2], ax 
	je equal
	jmp notEqual
equal:
	mov ax, 1
	jmp exitEndCompareDouble
	
notEqual:
	mov ax, 0
	
exitEndCompareDouble:
	ret
endp CompareDouble

; Input: A char to search for
; output: ax = 1 if char found cx = char index
;		  ax = 0 if char not found
proc SearchDict
	push bp
	mov bp, sp
	push dx
	push bx
	Word1 equ [bp + 4]
	Word2 equ [bp + 6]
	
	xor bx, bx
	xor cx, cx
next:
	mov ax, Word1
	mov dx, Word2
	call CompareDouble
	; if found then ax will be equal to 1
	cmp ax, 1
	je found
	; otherwise continue until cx 
	; has reached the end of the dictionary
	inc cx
	add bx, 4
	cmp cx, [word ptr dictCurrentLen]
	jne	next
	; if cx reached final dictionary index
	; set ax to 0, not found and exit
	jmp notFound
	
found:
	mov ax, 1
	jmp exitSearchDict
	
notFound:
	mov ax, 0
	jmp exitSearchDict
	
exitSearchDict:
	pop bx
	pop dx
	pop bp
	ret 4
endp SearchDict

; prints inputted value
proc print
	push bp
	mov bp, sp
	to_print equ [bp + 4]
	push ax
	push dx
	
	mov dl, to_print
	mov ah, 2h
	int 21h
	
	pop dx
	pop ax
	pop bp
	ret 2
endp print


;;;;;; NEED TO CLARIFY THE WAY I OUTPUT
; Get's 2 parameters: start of stream and length of stream
; output: outputs to file 'output.lzw'
proc Compress2
	push bp
	mov bp, sp
	; to save
	push ax ; used as helper
	; params
	stream equ [bp + 4]
	streamLen equ [bp + 6]
	; internal variables
	sub sp, 2
	p equ [bp - 2]
	
	current equ bx
	
	mov cx, streamLen
	mov bx, stream ; bx = start of stream, and p
	mov si, [bx] ; si used as helper for moving into p
	mov p, si
	inc bx ; = c
compression:
	xor ax, ax
	mov al, [bx]
	mov dx, p
	push ax ; to save value
	push dx
	push ax
	call SearchDict
	inc bx ; to move to next value in stream
	cmp ax, 1
	pop ax ; to save value for p + c
	je inDicti
	jmp notInDicti

inDicti:
	push dx
	
	mov dh, dl
	mov dl, al
	mov p, dx
	pop dx
	jmp compression

notInDicti:
	push 0
	push p
	call SearchDict
	push cx ; character in dicti
	call print
	jmp compression

	
	
	pop bp
	ret 4
endp Compress2

; Input: bx
; adds bx to dictionary
proc add_to_dictionary
	mov di, [dictCurrentAddr]
	mov [di], bx
	add [dictCurrentAddr], 4 
	inc [dictCurrentLen]
	
	ret
endp add_to_dictionary
proc compress
	push bp
	mov bp, sp
	call open_file
	call open_output
	sub sp, 4 ; for [p] and [c]
	p equ [bp - 2]
	call read_file
	; p = first char in file
	push bx ; save bx
	xor bx, bx
	mov bl, [Buffer]
	mov p, bx
	pop bx ; get saved bx

	; setting c
	c equ [bp - 4]
compression_loop:
	call read_file
	push bx
	xor bx, bx
	mov bl, [Buffer]
	mov c, bl
	pop bx

	; check length of p
	mov bx, p
	cmp bh, 0
	je one_byte
	; two byte
	push p
	push c
	call SearchDict
;	cmp ax, 1
;	je in_dicti_twobyte
	


one_byte:
	mov bl, c
	mov bh, p
	push bx ; for p = p + c
	push bx
	push 0h
	call SearchDict
	pop bx ; for p = p + c
	cmp ax, 1
	je in_dictionary
	jmp not_in_dictionary

in_dictionary:
	mov p, bx
not_in_dictionary:
	mov [Buffer], bh
	call write_byte ; write p to output
	call add_to_dictionary ; add p + c to dicti


	add sp, 4 ; for [p] and [c]
	pop bp
	ret
endp compress

;-------END-COMPRESSION----------S
; print newline
proc newline
	
	mov dl, 10
	mov ah, 2h
	int 21h
	mov dl, 13
	int 21h

	ret
endp newline

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


start:
	mov ax, @data
	mov ds, ax
; --------------------------
;	call FillCompDict	
;	call input
;	call newline
;	mov bx, offset input_buffer + 1
;	xor ax, ax
;	mov al, [bx] ; length of stream
;	push ax ; push as param
;	inc bx
;	push bx ; stream
;	call Compress
; --------------------------
;push 8
;push offset testStream
;call Compress
call FillCompDict
call compress
exit:
	mov ax, 4c00h
	int 21h
END start


