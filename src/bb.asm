;-------------------------------------------------------------------------------
CPU 8086    ; specifically compile for 8086 architecture (compatible with 8088)
;-------------------------------------------------------------------------------
    org 100h

start:
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
    mov si,di
    mov al,'$'
    mov [di],al
    mov ah,9
    mov dx,writingtostr
    int 21h
    mov ah,9
    mov dx,path
    int 21h
    call lncr
    mov al,0                ; restore terminating character
    mov [di],al

    ; read datastream
    mov di,buffer
    mov cx,[nrbytes]
nextbyte:
    mov ah,2
    int 14h
    mov [di],al
    inc di
    loop nextbyte

    ; create the new file
    mov ah,3ch
    mov cx,0
    mov dx,path
    int 21h
    jc error
    mov [filehandle],ax         ; store filehandle

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
; print error and terminate program
;-------------------------------------------------------------------------------
error:
    mov dx,errorstring          ; set pointer to error string
    mov ah,09h                  ; print error string to screen
    int 21h                     ; run it
    
    mov ah,00h                  ; terminate program
    int 21h                     ; run it

;-------------------- SECTION DATA --------------------------------------------- 
section .data

numbytesstr:
    db "Number of bytes: 0x$"

writingtostr:
    db "Writing to: $"

errorstring:
    db "An error was encountered.$"

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