IDEAL
MODEL small
STACK 100h
DATASEG
; --------------------------

; start_screen
welcome_msg db "Welcome to the Lempel-Ziv-Welch compression program!", 10, 13, "Choose what you want to do:", 10, 13, "$"
options_msg db "	1. Compress", 10, 13, "	2. Uncompress", 10,13, "$"
InstructionsMsg db 8, "First type in the input file, and then the output file", 10, 13, "$"
invalid_input_msg db 10, 13, "Invalid input", 10, 13, "exitting...$"
OpeningFileMsg db "Opening file...", 10, 13, 10, 13,"$"
GettingFileMsg db "Input file-name", 10, 13, "-->$"
CloseFileMsg db "Closing file...", 10, 13, "$"
CompressingMsg db "Compressing...", 10, 13, "$"
DecompressingMsg db "Decompressing...", 10, 13, "$"
DoneMsg db "Done!", 10, 13, 10, 13, "$"
FileNotFoundErrorMsg db "File Not Found", 10, 13, "$"
TooManyFilesOpenErrorMsg db "Too many file open", 10, 13, "$"
NoPremissonErrorMsg db "You don't have premission to open this file", 10, 13, "$"

inputFilehandle dw 10 dup(?)
outputFilehandle dw 10 dup(?)
opening_error_msg db "Opening error", 10, 13, "exitting...$"
; File name
f_name db 20 dup(?)

; I/O buffer
Buffer db 4 dup(0) ; char read from file

; ---Dictionary----
CODE_LEN = 12 ; length of the code words in bits
FIRST_CODE = 256
DictSize = 3840 ; the maximum number of entries required - single character codes
MaxCodeWord dd 4096

compDict db DictSize dup(4 dup (-1), 1 dup (2), 4 dup(3)) ; int, char, int: codeValue, Suffix, Prefix(is a code)
codeWord dd 0
suffixChar db 0
prefixCode dd 0

CurrentDictSize dw 0

; ---BitFileManagement---

bitbuffer db 0
bitcount db 0

; ---COMPRESSION-----
; input file, output file
code dd 0
nextCode dd FIRST_CODE
character db 0
currentIndex dw offset compDict

TempToWrite dd 0

; ---Decompression---
; input file, output file
; These are used both in the compression process and in the decompression

; nextCode dd FIRST_CODE used also in the decompression
; character db 0
; code dd 0
lastCode dd 0

; Reading encoded file
TempToRead dd 0
GetCharReturnValue db 0
; Decoding codes
OutputChar db 0
DecodeIndex dd 0
TempCode dd 0

CODESEG
; -------HELPERS---------

; Input: Offset of a double word type variable
; Output: Increases it's value by 1
proc IncDouble
	push bp
	mov bp, sp
	DoubleOffset equ [bp + 4]
	mov bx, DoubleOffset
	inc [word ptr bx]
	jz ZeroFlagOn ; if the zero flag is on that means the value "overflowed"
	jmp EndIncDouble

ZeroFlagOn:
	inc [word ptr bx + 2]

EndIncDouble:
	pop bp
	ret 2
endp IncDouble


; Input: Two double word type variable's values
; Output: ax = 1 if first double is less than the second double, else ax = 0
proc CompareDoubleLessThan
	push bp
	mov bp, sp
	FirstDouble1 equ [bp + 10]
	FirstDouble2 equ [bp + 8]
	SecondDouble1 equ [bp + 6]
	SecondDouble2 equ [bp + 4]

	mov ax, FirstDouble1 ; first compare the high part
	cmp ax, SecondDouble1
	jb DoubleIsLessThan
	ja DoubleIsNotLessThan
	; if they are equal we need to check their lower part(the smaller one)
	mov ax, FirstDouble2
	cmp ax, SecondDouble2
	jb DoubleIsLessThan
	jmp DoubleIsNotLessThan

DoubleIsLessThan:
	mov ax, 1
	jmp EndCompareDoubleLessThan

DoubleIsNotLessThan:
	mov ax, 0
	jmp EndCompareDoubleLessThan

EndCompareDoubleLessThan:
	pop bp
	ret 8
endp CompareDoubleLessThan

; Input: An offset to a double word type variable, and a value
; Summary: Moves the inputted value to the offset as a double word variable.
proc MoveDoubleWord
	push bp
	mov bp, sp
	DoubleOffset equ [bp + 8]
	Double1 equ [bp + 6]
	Double2 equ [bp + 4]

	mov bx, DoubleOffset
	mov ax, Double2
	mov [word ptr bx], ax
	mov ax, Double1
	mov [word ptr bx + 2], ax; according to little endian

	pop bp
	ret 6
endp MoveDoubleWord


; Input: 2 Double words, or 4 words
; Output: If the 2 double words are equal, ax = 1. Else, ax = 0
proc CompareDoubleEqual
	push bp
	mov bp, sp
	FirstDouble1 equ [bp + 10]
	FirstDouble2 equ [bp + 8]
	SecondDouble1 equ [bp + 6]
	SecondDouble2 equ [bp + 4]

	mov ax, FirstDouble1
	cmp ax, SecondDouble1
	je checkNextValues
	jmp ValuesAreNotEqual
checkNextValues:
	mov ax, FirstDouble2
	cmp ax, SecondDouble2
	je ValuesAreEqual
	jmp ValuesAreNotEqual
ValuesAreEqual:
	mov ax, 1
	jmp EndCompareDoubleEqual	
ValuesAreNotEqual:
	mov ax, 0
	
EndCompareDoubleEqual:
	pop bp
	ret 8
endp CompareDoubleEqual


; Input: 2 double word values.
; Output: ax = 1, if the value of the first is above or equal to the value of the second
; 		  else, ax = 0 
proc CompareDoubleEqualAbove
	push bp
	mov bp, sp
	FirstDouble1 equ [bp + 10]
	FirstDouble2 equ [bp + 8]
	SecondDouble1 equ [bp + 6]
	SecondDouble2 equ [bp + 4]

	mov ax, FirstDouble1
	cmp ax, SecondDouble1
	ja ValueIsEqualOrAbove
	jb ValueIsNotEqualOrAbove
	; If the high words are equal we need to check the low words
	mov ax, FirstDouble2
	cmp ax, SecondDouble2
	jb ValueIsNotEqualOrAbove
	; if the value is greater or equal it will continue in the code and output the correct output

ValueIsEqualOrAbove:
	mov ax, 1
	jmp EndCompareDoubleEqualAbove

ValueIsNotEqualOrAbove:
	mov ax, 0
	jmp EndCompareDoubleEqualAbove

EndCompareDoubleEqualAbove:
	pop bp
	ret 8
endp CompareDoubleEqualAbove


; Input: The offset of a double word type variable
;		 The value of the double word we want to OR with the variable at the offset with
; Summary: Preforms a bitwise OR on the variable
proc BitWiseOrDouble
	push bp
	mov bp, sp
	DoubleOffset equ [bp + 8]
	FirstWordOr equ [bp + 6]
	SecondWordOr equ [bp + 4]
	mov bx, DoubleOffset

	mov ax, SecondWordOr
	or [word ptr bx], ax
	mov ax, FirstWordOr
	or [word ptr bx + 2], ax

	pop bp  
	ret 6
endp BitWiseOrDouble


; Input: The offset of a double word type variable
;		 The value of the double word we want to AND with the variable at the offset with
; Summary: Preforms a bitwise AND on the variable
proc BitWiseAndDouble
	push bp
	mov bp, sp
	DoubleOffset equ [bp + 8]
	FirstWordAnd equ [bp + 6]
	SecondWordAnd equ [bp + 4]
	mov bx, DoubleOffset

	mov ax, SecondWordAnd
	and [word ptr bx], ax
	mov ax, FirstWordAnd
	and [word ptr bx + 2], ax

	pop bp  
	ret 6
endp BitWiseAndDouble


; Input: The offset of double word type variable, and the amount of bits to shift it by
; Summary: Shifts the given amount of bits in the given variable
proc RightShiftDouble
	push bp
	mov bp, sp
	DoubleOffset equ [bp + 6]
	shiftAmount equ [bp + 4]

	mov cx, shiftAmount
	mov bx, DoubleOffset
RightShiftLoop:
	shr [word ptr bx + 2], 1 
	rcr [word ptr bx], 1 ; input carry flag value that we got from last shift, this way the shift "continues" to the rest of the bits
	loop RightShiftLoop ; do so until we have shifted the given amount of times

	pop bp
	ret 4
endp RightShiftDouble

; Input: The offset of double word type variable, and the amount of bits to shift it by
; Summary: Shifts the given amount of bits in the given variable
proc LeftShiftDouble
	push bp
	mov bp, sp
	DoubleOffset equ [bp + 6]
	shiftAmount equ [bp + 4]

	mov cx, shiftAmount
	mov bx, DoubleOffset
LeftShiftLoop:
	shl [word ptr bx], 1 
	rcl [word ptr bx + 2], 1 ; input carry flag value that we got from last shift, this way the shift "continues" to the rest of the bits
	loop LeftShiftLoop ; do so until we have shifted the given amount of times

	pop bp
	ret 4
endp LeftShiftDouble


; Input: The offset of the variable we want to return to (double word),
;		 Two double word type variable values.
; Output: The quotient of the values into the return offset
proc SubDouble
	push bp
	mov bp, sp
	ToReturnToOffset equ [bp + 12]
	FirstDouble1 equ [bp + 10]
	FirstDouble2 equ [bp + 8]
	SecondDouble1 equ [bp + 6]
	SecondDouble2 equ [bp + 4]
	mov bx, ToReturnToOffset

	; low word
	mov ax, FirstDouble2
	sub ax, SecondDouble2
	mov [word ptr bx], ax

	; high word
	mov ax, FirstDouble1
	sbb ax, SecondDouble1 ; sbb adds the value of the carry flag to the calculation
	mov [word ptr bx + 2], ax

	pop bp
	ret	10
endp SubDouble

; Input: The offset of the variable we want to return to (double word),
;		 Two double word type variable values.
; Output: The sum of the values into the return offset
proc AddDouble
	push bp
	mov bp, sp
	ToReturnToOffset equ [bp + 12]
	FirstDouble1 equ [bp + 10]
	FirstDouble2 equ [bp + 8]
	SecondDouble1 equ [bp + 6]
	SecondDouble2 equ [bp + 4]
	mov bx, ToReturnToOffset

	; low word
	mov ax, FirstDouble2
	add ax, SecondDouble2
	mov [word ptr bx], ax
	; add carry flag to calculation
	jc AddCarry
	jmp NoCarry

AddCarry:
	mov ax, 1
	jmp AddHighWord

NoCarry:
	mov ax, 0

AddHighWord:
	; high word
	add ax, FirstDouble1
	add ax, SecondDouble1 ; sbb adds the value of the carry flag to the calculation
	mov [word ptr bx + 2], ax

	pop bp
	ret	10
endp AddDouble

; Input: The offset we want to return to
;		 A double word type variable
;		 The value we want to multiply by
; Output: The two values multiplied and outputted to the return offset
proc MulDoubleByByte
	push bp
	mov bp, sp
	ToReturnToOffset equ [bp + 10]
	FirstDouble1 equ [bp + 8]
	FirstDouble2 equ [bp + 6]
	Value equ [bp + 4]
	mov bx, ToReturnToOffset
	push ToReturnToOffset
	push 0
	push 0
	call MoveDoubleWord ; make sure no previous values interfere with the output

	; calculate value for high byte
	mov ax, FirstDouble1
	mov dx, Value
	mul dx
	mov [bx], ax

	; shift by word's length
	push ToReturnToOffset
	push 16
	call LeftShiftDouble

	; calculate the second word 
	mov ax, FirstDouble2
	mov dx, Value
	mul dx

	; or the result in to output
	push ToReturnToOffset
	push dx
	push ax
	call BitWiseOrDouble

	pop bp
	ret	8
endp MulDoubleByByte

; -----END HELPERS-------


; -------------START-SCREEN----------------
; Output: Prints the InstructionsMsg variable to the screen
proc printInstructions
	mov dx, offset InstructionsMsg
	mov ah, 9h
	int 21h

	ret
endp printInstructions

; Output: Prints the welcome message and options
proc PrintStartScreen
	mov dx, offset welcome_msg
	mov ah,9h
	int 21h ; print welcome
	mov dx, offset options_msg
	int 21h ; print options

	ret
endp PrintStartScreen

; Summary: Requests initial option from user and acts accordigly
;		   (Compress, Uncompress, Invalid)
proc Run
	mov ah, 1h
	int 21h
	sub al, '0'
	; check if 1(compress) or 2(uncompress)
	cmp al, 1
	je compress_option
	cmp al, 2
	je uncompress_option
	; in case it's neither of them, 
	; output invalid option and exit
	jmp invalid_option

compress_option:
	call printInstructions
	call ProjectCompress
	jmp exit_get_input

uncompress_option:
	call printInstructions
	call ProjectDecompress
	jmp exit_get_input
	
invalid_option:
	call InvalidInput
	; exit app
	mov ax, 4c00h
	int 21h
	
exit_get_input:
	ret
endp Run

; Output: prints that the input was invalid
proc InvalidInput
	mov dx, offset invalid_input_msg
	mov ah, 9h
	int 21h
	
	ret
endp InvalidInput

; Output: print newline
proc newline
	
	mov dl, 10
	mov ah, 2h
	int 21h
	mov dl, 13
	int 21h

	ret
endp newline


; -------INPUT-FILE-PROCEDURES-------
; Input: Gets input from user and stores it in f_name
; Summary: Gets the name of the file to open
proc getFileName
	; print getting file message
	mov dx, offset GettingFileMsg
	mov ah, 9h
	int 21h
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

; Summary: Gets the names of the I/O files using GetFileName, and opens the files.
proc GetInputOutput
	call getFileName
	push offset inputFilehandle
	push 0
	call OpenFile

	call getFileName
	push offset outputFilehandle
	push 1
	call OpenFile

	ret
endp GetInputOutput

; Summary: Calls both procedures to close input and output files
proc CloseInputOutput
	push offset inputFilehandle
	call CloseFile
	push offset outputFilehandle
	call CloseFile

	ret
endp CloseInputOutput
; ------END-INPUT-FILE-PROCEDURES

; ----- Project-Operations -------

; Summary: Calls I/O procedures and compresses
proc ProjectCompress
	call GetInputOutput

	mov dx, offset CompressingMsg
	mov ah, 9h
	int 21h
	call Compress
	mov dx, offset DoneMsg
	mov ah, 9h
	int 21h

	call CloseInputOutput

	ret
endp ProjectCompress

; Summary: Calls I/O procedures and decompresses
proc ProjectDecompress
	call GetInputOutput

	mov dx, offset DecompressingMsg
	mov ah, 9h
	int 21h
	call Decompress
	mov dx, offset DoneMsg
	mov ah, 9h
	int 21h

	call CloseInputOutput

	ret
endp ProjectDecompress

; ----- End-Project-Operations -------

; ----------END-START-SCREEN-----------


; -----------FILE-PROCEDURES-----------

; Input: offset to put filehandle in and opening mode (Read = 0, Write = 1, Both = 2)
; Output: Opens the file with file name from f_name to given filehandle
proc OpenFile
	push bp
	mov bp, sp
	filehandleOffset equ [bp + 6]
	OpeningMode equ [bp + 4]

	; print opening file message
	mov dx, offset OpeningFileMsg
	mov ah, 9h
	int 21h

	mov ah, 3Dh	
	mov al, OpeningMode
	lea dx, [f_name + 2]
	int 21h
	jc open_error
	mov bx, filehandleOffset
	mov [bx], ax
	jmp EndOpenInputFile

open_error:
	; Print message
	call OpenError
	; Exit app
	mov ax, 4c00h
	int 21h

EndOpenInputFile:
	pop bp	
	ret 4
endp OpenFile


; Summary: Checks the value of the ax and prints
; 		   The correct error message
proc OpenError
	cmp ax, 2
	je FileNotFoundError
	cmp ax, 5
	je TooManyFilesOpenError
	; No premission to open file
	mov dx, offset NoPremissonErrorMsg
	mov ah, 9h
	int 21h
	jmp EndOpenError

FileNotFoundError:
	mov dx, offset FileNotFoundErrorMsg
	mov ah, 9h
	int 21h
	jmp EndOpenError

TooManyFilesOpenError:
	mov dx, offset TooManyFilesOpenErrorMsg
	mov ah, 9h
	int 21h

EndOpenError:
	ret
endp OpenError

; Summary: Read one byte of the file
; Output: One byte of the file to BUFFER
;         AX holds num of bytes read
proc ReadByte
	push bx
	push cx
	push dx

	mov ah, 3Fh
	mov bx, [inputFilehandle]
	mov cx, 1
	mov dx, offset Buffer
	int 21h

	pop dx
	pop cx
	pop bx
	ret
endp ReadByte

; Input: Filehandle of the file to close
; Output: Closes the file and prints closing message
proc CloseFile
	push bp
	mov bp, sp
	filehandleOffset equ [bp + 4]

	; print closing file message
	mov dx, offset CloseFileMsg
	mov ah, 9h
	int 21h

    push bx
	push ax
	mov bx, filehandleOffset

	mov ah, 3Eh
	mov bx, [bx]
	int 21h

	pop ax
	pop bx
	pop bp
	ret 2
endp CloseFile


; Input: Byte to write to an open output file in [OutputFilehandle]
; Output: Writes given byte to the output file
proc WriteByte
	push bp
	mov bp, sp
	ToWrite equ [bp + 4]
	push bx
	push cx
	push ax
	push dx

	mov al, ToWrite
	mov [Buffer], al

	mov ah, 40h ; write to file
	mov bx, [outputFilehandle]
	mov cx, 1
	mov dx, offset Buffer
	int 21h

	pop dx
	pop ax
	pop cx
	pop bx
	pop bp
	ret 2
endp WriteByte

; Summary: Writes out any unwritten bits in the buffer
proc ResetBitbuffer
	cmp [bitcount], 0
	je EndResetBuffer
	mov cl, 8
	sub cl, [bitcount]
	shl [bitbuffer], cl

	mov al, [bitbuffer]
	xor ah, ah
	push ax
	call WriteByte

EndResetBuffer:
	ret
endp ResetBitbuffer

; -----END-FILE-PROCEDURES--------
	

; ------DICTIONARY CONTROL--------------

; Input: Recieves a dictionary index as a paramter
; Output: Sets the value of codeWord (variable) to the value of the code word at the given index
; according to little endian
proc GetCodeWord
	push bp
	mov bp, sp
	push ax
	push bx
	index equ [bp + 4]

	mov bx, index ; in order to move to index's position in memory
	mov ax, [bx] ; set to first 2 bytes from index
	mov [word ptr codeWord], ax ; set first 2 bytes of code word to first 2 bytes from index (the code word at index)
	add bx, 2 ; to get the next 2 bytes
	mov ax, [bx] 
	mov [word ptr codeWord + 2], ax; set next 2 bytes of codeWord to next 2 bytes of code word at index

	pop bx
	pop ax
	pop bp
	ret 2
endp GetCodeWord

; Input: Gets the index in the dictionary to set code word of, and the value to set the code word to
; Output: Sets the code word at the given index to the given value
proc SetCodeWord
	push bp
	mov bp, sp
	push ax
	push bx
	index equ [bp + 8]
	first_bytes equ [bp + 4] ; the first 2 bytes of the new code word
	next_bytes equ [bp + 6] ; the next 2 bytes of the new code word
	
	mov bx, index ; in order to access index position in memory
	; set first 2 bytes of code word
	mov ax, first_bytes
	mov [bx], ax
	; set next 2 bytes of code word
	add bx, 2
	mov ax, next_bytes
	mov [bx], ax

	pop bx
	pop ax
	pop bp
	ret 6
endp SetCodeWord


; Input: Index in the dictionary
; Output: Sets the SuffixChar (variable) to the suffix char of the given dictionary index 
proc GetSuffixChar
	push bp
	mov bp, sp
	index equ [bp + 4]
	
	mov bx, index
	add bx, 4 ; to set bx to the suffix char of the current index
	; Set the value of the suffix character
	mov al, [bx]
	mov [suffixChar], al

	pop bp
	ret 2
endp GetSuffixChar


; Input: Dictionary index, Value to set suffix char to
; Output: Sets suffix char at the given index to the inputted value
proc SetSuffixChar
	push bp
	mov bp, sp
	index equ [bp + 6]
	value equ [bp + 4]
	
	mov bx, index
	add bx, 4
	mov ax, value
	mov [bx], al

	pop bp
	ret 4
endp SetSuffixChar

; Input: dictionary index
; Output: Sets the value of prefixCode (variable) to the value of the prefix at the given index
; according to little endian
proc GetPrefixCode
	push bp
	mov bp, sp
	push ax
	push bx
	index equ [bp + 4]

	mov bx, index
	add bx, 5 ; set bx to the position of the prefixCode at the index
	mov ax, [bx] ; set to first 2 bytes from index
	mov [word ptr prefixCode], ax ; set first 2 bytes of prefix to first 2 bytes from index (the prefix at index)
	add bx, 2 ; to get the next 2 bytes
	mov ax, [bx] 
	mov [word ptr prefixCode + 2], ax; set next 2 bytes of prefix to next 2 bytes of prefix at index

	pop bx
	pop ax
	pop bp
	ret 2
endp GetPrefixCode

; Input: the index in the dictionary to set prefix of, and the value to set the prefix to
; Output: Sets the prefix code at the given index to the given value
proc SetPrefixCode
	push bp
	mov bp, sp
	push ax
	push bx
	index equ [bp + 8]
	first_bytes equ [bp + 4] ; the first 2 bytes of the new prefix
	next_bytes equ [bp + 6] ; the next 2 bytes of the new prefix
	
	mov bx, index
	add bx, 5 ; set bx to the position of the prefixCode at the index
	; set first 2 bytes of prefix
	mov ax, first_bytes
	mov [bx], ax
	; set next 2 bytes of prefix
	add bx, 2
	mov ax, next_bytes
	mov [bx], ax

	pop bx
	pop ax
	pop bp
	ret 6
endp SetPrefixCode
; -----Dictionary Search and insert-----

; Input: Dictionary index, a codeword, a suffix char and a prefixcode
; Summary: Insert the values to the dictionary
proc DictionaryInsertToIndex
	push bp
	mov bp, sp
	index equ [bp + 14]
	codeWord1 equ [bp + 12]
	codeWord2 equ [bp + 10]
	suffix equ [bp + 8]
	prefix1 equ [bp + 6]
	prefix2 equ [bp + 4]

	push index
	push codeWord1
	push codeWord2
	call SetCodeWord

	push index
	push suffix
	call SetSuffixChar

	push index
	push prefix1
	push prefix2
	call SetPrefixCode

	inc [CurrentDictSize]
	
	pop bp
	ret 12
endp DictionaryInsertToIndex


; Input: Index - the index in the dictionary we want to check
;		 prefixCode - (Double word) The prefix code we want to check against
; 		 Char - Suffix character we want to check against
; Output: ax = 1, if the given prefix code and char are equal to the 
;		  prefix code and char at the given index, else ax = 0
proc DictionaryCheckPrefixAndChar
	push bp
	mov bp, sp
	index equ [bp + 10]
	GivenPrefixCode1 equ [bp + 8]
	GivenPrefixCode2 equ [bp + 6]
	Char equ [bp + 4]

	; Get prefix code at index
	push index
	call GetPrefixCode
	; Variable prefixCode now holds the prefix code at index
	; check if the given prefix code is the same as the prefix code at index
	push GivenPrefixCode1
	push GivenPrefixCode2
	push [prefixCode] ; Prefix at index
	call CompareDoubleEqual
	cmp ax, 1
	je CheckChar
	jmp EndDictionaryCheckPrefixAndChar

CheckChar:
	push index
	call GetSuffixChar ; Variable SuffixChar now holds suffix char at index
	mov al, Char
	cmp al, [suffixChar]
	je CharEqual
	jmp CharNotEqual

CharEqual:
	mov ax, 1
	jmp EndDictionaryCheckPrefixAndChar

CharNotEqual:
	mov ax, 0
	jmp EndDictionaryCheckPrefixAndChar

EndDictionaryCheckPrefixAndChar:
	pop bp
	ret 8
endp DictionaryCheckPrefixAndChar


; Input: A prefix code and a char
; Output: The currentIndex set to the index where this combination exists and dx = 1
;		  Or if the combination isn't found, returns dx = 0
proc GetDictionaryIndex
	push bp
	mov bp, sp
	push cx
	push ax
	push bx
	GivenPrefixCode1 equ [bp + 8]
	GivenPrefixCode2 equ [bp + 6]
	Char equ [bp + 4]

	mov cx, [CurrentDictSize]
CheckDictionaryLoop:
	cmp cx, 0
	je DidntFindEntryInDictionary
	dec cx

	push [currentIndex]
	push GivenPrefixCode1
	push GivenPrefixCode2
	push Char
	call DictionaryCheckPrefixAndChar
	cmp ax, 1
	je FoundEntryInDictionary
	
	add [currentIndex], 9
	jmp CheckDictionaryLoop

FoundEntryInDictionary:
	mov dx, 1
	jmp EndGetDictionaryIndex

DidntFindEntryInDictionary:
	mov dx, 0
	jmp EndGetDictionaryIndex

EndGetDictionaryIndex:
	pop bx
	pop ax
	pop cx
	pop bp
	ret 6
endp GetDictionaryIndex

; ---End Dictionary Search and insert---

; ------End Dict control---------


; ------Compression-------
; Output: Sets the value of code to the first char from the input file
proc ReadFirstCharFromInputFile
	call ReadByte
	push ax
	cmp ax, 0 ; In case the file is empty, you never know
	je EndReadFirstCharFromInputFile
	; move read character to variable
	mov al, [buffer]
	xor ah, ah
	mov [word ptr code], ax

EndReadFirstCharFromInputFile:
	pop ax
	ret
endp ReadFirstCharFromInputFile

; Output: Sets the value of character to the next byte read from the input file 
proc ReadCharFromInputFile
	call ReadByte
	push ax
	cmp ax, 0
	je EndReadCharFromInputFile
	; move read character to variable
	mov al, [buffer]
	xor ah, ah
	mov [character], al 

EndReadCharFromInputFile:
	pop ax
	ret
endp ReadCharFromInputFile


; Input: Character to write
; Output: Writes the character to the output file
proc WriteBitChar
	push bp
	mov bp, sp
	c equ [bp + 4]

	cmp [bitcount], 0
	je OutputByte
	; figure out what we need to write
	mov al, c
	mov cl, [bitcount]
	shr al, cl
	mov bl, [bitbuffer]
	mov cl, 8
	sub cl, [bitcount]
	shl bl, cl
	or al, bl
	; write the byte to the file
	xor ah, ah
	push ax
	call WriteByte

	mov al, c
	mov [bitbuffer], al
	jmp EndWriteBitChar

OutputByte:
	push c
	call WriteByte


EndWriteBitChar:
	pop bp
	ret 2
endp WriteBitChar

; Input: a value of 1 or 0 (a bit).
; Output: bit written to file if can, otherwise waits until more bits are entered and the bit count is a byte
; Summary:  Uses bitcount and bit buffer variables to dictate writing of bits to a file
proc WriteBit
	push bp
	mov bp, sp
	push ax
	BitToWrite equ [bp + 4]

	inc [bitcount]
	shl [bitbuffer], 1
	mov ax, 0
	cmp BitToWrite, ax
	jne BitIsAOne
	jmp CheckIfAbleToWrite

BitIsAOne:
	or  [bitbuffer], 1 ; insert the bit to the buffer

CheckIfAbleToWrite:
	cmp [bitcount], 8
	jne EndWriteBit

	; Able to write bit
	mov al, [bitbuffer]
	xor ah, ah ; make sure we are only writing what is in bitbuffer
	push ax
	call WriteByte
	; reset Buffer
	mov [bitcount], 0
	mov [bitbuffer], 0

EndWriteBit:
	pop ax
	pop bp
	ret 2
endp WriteBit

; Input: Offset of bytes to write, number of bits to write
; Output: Writes the bits to the file
proc WriteBits
	push bp
	mov bp, sp
	bytesOffset equ [bp + 6]
	NumOfBitsToWrite equ [bp + 4]

	mov cx, NumOfBitsToWrite
	mov bx, bytesOffset
	mov al, [bx]

WriteBitsLoop:
	cmp cx, 0
	je EndWriteBits

	push ax ; save value, we need it later.
	and al, 80h
	xor ah, ah
	push ax
	call WriteBit
	pop ax ; this is later.

	shl al, 1
	dec cx

	jmp WriteBitsLoop


EndWriteBits:
	pop bp
	ret 4
endp WriteBits

; Input: Double word codeword to write to file at [outputFilehandle]
; Output: writes the code word to the file as 12 bits
proc WriteToFile
	push bp
	mov bp, sp
	CodeWord1 equ [bp + 6]
	CodeWord2 equ [bp + 4]

	push offset TempToWrite
	push CodeWord1
	push CodeWord2
	call MoveDoubleWord

	push offset TempToWrite
	push 0
	push 0FFh
	call BitWiseAndDouble

	xor ax, ax
	mov ax, [word ptr TempToWrite]
	push ax
	call WriteBitChar

	push offset TempToWrite
	push CodeWord1
	push CodeWord2
	call MoveDoubleWord
	push offset TempToWrite
	push 4
	call RightShiftDouble
	push offset TempToWrite
	push 0
	push 0FF0h
	call BitWiseAndDouble


	; write rest
	push offset TempToWrite
	push 4
	call WriteBits

	pop bp
	ret 4
endp WriteToFile

; USES:
; input file, output file
; code dd
; nextCode dd
; character db
; currentIndex dw
proc Compress
	; Dictionary is empty

	call ReadFirstCharFromInputFile
	cmp ax, 0
	je @EndCompress

CompressionLoop:
	; set the search index to the start of the dictionary
	mov [currentIndex], offset compDict
	call ReadCharFromInputFile
	cmp ax, 0
	je @EndCompress

	push [code]
	mov al, [character]
	xor ah, ah
	push ax
	call GetDictionaryIndex

	cmp dx, 1
	je InDictionary
	; Code is not in the dictionary, add it if we can
	push [nextCode]
	push [MaxCodeWord]
	call CompareDoubleLessThan
	cmp ax, 1 ; if the next code is less than the max code word
	je AddToDictionary
	jmp OutputCode

@EndCompress:
	jmp EndCompress

AddToDictionary:
	push [currentIndex]
	push [nextCode] ; code word
	mov al, [character]
	xor ah, ah
	push ax ; suffix char
	push [code] ; prefix code
	call DictionaryInsertToIndex

	push offset nextCode
	call IncDouble

OutputCode:
	; output code
	push [code]
	call WriteToFile

	; the new code is now the character
	push offset code
	push 0
	mov al, [character]
	xor ah, ah
	push ax
	call MoveDoubleWord

	jmp CompressionLoop

InDictionary:
	; code + character is in the dictionary
	; makes it's code the new code
	push [currentIndex]
	call GetCodeWord
	push offset code
	push [codeWord]
	call MoveDoubleWord

	jmp CompressionLoop
	

EndCompress:
	; print last code to the output
	push [code]
	call WriteToFile

	call ResetBitbuffer
	ret
endp Compress
; ----End Compression-----

; -----Decompression------

; Reading the encoded file

; Summary: Gets a byte from the input file using according to the bitbuffer and bitcount
; Output: Sets the value of GetCharReturnValue
proc BitGetChar
	mov [GetCharReturnValue], 0

	call ReadByte
	push ax ; if it failed we can check the value of ax
	; check ax for end of file
	cmp ax, 0
	je BitEndGetChar 
	mov dl, [buffer]
	mov [GetCharReturnValue], dl
	cmp [bitcount], 0
	je BitEndGetChar

	; al acts as temp variable
	mov al, [GetCharReturnValue]
	mov cl, [bitcount]
	shr al, cl
	; shift the bitbuffer's value by 8 - bitcount
	mov cl, 8
	sub cl, [bitcount]
	mov ah, [bitbuffer]
	shl ah, cl
	; or temp by the shifted amount
	or al, ah

	; put remaining in buffer
	mov dl, [GetCharReturnValue]
	mov [bitbuffer], dl

	mov [GetCharReturnValue], al
	jmp BitEndGetChar

BitEndGetChar:
	pop ax ; in order to check if the read failed
	ret
endp BitGetChar


; Output: returns in dl the value of a bit read from an input open file
; 	      If ax = 0, the reading failed(End of file), else ax = 1 and we succeded
proc ReadBit
	push cx

	cmp [bitcount], 0
	jne PreBufferNotEmpty
	; Buffer is empty
	; read another character
	call ReadByte
	push ax
	; check if it's the end of file
	cmp ax, 0
	je EndReadBit

	mov [bitcount], 8
	mov al, [Buffer]
	mov [bitbuffer], al ; move read character to buffer
	jmp BufferNotEmpty

PreBufferNotEmpty:
	push 1 ; to signal that the reading was successful
BufferNotEmpty:
	dec [bitcount]
	mov cl, [bitcount]
	mov dl, [bitbuffer]
	shr dl, cl
	and dl, 1


EndReadBit:
	pop ax
	pop cx
	ret
endp ReadBit


; Input: offset of a byte variable we want to return the value to
; Output: The value of the read bits to the inputted offset
proc ReadBits
	push bp
	mov bp, sp
	ByteOffset equ [bp + 4]
	mov cx, 4

ReadBitsLoop:
	call ReadBit ; return value in dl
	cmp ax, 0
	je EndReadBit ; The reading failed (End of file, we read 0 bytes)
	mov bx, ByteOffset
	shl [byte ptr bx], 1
	and dl, 1
	or [byte ptr bx], dl
	loop ReadBitsLoop
	; shift last bits
	shl [byte ptr bx], 4

EndReadBits:
	pop bp
	ret 2
endp ReadBits


; Input: The offset of the variable we want to return the value to
; Output: The next code in the compressed stream in the offset we inputted.
;		  (The offset is of a double word type variable)
proc ReadCode
	push bp
	mov bp, sp
	ReturnToOffset equ [bp + 4]
	mov ax, 0
	push offset TempToRead
	push 0
	push 0
	call MoveDoubleWord

	call BitGetChar
	cmp ax, 0
	je EndReadCode

	push ReturnToOffset
	push 0
	mov al, [GetCharReturnValue]
	xor ah, ah
	push ax
	call MoveDoubleWord

	push offset TempToRead
	call ReadBits
	cmp ax, 0
	je EndReadCode
	push ax

	push offset TempToRead
	push 4
	call LeftShiftDouble	
	push ReturnToOffset
	push [TempToRead]
	call BitWiseOrDouble

	pop ax


EndReadCode:
	pop bp
	ret 2
endp ReadCode


; Input: A code value
; Output: In dl the value of the char that we decoded
; Summary: Recusively searches the dictionary to find the code
proc DecodeCode
	push bp
	mov bp, sp
	sub sp, 4
	OutputCharRecursive equ [bp - 2]
	firstChar equ [bp - 4]
	Code1 equ [bp + 6]
	Code2 equ [bp + 4]
	push offset TempCode
	push 0
	push 0
	call MoveDoubleWord

	push offset TempCode
	push Code1
	push Code2
	call MoveDoubleWord

	push [TempCode]
	push 0
	push FIRST_CODE
	call CompareDoubleEqualAbove
	cmp ax, 1 ; if the given code is equal or above the first code
	je RecursiveDecodeCode
	jmp CodeReached

RecursiveDecodeCode:
	push [TempCode]
	call CalculateIndex

	mov ax, [word ptr DecodeIndex]
	; Suffix char
	push ax ; low word of decode index
	call GetSuffixChar	
	mov al, [suffixChar]
	mov OutputCharRecursive, al
	; Prefix code
	mov ax, [word ptr DecodeIndex]
	push ax ; low word of decode index
	call GetPrefixCode
	push offset TempCode ; acts as a temp for the code inputted above
	push [prefixCode]
	call MoveDoubleWord 

	push [TempCode]
	call DecodeCode
	mov FirstChar, dl ; return value of decode code is in dl
	jmp OutputDecoded

CodeReached:
	mov bx, offset TempCode
	mov al, [bx]
	mov OutputCharRecursive, al
	mov FirstChar, al

OutputDecoded:
	mov al, OutputCharRecursive
	xor ah, ah
	push ax
	call WriteByte

	mov dl, FirstChar

	add sp, 4
	pop bp
	ret 4
endp DecodeCode

; Input: Index in the dictionary, a prefix code, and a suffix char
; Summary: Adds values to the dictionary at the given index
proc AddToDecodeDictionary
	push bp
	mov bp, sp
	Index equ [bp + 10]
	GivenPrefixCode1 equ [bp + 8]
	GivenPrefixCode2 equ [bp + 6]
	GivenSuffixChar equ [bp + 4]

	push Index
	push GivenPrefixCode1
	push GivenPrefixCode2
	call SetPrefixCode

	push Index
	push GivenSuffixChar
	call SetSuffixChar

	push offset nextCode
	call IncDouble

	pop bp
	ret 8
endp AddToDecodeDictionary

; Summary: Set the first values when starting to decode
proc InitializeDecoding
	push offset lastCode
	call ReadCode

	mov al, [byte ptr lastCode]
	mov [OutputChar], al

	mov bx, offset lastCode
	push [word ptr bx] ; the low word of the last code variable.
	call WriteByte

	ret
endp InitializeDecoding


; Summary: On the occasion where the decoder gets a code it does not have in it's dictionary.
; 		   We know on what occasion this happens, so we calculate the correct output.
proc DecodingException
	push bp
	mov bp, sp
	sub sp, 2
	TempChar equ [bp - 2]

	mov al, [OutputChar]
	xor ah, ah
	mov TempChar, ax

	push [lastCode]
	call DecodeCode
	mov [OutputChar], dl ; return value of decode code

	push TempChar
	call WriteByte

	add sp, 2
	pop bp
	ret
endp DecodingException

; Input: A code's Value
; Output: Sets the DecodeIndex to the correct index in the dictionary to start the decoding at
proc CalculateIndex
	push bp
	mov bp, sp
	Double1 equ [bp + 6]
	Double2 equ [bp + 4]

	push offset DecodeIndex
	push Double1
	push Double2
	push 0
	push FIRST_CODE
	call SubDouble

	push offset DecodeIndex
	push [DecodeIndex]
	push 9
	call MulDoubleByByte

	push offset DecodeIndex
	push [DecodeIndex]
	push 0
	push offset compDict
	call AddDouble ; add the offset of the dictionary to the index

	pop bp
	ret 4
endp CalculateIndex

; Summary: Calculates the index of the dictionary to insert the last code and output char to
proc AddToDecode
	push [nextCode]
	call CalculateIndex

	mov ax, [word ptr DecodeIndex]
	push ax ; only first word of decode index, the max index is 9000h, the double word size is used for easy calculation
	push [lastcode]
	xor ah, ah
	mov al, [OutputChar]
	push ax
	call AddToDecodeDictionary

	ret
endp AddToDecode

; Summary: Decompress the input file and output the results to the output file. According to the LZW algorithm 
proc Decompress
	call InitializeDecoding

DecodingLoop:
	; read next code
	push offset code
	call ReadCode
	cmp ax, 0 ; exit if we reached end of file
	je @EndDecompress

	push [code]
	push [nextCode]
	call CompareDoubleLessThan
	cmp ax, 1
	je KnownCode
	call DecodingException
	jmp DecodeAddDictionary


KnownCode:
	push [code]
	call DecodeCode
	mov [OutputChar], dl
	jmp DecodeAddDictionary

@EndDecompress:
	jmp EndDecompress

DecodeAddDictionary:
	; check if we can add to the dictionary
	push [nextCode]
	push [MaxCodeWord]
	call CompareDoubleLessThan
	cmp ax, 0 ; if we can't continue
	je ContinueDecode
	; otherwise add to the dictionary
	call AddToDecode

ContinueDecode:
	push offset lastCode
	push [code]
	call MoveDoubleWord

	jmp DecodingLoop

EndDecompress:
	ret
endp Decompress
; -----End-Decompression------

start:
	mov ax, @data
	mov ds, ax
; --------------------------
	call PrintStartScreen
	call Run
; --------------------------
	
exit:
	mov ax, 4c00h
	int 21h
END start

