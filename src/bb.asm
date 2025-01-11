;------------------------------------------------------------------------------
CPU 8086    ; specifically compile for 8086 architecture (compatible with 8088)
;------------------------------------------------------------------------------
    org 100h

start:
    ; configure terminal interface
    mov al,11101011b        ; 9600 BAUD, odd parity, single stop bit, 8 bpp
    mov ah,0                ; set serial interface parameters
    int 14h                 ; run interrupt

    ; inform the user on settings
    mov dx,parameterstr     ; load pointer to string
    mov ah,09h              ; print string routine
    int 21h                 ; run interrupt
    call lncr               ; call newline routine
    mov dx,readystr         ; set pointer to message string
    mov ah,09h              ; print string routine
    int 21h                 ; run interrupt
    call lncr

;===============================================================================
; READ METADATA
;===============================================================================
    ; read number of bytes to transfer from serial port
    call receive_word       ; receive 16 bit unsigned integer
    mov [nrbytes],cx        ; store file length
    call receive_word       ; receive next 16 bit unsigned integer
    mov [checksum],cx       ; store checksum overall file checksum
    mov cx,[nrbytes]        ; move total number of bytes to cx
    call send_word          ; respond nr bytes
    mov cx,[checksum]       ; move checksum
    call send_word          ; respond checksum
    
    ; print number of bytes to screen
    mov dx,numbytesstr      ; load pointer to string
    mov ah,9                ; print string routine
    int 21h                 ; run interrupt
    mov bx,[nrbytes]        ; load number of bytes
    call printword          ; print number of bytes in hex to screen
    call lncr               ; print newline character

    ; print checksum to screen
    mov dx,checksumstr      ; load pointer to string
    mov ah,9                ; print string routine
    int 21h                 ; run interrupt
    mov bx,[checksum]       ; load checksum
    call printword          ; print number of bytes in hex to screen
    call lncr               ; print newline character

    ; calculate number of packages to receive
    mov bx,[nrbytes]        ; load number of bytes
    cmp bl,0                ; check if bl is zero
    je skipinc              ; skip if zero
    inc bh                  ; if not, increment bh
skipinc:
    mov [nrpacktotal],bh    ; store number of packages
    mov [nrpackages],bh     ; store number of packages that remain to be read

    ; inform user about number of packages
    mov dx,numpackstr       ; load pointer to string
    mov ah,9                ; print string routine
    int 21h                 ; run interrupt
    mov bh,[nrpacktotal]    ; load number of packages
    call printbyte          ; print number of packages in hex
    call lncr               ; print newline character

    ; receive path over serial port
    mov di,path             ; set pointer to path
nextchar:
    mov ah,2                ; read char over serial routine
    int 14h                 ; receive character
    mov [di],al             ; store character
    inc di                  ; increment pointer
    cmp al,0                ; check for terminating character
    jne nextchar            ; if not, read next character

    ; print path to screen
    dec di                  ; decrement string pointer
    mov [termbyte],di       ; store pointer to terminating byte (needed later)
    mov al,'$'              ; set terminating character for screen print
    mov [di],al             ; store at pointer
    mov ah,9                ; print string routine
    mov dx,filenamestr      ; print filename
    int 21h                 ; run interrupt
    mov ah,9                ; print string routine
    mov dx,path             ; set pointer to file path string
    int 21h                 ; run interrupt
    call lncr               ; print newline character

;===============================================================================
; READ DATASTREAM
;===============================================================================
    mov dx,startrecstr      ; set pointer to message string
    mov ah,09h              ; print error string to screen
    int 21h                 ; run it
    call lncr               ; print newline character

    ; initialize buffer and counter
    mov di,buffer
nextpacket:
    call read_packet        ; read packet
    mov cl,[nrpackages]     ; load number of packages that remain
    dec cl                  ; decrement by one
    mov [nrpackages],cl     ; store value in memory
    cmp cl,0                ; check whether all packets have been received
    jne nextpacket          ; if not, read next packet

    ; calculate and print checksum
    mov dx,[nrbytes]
    mov si,buffer
    call crc16      ; checksum in bx
    mov ax,[checksum]
    cmp ax,bx       ; compare checksum
    jne error       ; if not equal, exit, do not write
    mov dx,checksumvalstr
    mov ah,9
    int 21h
    call lncr

;===============================================================================
; WRITE FILE
;===============================================================================
    ; start writing procedure
    mov ah,9
    mov dx,writestr
    int 21h
    mov ah,9
    mov dx,path
    int 21h
    call lncr

    ; create the new file
    mov di,[termbyte]       ; restore pointer to terminating byte of filename
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
; Read packet routine
;-------------------------------------------------------------------------------
read_packet:
    mov cx, 256             ; number of bytes in a packet
.nextbyte:
    mov ah,2
    int 14h
    mov [di],al
    inc di
    loop .nextbyte
    mov bh, [nrpacktotal]   ; load total number of packages (T)
    mov bl, [nrpackages]    ; load number of packages that need to be read (N)
    sub bh,bl               ; T - N
    inc bh                  ; increment by one
    call printbyte          ; print package number (output BH as HEX)
    mov ah,9                ; print string
    mov dx,packsplitstr     ; pointer to string
    int 21h                 ; run interrupt
    mov si,di               ; transfer buffer pointer to si
    sub si, 256             ; subtract 256 to get to begin of package
    mov dx, 256             ; number of bytes in checksum
    call crc16              ; calculate checksum, store result in BX
    mov ah,1
    mov al,bh               ; transfer high byte
    int 14h
    mov ah,1
    mov al,bl               ; transfer low byte
    int 14h
    call printword          ; print checksum to screen
    call lncr
    ret

;-------------------------------------------------------------------------------
; Receive word in CX
;-------------------------------------------------------------------------------
receive_word:
    mov ah,2
    int 14h                 ; receive lower byte filelength
    mov cl,al
    mov ah,2
    int 14h                 ; receive upper byte filelength
    mov ch,al
    ret

;-------------------------------------------------------------------------------
; Send word from CX
;-------------------------------------------------------------------------------
send_word:
    mov ah,1
    mov al,cl
    int 14h                 ; respond lower byte
    mov ah,1
    mov al,ch
    int 14h                 ; respond upper byte
    ret

;-------------------------------------------------------------------------------
; Print value in BX to screen
;-------------------------------------------------------------------------------
printword:
    call printbyte          ; print BH to screen
    mov bh, bl              ; put BL in BH
    call printbyte          ; print BL to screen
    ret

;-------------------------------------------------------------------------------
; Print value in BH to screen
;-------------------------------------------------------------------------------
printbyte:
    mov dl,bh
    mov cl,4                ; load number of bits to shift
    ror dl,cl               ; shift 4 bits in dl
    call print_nibble       ; print upper nibble
    mov dl,bh               ; load bl again in bh
    call print_nibble       ; print lower nibble
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

parameterstr:
    db "BAUD: 9600, PARITY: ODD, STOPBITS: 1, BYTESIZE: 8$"

readystr:
    db "Ready to receive file. Start the transfer.$"

numbytesstr:
    db "Number of bytes to receive: 0x$"

filenamestr:
    db "Filename: $"

numpackstr:
    db "Number of packages to receive: 0x$"

packsplitstr:
    db ": 0x$"

startrecstr:
    db "Receiving bytes. This might take a while.$"

writestr:
    db "Writing file to: $"

checksumstr:
    db "Expected checksum: 0x$"

checksumvalstr:
    db "Checksum validation OK$"

errorstring:
    db "An error was encountered.$"

timeoutstr:
    db "Received timeout. Exiting.$"

donestr:
    db "All done!$"

;-------------------- SECTION BSS ----------------------------------------------
section .bss       

; number of bytes read
nrbytes:
    resb 2

; XMODEM CRC16 checksum
checksum:
    resb 2

; number of 256-byte packages that remain
nrpackages:
    resb 1

; total number of 256 byte packages to receive
nrpacktotal:
    resb 1

; dword with file pointer
filehandle:
    resb 2

; 256 byte buffer
path:
    resb 256

; pointer to terminating byte
termbyte:
    resb 2

; data to write
buffer: