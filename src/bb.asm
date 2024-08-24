;-------------------------------------------------------------------------------
CPU 8086    ; specifically compile for 8086 architecture (compatible with 8088)
;-------------------------------------------------------------------------------
    org 100h

start:
    mov dx,readystr         ; set pointer to message string
    mov ah,09h              ; print error string to screen
    int 21h                 ; run it
    call lncr

    ; read number of bytes to transfer from serial port
    mov ah,2
    int 14h                 ; receive lower byte filelength
    mov cl,al
    mov ah,2
    int 14h                 ; receive upper byte filelength
    mov ch,al
    mov [nrbytes],cx        ; store filelength
    mov ah,1
    mov al,cl
    int 14h                 ; respond lower byte
    mov ah,1
    mov al,ch
    int 14h                 ; respond upper byte
    
    ; print number of bytes to screen
    mov ah,9
    mov dx,numbytesstr
    int 21h
    mov bx,cx
    call printhex
    call lncr

    ; receive path over serial port
    mov di,path
nextchar:
    mov ah,2
    mov al,ch
    int 14h                 ; receive character
    mov [di],al
    inc di
    cmp al,0
    jne nextchar

    ; print path to screen
    dec di
    mov si,di               ; store pointer to terminating byte of filename
    mov al,'$'              ; set terminating character for screen print
    mov [di],al
    mov ah,9
    mov dx,filenamestr      ; print filename
    int 21h
    mov ah,9
    mov dx,path
    int 21h
    call lncr
    
    ; read datastream
    mov dx,startrecstr      ; set pointer to message string
    mov ah,09h              ; print error string to screen
    int 21h                 ; run it
    call lncr
    mov di,buffer
    mov cx,[nrbytes]
nextbyte:
    mov ah,2
    int 14h
    mov [di],al
    inc di
    loop nextbyte

    ; calculate CRC-16 checksum and output to screen
    mov dx,crc16str         ; set pointer to message string
    mov ah,09h              ; print error string to screen
    int 21h                 ; run it

    mov si,buffer           ; data pointer
    mov dx,[nrbytes]        ; number of bytes
    call crc16              ; CRC16 checksum is stored in BX
    call printhex           ; output to screen
    call lncr               ; call newline

    ; start writing procedure
    mov ah,9
    mov dx,writestr
    int 21h
    mov ah,9
    mov dx,path
    int 21h
    call lncr

    ; create the new file
    mov di,si               ; restore pointer to terminating byte of filename
    mov al,0                ; restore terminating character
    mov [di],al
    mov ah,3ch
    mov cx,0
    mov dx,path
    int 21h
    jc error
    mov [filehandle],ax     ; store filehandle

    ; write data to file handle
    ; (see: https://stanislavs.org/helppc/int_21-40.html)
    mov ah,40h
    mov bx,[filehandle]
    mov cx,[nrbytes]
    mov dx,buffer
    int 21h
    jc error

    ; close file
    ; (see: https://stanislavs.org/helppc/int_21-3e.html)
    mov bx,[filehandle]
    mov ah,3eh
    int 21h
    jc error

    ; exit program
    mov ah,9
    mov dx,donestr
    int 21h
    int 20h

;-------------------------------------------------------------------------------
; Print value in BX to screen
;-------------------------------------------------------------------------------
printhex:
    mov dl,bh
    mov cl,4
    ror dl,cl
    call print_nibble
    mov dl,bh
    call print_nibble
    mov dl,bl
    ror dl,cl
    call print_nibble
    mov dl,bl
    call print_nibble
    ret

;-------------------------------------------------------------------------------
; print lower nibble in DL to the screen
;-------------------------------------------------------------------------------
print_nibble:
    and dl,0Fh
    add dl,'0'
    cmp dl,'9'
    jbe print_digit
    add dl,7
print_digit:
    mov ah,2
    int 21h
    ret

;-------------------------------------------------------------------------------
; write a newline character and a carriage return character
;-------------------------------------------------------------------------------
lncr:
    mov ah,2
    mov dl,`\n`
    int 21h
    mov dl,`\r`
    int 21h
    ret

;-------------------------------------------------------------------------------
; generate CRC16 checksum
; INPUT:  SI - pointer to data
;         DX - number of bytes
; OUTPUT: BX - CRC16 checksum
;-------------------------------------------------------------------------------
crc16:
    mov bx,0        ; start with a 0 checksum
    mov al,0
.crcloop:
    mov ah,[si]     ; load character from memory
    xor bx,ax       ; xor into top byte
    inc si
    mov cx,8        ; number of bits to shift
.bitloop:
    shl bx,1
    jc .crc_poly    ; if highest bit is set, xor with polynomial
    loop .bitloop
    jmp .nextbyte
.crc_poly:
    xor bx,0x1021   ; xor with the XMODEM polynomial
    loop .bitloop
.nextbyte:
    dec dx
    jnz .crcloop
    ret

;-------------------------------------------------------------------------------
; print error and terminate program
;-------------------------------------------------------------------------------
error:
    mov dx,errorstring          ; set pointer to error string
    mov ah,09h                  ; print error string to screen
    int 21h                     ; run it
    
    mov ah,00h                  ; terminate program
    int 21h                     ; run it

;-------------------------------------------------------------------------------
; timeouts
;-------------------------------------------------------------------------------
timeout:
    mov dx,timeoutstr           ; set pointer to error string
    mov ah,09h                  ; print error string to screen
    int 21h                     ; run it
    
    mov ah,00h                  ; terminate program
    int 21h                     ; run it

;-------------------- SECTION DATA --------------------------------------------- 
section .data

readystr:
    db "Ready to receive file. Start the transfer.$"

numbytesstr:
    db "Number of bytes to receive: 0x$"

filenamestr:
    db "Filename: $"

startrecstr:
    db "Receiving bytes. This might take a while.$"

writestr:
    db "Writing file to: $"

errorstring:
    db "An error was encountered.$"

crc16str:
    db "CRC16 checksum: 0x$"

timeoutstr:
    db "Received timeout. Exiting.$"

donestr:
    db "All done!$"

;-------------------- SECTION BSS ----------------------------------------------
section .bss       

; number of bytes read
nrbytes:
    resb 2

; dword with file pointer
filehandle:
    resb 2

; 256 byte buffer
path:
    resb 256

; data to write
buffer: