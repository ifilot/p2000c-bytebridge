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

    ; exit program
    int 20h

;
; Print value in BX to screen
;
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

lncr:
    mov ah,2
    mov dl,`\n`
    int 21h
    mov dl,`\r`
    int 21h
    ret

;-------------------- SECTION DATA --------------------------------------------- 
section .data

numbytesstr:
    db "Number of bytes: 0x$"

writingtostr:
    db "Writing to: $"

;-------------------- SECTION BSS ----------------------------------------------
section .bss       

; number of bytes read
nrbytes:
    resb 2

; 256 byte buffer
path:
    resb 256

buffer:
    resb 1024