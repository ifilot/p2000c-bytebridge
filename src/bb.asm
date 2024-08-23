;-------------------------------------------------------------------------------
CPU 8086    ; specifically compile for 8086 architecture (compatible with 8088)
;-------------------------------------------------------------------------------

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
    mov bx,cx
    call printhex

    ; receive path over serial port
    mov di,path
nextbyte:
    mov ah,1
    mov al,ch
    int 14h                 ; respond upper byte
    mov [di],al
    inc di
    cmp al,0
    jne nextbyte

    ; print path to screen
    dec di
    mov si,di
    mov al,'$'
    mov [di],al
    mov ah,9
    mov dx,path
    int 21h

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

;-------------------- SECTION DATA --------------------------------------------- 
section .data 

;-------------------- SECTION BSS ----------------------------------------------
section .bss       

; number of bytes read
nrbytes:
    resb 2

; 256 byte buffer
path:
    resb 256