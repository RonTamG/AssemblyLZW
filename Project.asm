IDEAL
MODEL small
STACK 100h
DATASEG
; --------------------------
dictLength equ 4000
CompDict dd dictLength dup(?)
dictStart equ 256
dictCurrentLen dw 256
input_buffer db 100 dup(?)
testStream db "BABAABAA" ;;;;
; --------------------------
CODESEG
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
	
	ret
endp FillCompDict

; gets params in ax, and dx
; returns 1 if equal and 0 if not equal to double word of bx
proc CompareDouble
	
	; ax == [bx] && dx == [bx + 2]
	cmp [word ptr bx], ax
	je checkNext
	jmp notEqual
checkNext:
	cmp [word ptr bx + 2], dx 
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
	Word1 equ [bp + 4]
	Word2 equ [bp + 6]
	push dx
	push bx
	xor bx, bx
	xor cx, cx
next:
	mov ax, Word1
	mov dx, Word2
	call CompareDouble
	cmp ax, 1
	je found
	inc cx
	add bx, 4
	cmp cx, [word ptr dictCurrentLen]
	jne	next
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

; Requests input fo input_buffer
proc input
	push dx
	push ax
	push bx
	
	mov bx, offset input_buffer
	mov al, 100
	mov [bx], al ; max length of input stream
	
	mov dx, offset input_buffer
	mov ah, 0Ah
	int 21h

	pop bx
	pop ax
	pop dx
	ret
endp input

; Get's 2 parameters: start of stream and length of stream
; output: outputs to file 'output.lzw'
proc Compress
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
	push ax ; to save ax
	mov ax, 0
	mov p, ax
	pop ax
	
	current equ bx
	
	mov cx, streamLen
	mov bx, stream ; bx = start of stream, and c
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
endp Compress
; print newline
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
call FillCompDict
push 9
push offset testStream
call Compress


	
exit:
	mov ax, 4c00h
	int 21h
END start


