[org 100h]
jmp start
levels: db 5, 13, 6, 18, 10, 20, 11, 22, 4, 23
        db 3, 17, 8, 16, 2, 0, 7, 10, 24, 15
        db 19, 11, 18, 6, 14, 4, 13, 2, 20, 1

full_redraw db 1
board_dirty db 1
old_cursor db 0
paint_color db 0
moves dw 0
old_timer dd 0
timer_running db 0
time_expired db 0
end_state db 0
lose_text db 'TIME OVER!',0
final_text db 'YOU WIN! ALL LEVELS COMPLETE',0
restart_text db 'RESTART (ENTER / R)',0
end_title db 'COLOR CONNECT',0
ready_text db 'ARE YOU READY?',0
start_text db 'START (ENTER / SPACE)',0
tick_phase dw 0
elapsed_seconds dw 0
shown_seconds dw 0FFFFh
time_label db 'TIME',0
time_value db '00:00',0
number db '00000',0
title1 db 'COLOR',0
title2 db 'CONNECT',0
score_label db 'SCORE',0
level_label db 'LEVEL',0
pairs_label db 'PAIRS',0
moves_label db 'MOVES',0
pair_value db '0/5',0
level_value db '1/3',0

level       db 0
cursor      db 0
active      db 0          
last_color  db 0         
next_cell   db 0
endpoints   times 10 db 0 
board       times 25 db 0 ; 0=empty; colors: 1=yellow, 2=gold, 3=blue, 4=red, 5=green
lengths     db 0,0,0,0,0
completed   db 0,0,0,0,0
paths       times 125 db 0 ; 25 entries for each path
palette     db 0,14,6,9,12,10

dot_widths db 4,6,8,9,9,10,10,10,10,10,10,10,10,10,10,9,9,8,6,4
stroke_widths db 3,4,5,5,5,5,5,5,4,3
legend db 'ARROWS MOVE  SPACE SELECT',0
legend2 db 'U UNDO  R RESET  ESC EXIT',0
winmsg db 'SOLVED! N FOR NEXT LEVEL',0

start:
    push cs
    pop ds
    cld
    mov ax,000Dh
    int 10h
    call install_timer
    call load_level
    call ready_screen

main:
    cmp byte [time_expired],1
    je time_over
    call is_won
    cmp al,1
    jne check_clock
    cmp byte [level],2
    je all_complete
check_clock:
    call is_won
    cmp al,1
    je pause_clock
    mov byte [timer_running],1
    jmp clock_ready
pause_clock:
    mov byte [timer_running],0
clock_ready:
    call draw_screen
wait_key:
    cmp byte [time_expired],1
    je time_over
    ; Update only the time digits while waiting; never redraw the board.
    call draw_timer
    mov ah,01h
    int 16h
    jz wait_key
    xor ah,ah
    int 16h
    cmp byte [time_expired],1
    je time_over
    cmp al,27
    je quit
    cmp al,'r'
    je reset_level
    cmp al,'R'
    je reset_level
    cmp al,'u'
    je undo_key
    cmp al,'U'
    je undo_key
    cmp al,8
    je undo_key
    cmp al,' '
    je select_key
    cmp al,'n'
    je next_level
    cmp al,'N'
    je next_level
    cmp ah,48h
    je key_up
    cmp ah,50h
    je key_down
    cmp ah,4Bh
    je key_left
    cmp ah,4Dh
    je key_right
    jmp main

reset_level:
    call load_level
    jmp main
undo_key:
    call undo_step
    jmp main
select_key:
    call select_dot
    jmp main
next_level:
    call is_won
    cmp al,1
    jne main
    inc byte [level]
    cmp byte [level],3
    jb load_next
    mov byte [level],0
load_next:
    call load_level
    jmp main

key_up:
    mov al,[cursor]
    cmp al,5
    jb main
    sub al,5
    jmp attempt_move
key_down:
    mov al,[cursor]
    cmp al,20
    jae main
    add al,5
    jmp attempt_move
key_left:
    mov al,[cursor]
    xor ah,ah
    mov bl,5
    div bl
    cmp ah,0
    je main
    mov al,[cursor]
    dec al
    jmp attempt_move
key_right:
    mov al,[cursor]
    xor ah,ah
    mov bl,5
    div bl
    cmp ah,4
    je main
    mov al,[cursor]
    inc al

attempt_move:
    mov [next_cell],al
    cmp byte [active],0
    je cursor_only
    call draw_step
    jmp main
cursor_only:
    mov [cursor],al
    jmp main

; Reset paths and copy the selected level's ten endpoint indices.
load_level:
    cli
    mov byte [timer_running],0
    mov byte [time_expired],0
    mov byte [end_state],0
    mov word [tick_phase],0
    mov word [elapsed_seconds],0
    mov word [shown_seconds],0FFFFh
    sti
    mov byte [full_redraw],1
    mov byte [board_dirty],1
    mov word [moves],0
    push ax
    push bx
    push cx
    push si
    push di
    push es
    push ds
    pop es
    cld
    xor ax,ax
    mov di,board
    mov cx,25
    rep stosb
    mov di,paths
    mov cx,125
    rep stosb
    mov word [lengths],0
    mov word [lengths+2],0
    mov byte [lengths+4],0
    mov word [completed],0
    mov word [completed+2],0
    mov byte [completed+4],0
    mov byte [active],0
    mov byte [last_color],0
    mov byte [cursor],0
    xor ax,ax
    mov al,[level]
    mov bl,10
    mul bl
    mov si,levels
    add si,ax
    mov di,endpoints
    mov cx,10
    rep movsb
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; Select either endpoint of a new or existing color.
; If second endpoint selected, swap endpoint order in RAM.
select_dot:
    push ax
    push bx
    push cx
    push dx
    push si
    cmp byte [active],0
    jne select_end
    xor bx,bx
    mov cx,5
select_search:
    mov si,bx
    shl si,1
    mov al,[cursor]
    cmp al,[endpoints+si]
    je select_found
    cmp al,[endpoints+si+1]
    jne select_next
    cmp byte [lengths+bx],0
    jne select_found
    mov dl,[endpoints+si]
    mov [endpoints+si],al
    mov [endpoints+si+1],dl
select_found:
    cmp byte [lengths+bx],0
    je select_new
    ; Selecting an existing color resumes it at its last cell.
    mov ax,25
    mul bx
    mov si,ax
    xor ax,ax
    mov al,[lengths+bx]
    add si,ax
    dec si
    mov al,[paths+si]
    mov [cursor],al
    mov al,bl
    inc al
    mov [last_color],al
    cmp byte [completed+bx],0
    jne select_end
    mov [active],al
    jmp select_end
select_new:
    mov al,bl
    inc al
    mov [active],al
    mov [last_color],al
    mov byte [lengths+bx],1
    mov ax,25
    mul bx
    mov si,ax
    mov al,[cursor]
    mov [paths+si],al
    jmp select_end
select_next:
    inc bx
    loop select_search
select_end:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Extend active path to adjacent next_cell.
; Going back to the previous cell undoes the last segment.
draw_step:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    xor bx,bx
    mov bl,[active]
    dec bx                     
    mov ax,25
    mul bx
    mov si,ax                   
    xor cx,cx
    mov cl,[lengths+bx]
    cmp cx,1
    jbe check_target
    mov di,si
    add di,cx
    sub di,2
    mov al,[paths+di]
    cmp al,[next_cell]
    jne check_target
    call undo_step
    jmp step_end
check_target:
    xor ax,ax
    mov al,[next_cell]
    mov di,ax
    cmp byte [board+di],0
    jne step_end
    ; Cannot step onto an endpoint except this color's goal.
    xor di,di
check_endpoint:
    mov al,[next_cell]
    cmp al,[endpoints+di]
    jne check_next_endpoint
    mov ax,bx
    shl ax,1
    inc ax                      ; goal endpoint index
    cmp di,ax
    jne step_end
    jmp step_allowed
check_next_endpoint:
    inc di
    cmp di,10
    jb check_endpoint
step_allowed:
    mov byte [board_dirty],1
    inc word [moves]
    cmp cx,25
    jae step_end
    mov di,si
    add di,cx
    mov al,[next_cell]
    mov [paths+di],al
    inc byte [lengths+bx]
    xor ah,ah
    mov di,ax                   ; next cell index, not DX!
    mov al,[active]
    mov [board+di],al
    mov al,[next_cell]
    mov [cursor],al
    mov di,bx
    shl di,1
    inc di
    cmp al,[endpoints+di]
    jne step_end
    mov byte [completed+bx],1
    mov byte [active],0
step_end:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Undo last segment of active or most recently used path.
; Undo at length=1 cancels selection, allowing another color.
undo_step:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov al,[active]
    or al,al
    jne undo_have_color
    mov al,[last_color]
    or al,al
    je undo_end
undo_have_color:
    xor bx,bx
    mov bl,al
    dec bx
    xor cx,cx
    mov cl,[lengths+bx]
    or cx,cx
    jz undo_end
    mov ax,25
    mul bx
    mov si,ax
    add si,cx
    dec si
    xor dx,dx
    mov dl,[paths+si]
    mov di,dx
    ; The first endpoint was never added to board.
    cmp cx,1
    je undo_cancel
    call erase_tail
    mov byte [board_dirty],1
    mov byte [board+di],0
    mov byte [paths+si],0
    dec byte [lengths+bx]
    mov byte [completed+bx],0
    dec si
    mov al,[paths+si]
    mov [cursor],al
    mov al,bl
    inc al
    mov [active],al
    jmp undo_end
undo_cancel:
    mov byte [lengths+bx],0
    mov byte [active],0
    mov byte [last_color],0
undo_end:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

is_won:
    mov al,[completed]
    and al,[completed+1]
    and al,[completed+2]
    and al,[completed+3]
    and al,[completed+4]
    ret

; AL=cell, returns SI=center X and DI=center Y. Saves other registers.
cell_xy:
    push ax
    push bx
    xor ah,ah
    mov bl,5
    div bl
    push ax
    xor ah,ah
    mov bl,32
    mul bl
    add ax,20
    mov di,ax
    pop ax
    mov al,ah
    xor ah,ah
    mov bl,32
    mul bl
    add ax,96
    mov si,ax
    pop bx
    pop ax
    ret

; Rectangle: SI=x, DI=y, CX=width, DX=height, AL=color.
; BIOS write-pixel is demonstrated in chapter 12. All registers saved.
rectangle:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    mov bp,dx
    mov bx,cx
    mov dx,di
rectangle_row:
    push bx
    mov cx,si
rectangle_pixel:
    push ax
    push bx
    mov ah,0Ch
    xor bh,bh
    int 10h
    pop bx
    pop ax
    inc cx
    dec bx
    jnz rectangle_pixel
    pop bx
    inc dx
    dec bp
    jnz rectangle_row
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Rounded shape centered at SI,DI. BX=half-width table, CX=row count.
; AL=color. The table makes this simpler than a circle algorithm.
round_shape:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    mov bp,cx
    shr cx,1
    sub di,cx
round_row:
    xor cx,cx
    mov cl,[bx]
    push si
    sub si,cx
    shl cx,1
    mov dx,1
    call rectangle
    pop si
    inc di
    inc bx
    dec bp
    jnz round_row
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw every segment from its saved pair of adjacent cell positions.
draw_paths:
    xor bp,bp
path_color:
    mov ax,25
    mul bp
    mov bx,paths
    add bx,ax
    mov si,bp
    xor cx,cx
    mov cl,[lengths+si]
    cmp cx,0
    je path_next_color
path_cell:
    push cx
    push bx
    mov al,[bx]
    call cell_xy
    mov bx,bp
    mov al,[palette+bx+1]
    mov bx,stroke_widths
    mov cx,10
    call round_shape
    pop bx
    pop cx
    cmp cx,1
    je path_next_color
    push cx
    push bx
    ; Save the current center and calculate the next center.
    push si
    push di
    mov al,[bx+1]
    call cell_xy
    pop dx
    pop ax
    cmp si,ax
    je vertical_segment
    cmp si,ax
    jb horizontal_ordered
    xchg si,ax
horizontal_ordered:
    sub di,5
    mov cx,32
    mov dx,10
    jmp segment_ready
vertical_segment:
    cmp di,dx
    jb vertical_ordered
    xchg di,dx
vertical_ordered:
    sub si,5
    mov cx,10
    mov dx,32
segment_ready:
    mov bx,bp
    mov al,[palette+bx+1]
    call rectangle
    pop bx
    pop cx
    inc bx
    dec cx
    jmp path_cell
path_next_color:
    inc bp
    cmp bp,5
    jb path_color
    ret

; SI=string, DH=text row, DL=text column; BIOS text output in graphics.
print_text:
    mov ah,02h
    xor bh,bh
    int 10h
print_next:
    lodsb
    cmp al,0
    je print_done
    mov ah,0Eh
    mov bx,0007h
    int 10h
    jmp print_next
print_done:
    ret

draw_screen:
    cmp byte [full_redraw],1
    je fresh_screen
    ; Only erase the old white cursor; the board remains on screen.
    mov al,[old_cursor]
    mov byte [paint_color],0
    call draw_cursor
    jmp update_board
fresh_screen:
    mov ax,0600h
    xor bh,bh
    xor cx,cx
    mov dx,1827h
    int 10h
    mov byte [full_redraw],0
    call draw_grid
    jmp update_board

draw_grid:
    ; Square gray outline and faint grid on the black board.
    mov si,80
    mov di,4
    mov cx,160
    mov dx,1
    mov al,8
    call rectangle
    mov di,164
    call rectangle
    mov di,4
    mov cx,1
    mov dx,161
    call rectangle
    mov si,240
    call rectangle
    mov bp,1
    mov si,112
    mov di,36
 grid_line:
    push si
    mov si,80
    mov cx,160
    mov dx,1
    call rectangle
    pop si
    push di
    mov di,4
    mov cx,1
    mov dx,160
    call rectangle
    pop di
    add si,32
    add di,32
    inc bp
    cmp bp,5
    jb grid_line
    ret

update_board:
    cmp byte [board_dirty],0
    je board_ready
    call draw_paths
    xor bp,bp
 draw_dot:
    mov bx,bp
    mov al,[endpoints+bx]
    call cell_xy
    shr bx,1
    mov al,[palette+bx+1]
    mov bx,dot_widths
    mov cx,20
    call round_shape
    inc bp
    cmp bp,10
    jb draw_dot
    mov byte [board_dirty],0
board_ready:
    mov al,[cursor]
    mov [old_cursor],al
    mov byte [paint_color],15
    call draw_cursor
    call draw_hud
    mov si,legend
    mov dh,22
    mov dl,8
    call print_text
    mov si,legend2
    mov dh,23
    mov dl,8
    call print_text
    mov si,winmsg
    call is_won
    cmp al,1
    je status_ready
    mov si,blank_status
status_ready:
    mov dh,21
    mov dl,8
    call print_text
    ret

; Cursor corners never touch grid lines, dots, or paths.
draw_cursor:
    call cell_xy
    sub si,13
    sub di,13
    mov al,[paint_color]
    mov cx,5
    mov dx,1
    call rectangle
    add si,22
    call rectangle
    add di,26
    call rectangle
    sub si,22
    call rectangle
    sub di,26
    mov cx,1
    mov dx,5
    call rectangle
    add si,26
    call rectangle
    add di,22
    call rectangle
    sub si,26
    call rectangle
    ret

; Remove only the last segment before undo changes the path history.
; Preserve all registers because undo_step still needs its indices.
erase_tail:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push si
    mov al,[paths+si]
    call cell_xy
    mov bx,stroke_widths
    mov cx,10
    xor al,al
    call round_shape
    pop si
    mov al,[paths+si-1]
    push si
    call cell_xy
    mov ax,si
    mov dx,di
    pop si
    push ax
    push dx
    mov al,[paths+si]
    call cell_xy
    pop dx
    pop ax
    cmp si,ax
    je erase_vertical
    cmp si,ax
    jb erase_horizontal_ordered
    xchg si,ax
erase_horizontal_ordered:
    sub di,5
    mov cx,32
    mov dx,10
    jmp erase_ready
erase_vertical:
    cmp di,dx
    jb erase_vertical_ordered
    xchg di,dx
erase_vertical_ordered:
    sub si,5
    mov cx,10
    mov dx,32
erase_ready:
    xor al,al
    call rectangle
    ; Restore just the tiny grid crossing exposed by the removed segment.
    cmp cx,32
    jne erase_vertical_grid
    add si,16
    mov cx,1
    mov dx,10
    jmp erase_grid_ready
erase_vertical_grid:
    add di,16
    mov cx,10
    mov dx,1
erase_grid_ready:
    mov al,8
    call rectangle
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

blank_status db '                        ',0

; Convert AX to five decimal digits using DIV, as in chapter 6.
format_number:
    mov bx,10
    mov di,number+4
    mov cx,5
number_digit:
    xor dx,dx
    div bx
    add dl,'0'
    mov [di],dl
    dec di
    loop number_digit
    ret

draw_hud:
    mov si,title1
    mov dh,2
    mov dl,2
    call print_text
    mov si,title2
    mov dh,3
    mov dl,1
    call print_text
    mov si,score_label
    mov dh,7
    mov dl,2
    call print_text
    xor ax,ax
    mov al,[level]
    mov bx,500
    mul bx
    mov bp,ax
    xor bx,bx
    xor ax,ax
hud_count:
    add al,[completed+bx]
    inc bx
    cmp bx,5
    jb hud_count
    mov dl,al
    add dl,'0'
    mov [pair_value],dl
    mov bx,100
    mul bx
    add ax,bp
    call format_number
    mov si,number
    mov dh,8
    mov dl,2
    call print_text
    mov si,moves_label
    mov dh,11
    mov dl,2
    call print_text
    mov ax,[moves]
    call format_number
    mov si,number
    mov dh,12
    mov dl,2
    call print_text
    mov si,level_label
    mov dh,3
    mov dl,33
    call print_text
    mov al,[level]
    add al,'1'
    mov [level_value],al
    mov si,level_value
    mov dh,4
    mov dl,34
    call print_text
    mov si,time_label
    mov dh,11
    mov dl,33
    call print_text
    call draw_timer
    mov si,pairs_label
    mov dh,7
    mov dl,33
    call print_text
    mov si,pair_value
    mov dh,8
    mov dl,34
    call print_text
    ret

; Chapter 9.4 timer interrupt. Chain the BIOS handler so DOS time keeps working.
install_timer:
    push ax
    push es
    xor ax,ax
    mov es,ax
    cli
    mov ax,[es:8*4]
    mov [old_timer],ax
    mov ax,[es:8*4+2]
    mov [old_timer+2],ax
    mov word [es:8*4],timer_tick
    mov [es:8*4+2],cs
    sti
    pop es
    pop ax
    ret

timer_tick:
    ; No video or DOS calls here: only update our counters.
    push ax
    cmp byte [cs:timer_running],0
    je timer_chain
    add word [cs:tick_phase],10
    cmp word [cs:tick_phase],182
    jb timer_chain
    sub word [cs:tick_phase],182
    cmp word [cs:elapsed_seconds],30
    jae timer_chain
    inc word [cs:elapsed_seconds]
    cmp word [cs:elapsed_seconds],30
    jb timer_chain
    mov byte [cs:time_expired],1
    mov byte [cs:timer_running],0
timer_chain:
    pop ax
    jmp far [cs:old_timer]

; 30-second countdown. Draw only when the displayed second changes.
draw_timer:
    mov ax,30
    sub ax,[elapsed_seconds]
    cmp ax,[shown_seconds]
    je timer_display_done
    mov [shown_seconds],ax
    xor dx,dx
    mov bx,60
    div bx
    push dx
    mov bl,10
    div bl
    add al,'0'
    add ah,'0'
    mov [time_value],al
    mov [time_value+1],ah
    pop ax
    div bl
    add al,'0'
    add ah,'0'
    mov [time_value+3],al
    mov [time_value+4],ah
    mov si,time_value
    mov dh,12
    mov dl,33
    call print_text
timer_display_done:
    ret

restore_timer:
    push ax
    push es
    xor ax,ax
    mov es,ax
    cli
    mov ax,[old_timer]
    mov [es:8*4],ax
    mov ax,[old_timer+2]
    mov [es:8*4+2],ax
    sti
    pop es
    pop ax
    ret

; Welcome screen: the clock stays stopped until Start is activated.
ready_screen:
    mov byte [timer_running],0
    mov ax,0600h
    xor bh,bh
    xor cx,cx
    mov dx,1827h
    int 10h
    mov si,end_title
    mov dh,4
    mov dl,13
    call print_text
    mov si,ready_text
    mov dh,8
    mov dl,13
    call print_text
    call draw_button
    mov si,start_text
    mov dh,15
    mov dl,10
    call print_text
ready_wait:
    xor ah,ah
    int 16h
    cmp al,13
    je ready_done
    cmp al,' '
    je ready_done
    cmp al,27
    je quit
    jmp ready_wait
ready_done:
    ; load_level already marked the board for a fresh draw.
    ret

; Reused outline for the keyboard-operated Start and Restart buttons.
draw_button:
    mov al,11
    mov si,80
    mov di,112
    mov cx,160
    mov dx,1
    call rectangle
    mov di,136
    call rectangle
    mov di,112
    mov cx,1
    mov dx,25
    call rectangle
    mov si,240
    call rectangle
    ret

; End screens are entered once; no gameplay keys are processed here.
time_over:
    mov byte [end_state],1
    jmp show_end_screen
all_complete:
    mov byte [end_state],2
show_end_screen:
    mov byte [timer_running],0
    mov ax,0600h
    xor bh,bh
    xor cx,cx
    mov dx,1827h
    int 10h
    mov si,end_title
    mov dh,4
    mov dl,13
    call print_text
    cmp byte [end_state],2
    je show_final_win
    mov si,lose_text
    mov dh,8
    mov dl,15
    jmp end_message_ready
show_final_win:
    mov si,final_text
    mov dh,8
    mov dl,6
end_message_ready:
    call print_text
    ; A single outlined restart button. Enter or R activates it.
    mov al,11
    mov si,80
    mov di,112
    mov cx,160
    mov dx,1
    call rectangle
    mov di,136
    call rectangle
    mov di,112
    mov cx,1
    mov dx,25
    call rectangle
    mov si,240
    call rectangle
    call draw_button
    mov si,restart_text
    mov dh,15
    mov dl,11
    call print_text
end_wait:
    xor ah,ah
    int 16h
    cmp al,13
    je restart_game
    cmp al,'r'
    je restart_game
    cmp al,'R'
    je restart_game
    cmp al,27
    je quit
    jmp end_wait
restart_game:
    mov byte [level],0
    call load_level
    call ready_screen
    jmp main

quit:
    mov byte [timer_running],0
    call restore_timer
    mov ax,0003h
    int 10h
    mov ax,4C00h
    int 21h