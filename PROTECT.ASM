;;;; Placed into the public domain 12 Dec 1992.

;;;; MS-DOS 8086/8088 assembly language program to load a TSR which
;;;;  traps disk writes at the BIOS level (INT 13h).

;;; NOTE: The user refers to the drives as 0-6; the are represented
;;;  internally as 1-7.

;;;; NOTE: This file must be assembled into a .COM file.  See
;;;;  the associated make files for the command procedures.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Define a macro to call the DOS string output function.
;;;  There is one parameter: the address of the beginning of the string.
;;;  (Offset only; segment must be in ds).  The string must end in
;;;  a $ (a prerequisite for the DOS function).
;;
StringOut MACRO stringAddress
        lea dx,stringAddress ; Load offset of message.
        mov ah,09h           ; DOS function to print a string.
        int 21h              ; Call DOS.
          ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Set up segments and names.  Necessary to produce a .com file
;;;  with some assemblers.
;;
Protect SEGMENT
Main    PROC FAR
        ASSUME cs:Protect
        ASSUME ds:Protect

;;
;;; This assembler directive to start assembled code at address 0100h
;;;  is necessary when assembling into .COM files.
;;
        ORG 0100h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; This is the starting point when this program is entered from DOS
;;;  as a command.
;;
go:
        jmp initialize       ; Jump to the initialization function.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; STAY RESIDENT CODE: This is the Protect interrupt handler.  The
;;;  Protect INT 13h (disk access through the BIOS) routine will:
;;;   1) Check the disk accessed.  If it is a floppy disk or an
;;;   unprotected hard disk, allow it by calling the DOS INT 13h
;;;   handler.
;;;   2) Check the disk function.  If it is not a write or format,
;;;   allow it.
;;;   3) If the request is not allowed, set up the registers to
;;;   show a protected disk error, and return.
;;
startResidentCode:

;;
;;; Data storage area for stay resident routine.
;;
oldVector  DD ?   ; The original vector address.
protStatus DB 0ffh ; The protection status:
                   ;  00h = Protection off.
                   ;  ffh = Protect all hard drives (drives greater than 80h).
                   ;  01h = Protect just the first drive (drive 0)...
                   ;  0xh = Protect just the drives who's bits are on.
                   ;        Example: 0101 protects zero and two.

;;
;;; The Protect interrupt handler for 13h starts here.
;;;  If this code is executed, then a disk access request has been
;;;  made to the BIOS through interrupt 13h.
;;
protINT13handler:

;;
;;; Check if this disk is protected.  Disk to be accessed is in register dl.
;;
        cmp dl,80h      ; Floppy disk request,
        jb allowAccess  ;  allow access.

                  ; Note: Only 16 bit quantities may be pushed & popped.
        push cx   ; Save the count register (need for shift).
        push ax   ; Save the accumulator (needed for shift).

        mov cl,dl  ; The count register will hold
        sub cl,80h ;  the fixed disk number,
        inc cl     ;  counting from one.
        mov al,80h ; This bit will be shifted into the accumulator,
        rol al,cl  ;  <drive number> times, to match the protStatus
                   ;  bit for this fixed drive.

        test al,cs:protStatus ; Load flags with comparison, to be checked
                             ;  below.  This is a one segment routine, so
                             ;  the data segment must be overridden

        pop ax  ; Restore registers.  Luckily, the pop instruction does not
        pop cx  ;  affect the flags (which haven't been checked yet).

        jz allowAccess ; Check the flags from the above "test".  If the bit
                       ;  for this drive is off, allow the access.

;;
;;; If here, then the requested disk is protected.  See if the requested
;;;  service (in register ah) will change data on the disk (is destructive).
;;
        cmp ah,03h   ; Write sector requested.
        je causeError
        cmp ah,05h   ; Format sector requested.
        je causeError
        cmp ah,06h   ; Format track requested (XT class BIOS only).
        je causeError
        cmp ah,07h   ; Format disk requested (XT class BIOS only).
        je causeError
        cmp ah,0Bh   ; Write long sector requested (DOS diagnostic routine).
        je causeError

;;
;;; If here, the disk request is not destructive;
;;;  jump to the original vector.
;;
allowAccess:
        jmp cs:[oldVector] ; Intersegment jump (assembler knows this because
                           ;  oldVector is type DD).  Note this "data" is
                           ;  in the code segment.

;;
;;; Abort the disk request.  Return with the registers set to:
;;;  "write protect error on disk".
;;
causeError:
        mov ah,03h   ; Return value for interrupt - write protect error.
        stc          ; Set carry flag, to signal error to caller.
        ret 0002h    ; Return from interrupt; iret is not used because
                     ;  it sets the flags back to what they when the
                     ;  interrupt happened (resetting the carry flag);
                     ;  ret 2 throws the old flags away, then returns.

;;
;;; End of stay resident code.
;;
endResident:

;;
;;; The 'magicSize' constant will be used to determine if this
;;;  interrupt handler is already loaded.  The above routine will be
;;;  compared with the current handler to see if they are the same.
;;
magicSize EQU endResident - protINT13handler

;;
;;; The protection status offset is the distance in bytes from
;;;  the top of the interrupt handler to the byte containing the
;;;  protection status.   Useful for for finding the protection status
;;;  of the resident copy of protect from a second copy.  (See below.)
;;
protStatusOffset EQU protINT13handler - protStatus


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; THIS CODE IS ALWAYS DISCARDED (even if exit is TSR).
;;

;;
;;; This message will be embedded in the code.
;;
copyrightMes DB 'Binary and source in the public domain.'

;;
;;; Storage space for discarded code.
;;
thereIsParam DB  00h  ; Are there parameters?

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; INITIALIZATION CODE.  Check parameters; then check if Protect
;;;  interrupt handler is already loaded.
;;
initialize:

IFDEF MAKING_PROTECT ; ### Only if making protect.com file.

;;
;;; SET UP SEGMENT REGISTERS: When this program is entered from DOS,
;;;  the ds (data segment) register points to the beginning of the
;;;  PSP (Program Segment Prefix); and the cs (code segment) register
;;;  points to the "go:" label, above.
;;; This is one segment program; the code and data are both in
;;;  the code segment.  So, after saving the ds register (the PSP
;;;  will be needed to find any parameters), make the ds register
;;;  the same as the cs register.
;;
        mov ax,ds  ; Save the ds register (now at the beginning of the PSP),
        mov es,ax  ;  into the es register (PSP is needed by FindParam).
                   ; (Two moves are needed because of addressing
                   ;   restrictions.)

        mov ax,cs  ; Load data segment register.  (Two move because
        mov ds,ax  ;  of addressing restrictions.)

;;
;;; FIND AND CHECK THE PARAMETERS: Parameters are used to protect some
;;;  disks while leaving others unprotected.  The parameter must be
;;;  an integer between 0 and 6, or A to protect all drives.
;;;  If there is a parameter, protection will be added for that physical
;;;  drive (or all drives).
;;
        call FindParam ; Call subroutine to parse parameter list.
                       ;  Results will be returned in the al and
                       ;  bl registers.

        cmp al,02h     ; Check for invalid parameters.
        jne paramsOK   ; Jump if parameters are ok.

        StringOut invalidParamMes ; Bad parameters: show usage message, -
        jmp exitOut               ;  then exit.

paramsOK:
        cmp al,00h    ; There are no parameters;
        je doneParam  ;  there is no need to do anything;
                      ;  the default is no parameters.

;;
;;; If here, there is a valid parameter. Save it, then check to
;;;  see how many drives there are.
;;
        mov thereIsParam,0ffh ; Record presence of parameter.
        cmp bl,0ffh         ; Test for protect all drives.
        jne setStatus       ; If not, set the status bits for the drive, etc..
        mov protStatus,0ffh ; Protect all drives.
        jmp doneParam       ; Jump over set status & check drive number.
 
setStatus:
        mov cl,bl  ; Load count register with drive number.
                   ; Make protection status bit for this drive.
                   ;  (Drive number is now in the cl register.)
        mov al,80h ; This bit will be shifted into al,
        rol al,cl  ;  <drive number> times, to match the protStatus
                   ;  bit for this fixed drive.

        mov protStatus,al ; Save the drive number as protection status.

        mov ah,08h  ; Get ready to use fixed drive function
        mov dl,80h  ;  to get information (08h); 80h specifies
                    ;  fixed disk information.
        int 13h     ; Call BIOS - 13h is fixed drive request.
                    ; The number of fixed disks is in register dl.

        cmp bl,dl     ; Compare requested fixed disk with
                      ;  the actual number of fixed disks.
        jbe doneParam ; The requested drive does exist.

                   ; If here, the requested drive does not exist.
        mov cl,dl  ; Save number of drives.
        StringOut tooManyMes ; Show message '...last drive is'

        dec cl      ; Drive are numbered 0-6 to the user;
                    ;  and numbered 1-7 internally.
        add cl,'0'  ; Make drive number into ascii.
        mov dl,cl   ; DOS function to output a single character, -
        mov ah,02h  ;  (in the dl register).
        int 21h     ; Call DOS.
        jmp exitOut ; Exit.

ENDIF ; ### End of protect specific code.

;;
;;; USE DOS TO GET THE OLD VECTOR (address of handler) for interrupt 13h.
;;;  The vector is needed both to test if the Protect handler is already
;;;  there and to be able to call the old handler, for allowed disk
;;;  services (example: reads).
;;
doneParam:
        mov ax,3513h   ; DOS function to get vector 13h.
        int 21h        ; Call DOS.

;;
;;; Move the vector for the DOS interrupt 13h handler into storage
;;;  space.  The space is in the stay resident section, so the
;;;  DOS handler can be called from the Protect handler.
;;
        mov word ptr oldVector,bx    ; Store offset first,
        mov word ptr oldVector[2],es ;  then segment.  Order is important,
                                     ;  to be able to do a jump far later.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; TEST IF NEW HANDLER HAS ALREADY BEEN INSTALLED.  See
;;;  note with label magicSize, above.  The built in string
;;;  comparison instructions are used.
;;
        mov di,bx ; Load destination string address offset register; -
                  ;  (No need to load destination segment register,
                  ;  it is es, which was is already loaded, from above.)
        lea si,protINT13handler ; Load source string offset register;
                                ;  (segment is ds).
        mov cx,magicSize ; Load string length.
        cld ; Clear direction flag: string operation will autoincrement.
        repe cmpsb   ; Repeat string comparison while strings are equal.
        jz alreadyLoaded ; If the end of the string is reached with all
                         ;  elements equal, this handler has already been
                         ;  loaded.

IFDEF MAKING_UNPROT ; ### Only if making protect.

        StringOut protNotOnMes
        jmp exitOut

ELSE ; ### MAKING_PROTECT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; LOAD NEW INTERRUPT (protection): Use DOS to set the Protect vector
;;;  (address of handler) for interrupt 13h.  The Protect handler is
;;;  in the stay resident code.
;;
        lea dx,protINT13handler  ; Load vector offset for Protect
                                 ;  interrupt 13 handler into dx.
        mov ax,2513h  ; DOS function to set vector 13h.
        int 21h       ; Call DOS.

;;
;;; Show protection loaded message and list protected disks.
;;
        StringOut loadingMes ; Print protection on message.
        mov bh,protStatus    ; Get ready to list protected disks.
        call ReportProt      ; Call function to list protected disks.

;;
;;; Terminate and stay resident.  The DOS function will want to know the
;;;  first available location after resident code in *paragraphs*.
;;; There are 16 bytes to a paragraph.  Right shifting 4 times will
;;;  divide the byte count generated by the assembler into paragraphs.
;;
        lea dx,endResident ; Load end of resident byte offset.
        mov cx,0004h       ; Prepare CS:CL (count) register for right shift 4.
        shr dx,cl  ; Compute number of paragraphs by division.
        inc dx     ; Increment number of paragraphs, to take care of round off.
        mov ax,3100h  ; DOS function to terminate but stay resident.
        int 21h    ; Call DOS.

ENDIF ; ### Of If making Protect.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; THE PROTECT HANDLER IS ALREADY LOADED.  If there are no parameters,
;;;  report the protected disks, then exit.  If there are parameters,
;;;  (a specific disk) added the requested disk to the protected list.
;;;  For either function, the current protection status is needed.
;;; Remember: at this point there are two copies of the PROTECT interrupt
;;;  13h handler in memory; the one that was there (loaded previously,
;;;  and just found), and a second one loaded by running protect
;;;  again.  The second copy will be ignored; it is redundant (and
;;;  its storage will be given back when the second copy of protect
;;;  does a normal exit).  When the protection status is checked or
;;;  changed, the *old* copy of the interrupt handler must be used.
;;
alreadyLoaded:
        StringOut wasHereMes ; Show protection was loaded message.

IFDEF MAKING_UNPROT ; ### Turn protection off.

        mov byte ptr es:[bx-protStatusOffset],00h ; Turn off protection.
        mov al,00h

ELSE ; ### MAKING_PROTECT

        mov al,es:[bx-protStatusOffset]  ; Get the protection status from
                                         ;  the copy of protect being used.

        cmp thereIsParam,00h  ; If there are no parameters,
        je reportFromAlready  ;  just report, then exit.

        mov cl,protStatus ; Disk to be added to protection status,
                          ;  (was stored in *new* copy of PROTECT).
        or al,cl          ; Add disk to the list of protected disks.
        mov es:[bx-protStatusOffset],al ; Put the new protection status
                                        ;  back into the copy of Protect
                                        ;  being used.

ENDIF ; ### 

reportFromAlready:
        mov bh,al       ; Move protection status into bh.
        call ReportProt ; Call function to list protected disks.

exitOut:
        mov ax,4c00h  ; DOS function for normal exit.
        int 21h       ; Call DOS.

Main    ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
ReportProt PROC NEAR
;;
;;; SUBROUTINE TO REPORT PROTECTION STATUS:
;;; This subroutine will expect the bh register to contain the
;;;  the current protection status.
;;; Nothing is returned.
;;; No attempt is made to preserve register contents, except for
;;;  segment registers.
;;
        StringOut listHeaderMes ; Announce list.

        cmp bh,00h       ; Test if protection has been turned off;
        je noneProtected ;  if so, jump to none protected message.

        cmp bh,0ffh;    ; Test if all fixed disks are protected;
        je allProtected ;  if so, jump to all protected message.

;;
;;; Check each potential disk.  DOS only allows 2; but for future
;;;  expansion, this program allows up to 7, if they exist.
;;;  The existence of a fixed disk is not checked here.  Since disks
;;;  are checked before being protected, it is assumed that if a disk
;;;  is protected, it exists.
;;
        sub cx,cx  ; Clear the count register.
        mov cl,07h ; Count down 7 drives (6-0).
topOfCheckLoop:
        mov bl,80h ; This bit will be shifted into bl,
        rol bl,cl  ;  <drive number> times, to match the protStatus
                   ;  bit for this fixed drive.

        test bh,bl   ; If this disk is not protected,
        jz loopAgain ;  the ZF flag is now set.

        mov dl,cl   ; This disk is protected,
        add dl,'0'  ;  output as an ascii number,
        dec dl      ;   in (0-6).
        mov ah,02h  ; DOS function to output a single character.
        int 21h     ; Call DOS.

        mov dl,' '  ; Output a trailing space,
        int 21h     ;  to be ready for the next disk.

loopAgain:
        loop topOfCheckLoop  ; Single instruction to decrement cl,
                             ;  test it for not zero, and if so, go
                             ;  back to the top of the loop.

        jmp retRProt ; Jump over below messages to the return statement.

allProtected:
        StringOut allProtMes ; Show all disks protected message.
        jmp retRProt         ; Jump to the return.

noneProtected:
        StringOut noneProtMes ; Show no disks protected message.

;;
;;; Return from subroutine Report Protection.
;;
retRProt:
        ret

ReportProt ENDP


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;

IFDEF MAKING_PROTECT ; ### Only called by protect, not unprot

FindParam PROC NEAR
;;
;;; SUBROUTINE TO FIND THE PARAMETERS, if any.  The only acceptable
;;;  parameter list is white space (spaces and tabs), followed by
;;;  an integer between 0 and 6; or A to protect all drives.  
;;;  If there is a parameter, protection will be added for that disk.
;;;
;;; NOTE: The user refers to the drives as 0-6; they are represented
;;;  internally as 1-7.
;;;
;;; This subroutine will expect: The cs & ds registers both point to
;;;  the beginning of the segment this code is in; and the
;;;  es register points to the beginning of the PSP.
;;; No attempt is made to preserve register contents, except for
;;;  segment registers.
;;; The al & bl registers will contain the results: if al is 0, there
;;;  are no parameters.  If al is 1, there was a parameter (in bl); if
;;;  al is 2, the parameters were invalid.  (bl will contain ff if 
;;;  parameter was A.)
;;;
;;; A string of white space with nothing following is recognized as no
;;;  parameters; also trailing white space after a valid parameter
;;;  is ignored.
;;
        sub cx,cx  ; Clear count register.

        mov bx,0080h    ; Load length (in bytes) of the parameter string
        mov cl,es:[bx]  ;  into the string count register.
        mov bx,cx       ; Save the count, for later use.

        cmp cl,00h ; If the length of the parameter string is 0,
        je noParm  ;  there are no parameters.

;;
;;; Convert tabs to spaces in the parameter string.
;;
        mov di,0081h ; Load the string function offset register to
                     ;  be the beginning of the parameters.
        mov al,09h   ; Character to search for (tab).
        cld          ; Clear direction flag, so string operation will increment.

convertTabsLoop:
        repne scasb    ; Scan to the first non-tab, or end of string.
        jne scanSpaces ; Last character wasn't tab, end of string was found.

        mov byte ptr es:[di-1],' ' ; Change the tab to a space.

        cmp cx,0000h        ; If there are more characters in the string,
        jne convertTabsLoop ;  then keep looking.

;;
;;; Scan over white space to find parameter.
;;
scanSpaces:
        mov cx,bx     ; Restore the string length (count).
        mov di,0081h  ; Restore the beginning of string pointer.

        mov al,' '   ; Character to search for (space).
        cld          ; Make sure direction flag is clear (see above).
        repe scasb   ; Scan to the first non-space.

        je noParm   ; If last character was space, no parameters.

        mov bl,es:[di-1] ; Save the first non-space in bl; if the parameters
                         ;  are okay, it is the drive number.

        cmp cx,0000h ; If there no characters left, everything is okay,
        je validList ;  otherwise, look for trailing white space.

        repe scasb       ; Scan over trailing characters. If any aren't
        jne invalidParam ;  white space, there is an error in the parameters.

;;
;;; If here, then the list is: <white space><single character>[<white space>]
;;;  Now verify the character is an integer between 0 and 6; or A.
;;
validList:
        cmp bl,'A'  ; Check for capital A.
        je paramIsA
        cmp bl,'a'  ; Check for small a.
        je paramIsA

;;
;;; If here, the paramater is not an A.
;;
        sub bl,'0'       ; Convert from ASCII to an integer.
        jb invalidParam  ; If below zero, there is an error.
        cmp bl,06h       ; Test for parameter too big.
        ja invalidParam  ; Parameter is too big.

;;
;;; If here, the parameter is a valid number.
;;
        inc bl ; The user refers to the drives as 0-6,
               ;  but they are represented internally as 1-7.

        mov al,01h    ; Tell caller there are parameters,
        jmp retFParam ;  then return.

;;
;;; Set up return values to protect all drives.
;;
paramIsA:
        mov bl,0ffh   ; Tell caller the parameter was A.
        mov al,01h    ; Tell caller there are parameters, 
        jmp retFParam ;  then return.

;;
;;; If here, there is a parameter list, but it invalid.
;;
invalidParam:
        mov al,02h    ; Tell caller parameters are invalid.
        jmp retFParam  ; Return.

;;
;;; If here, there are no parameters.
;;
noParm:
        sub al,al  ; Clear the al register (no parameters signal).

;;
;;; Return from subroutine "Find the parameters".
;;;
retFParam:
        ret

FindParam ENDP

ENDIF ; ### End of if making protect.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; MESSAGE STRING STORAGE AREA:
;;;  "$" marks end of string to the DOS string display function.
;;
invalidParamMes  DB 'Usage: protect [0-6 | a]$'
tooManyMes       DB 'Drive number too big; last drive is: $'
loadingMes       DB 'Loading Protection: $'
listHeaderMes    DB 'List of protected physical disks: $'
wasHereMes       DB 'Protection already loaded: $'
allProtMes       DB 'All.$'
noneProtMes      DB 'None.$'
protNotOnMes     DB 'Protect not loaded.$' 

;;
;;; Trailing information.  Necessary to produce a .com file with
;;;  some assemblers.
;;
Protect ENDS
        END go

