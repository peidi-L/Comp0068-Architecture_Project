# ROVER POWER CONTROLLER -- complete MARS 4.5 version
#
# Assemble and run in MARS. Enter PDR, MBC and IBC in Run I/O.
# Then open Tools > Keyboard and Display MMIO Simulator, connect it to MIPS,
# and type commands in its Keyboard area. Prompts/results appear in Run I/O.
# The clock runs after configuration, so connect the tool before running when
# possible. PDR units are drained each elapsed second, including idle time.
#
# Commands (uppercase, exactly one space before a positive decimal n):
#   C n: add n; S n: add 2*n; D n: add 2*n; T n: consume 3*n.
#   R: restore IBC and skip the next tick's drain; Q: quit.
# Values must be 1..2147483647. Charge is clamped to 0..MBC.
# Only R and Q are accepted while offline. Enter can be LF, CR or CRLF.
# Backspace/Delete redraws the edited line because MARS Run I/O appends text.
# Explicit nop delay slots support either MARS delayed-branching setting.

.data
heading_str: .asciiz "=== ROVER POWER CONTROLLER v1.0 ===\n"
charge_str: .asciiz ", IBC = "
maxcharge_str: .asciiz ", MBC = "
drain_str: .asciiz "PDR = "

# messages asking for the starting values
drain_prompt_str: .asciiz "Enter power drain rate PDR (units/sec) [default 1]: "
maxcharge_prompt_str: .asciiz "Enter maximum battery capacity MBC [default 15]: "
charge_prompt_str: .asciiz "Enter initial battery charge IBC [default 5]: "

# messages for accepted settings and invalid input
config_str: .asciiz "\nConfiguration accepted. "
invalid_str: .asciiz "Invalid value. Enter a positive integer.\n"
range_str: .asciiz "IBC must not exceed MBC. Try again.\n"

buffer: .space 64
# reserving 64 bytes in memory for the input string
# this includes space for the newline and the zero byte ending the string

# original rover levels
.align 2
PDR: .word 1
# power drain rate
MBC: .word 15
# maximum battery capacity
IBC: .word 5
# initial battery charge
charge: .word 0
# this is given by IBC when the program starts

command_prompt_str: .asciiz "Command (C n | S n | D n | T n | R | Q): "
# no leading newline, because the line before the prompt always ends with one

command_buffer: .space 64

# Stage 4: command interface
recharge_str:   .asciiz "Recharge accepted: +"
solar_str: .asciiz "Solar array aligned: +"
units_str:      .asciiz " units.\n"
invalid_command_str: .asciiz "Invalid command. Use C n | S n | D n | T n | R | Q; n must be 1..2147483647.\n"
cap_str:        .asciiz "Error, maximum battery capacity reached! Capped to the Max.\n"

# stage 6 adds docking, which supplies twice the number entered
dock_str: .asciiz "Docked at charging station: +"

# stage 7 adds traversal and the offline state
traverse_str: .asciiz "Traverse executed: -"
offline_str: .asciiz "Error, charge level equal to or less than 0. Rover is offline!\n"

# stage 8 adds reset so an offline rover can recover
reset_str: .asciiz "Systems reset. Rover back online.\n"
reset_available_str: .asciiz "Rover is offline. Use R to reset or Q to quit.\n"

# stage 9 adds a clock, continuous input polling and telemetry
# enter the starting settings in Run I/O as before
# then connect Tools > Keyboard and Display MMIO Simulator for commands
time_prefix_str: .asciiz "[t="
# mission_tick ends the prompt line first when needed, so no newline here
colon_str: .asciiz ":"
telemetry_charge_str: .asciiz "] Charge: "
slash_str: .asciiz "/"
offline_suffix_str: .asciiz " -- ROVER OFFLINE --"
newline_str: .asciiz "\n"
.align 2
last_tick_ms: .word 0
mission_seconds: .word 0
clock_started: .word 0
dispatch_active: .word 0
line_length: .word 0
line_ready: .word 0
line_bad: .word 0
skip_drain: .word 0
line_open: .word 0
# 1 when Run I/O is on a prompt line; 0 after a completed output line

# the full version adds line editing and accepts either Enter format
online_str: .asciiz "\nRover online. Beginning telemetry.\n"
mission_end_str: .asciiz "Telemetry link closed. Mission session ended.\n"
.align 2
ignore_lf: .word 0

.text
.globl main

main:
    # Keep procedure stack frames aligned to eight bytes.
    li $t0, -8
    and $sp, $sp, $t0

    # to print the heading
    addi $v0, $0, 4
    # adding number four to zero which is in register zero
    # placing it in register v0 which is another name for register 2
    # the register v0 is used by MARS to identify which service syscall should request
    # service number 4 means print string
    # note that service 4 specifically reads the string's address from register a0

    la $a0, heading_str
    # putting the address of the message string into register a0

    syscall
    # executing the MARS service four
    # printing the string whose address is in a0


    # to read the power drain rate
    la $a0, drain_prompt_str
    # putting the address of the prompt into a0
    li $a1, 1
    # putting the default value 1 into a1
    # these are the arguments that read_setting will use

    jal read_setting
    nop
    # jumping to read_setting and saving the return address in ra
    # when read_setting returns, v0 contains the selected number
    sw $v0, PDR
    # storing that number in memory at PDR before reading the next setting

    # to read the maximum battery capacity
    la $a0, maxcharge_prompt_str
    li $a1, 15
    # passing the prompt address and the default value 15
    jal read_setting
    nop
    sw $v0, MBC
    # storing the selected maximum capacity in memory

read_ibc:
    # to read the initial battery charge
    la $a0, charge_prompt_str
    li $a1, 5
    # passing the prompt address and the default value 5
    jal read_setting
    nop
    # v0 now contains the selected initial charge

    lw $t0, MBC
    # loading the accepted maximum capacity into t0
    bgt $v0, $t0, bad_ibc
    nop
    # jumping to bad_ibc if the initial charge is greater than the capacity

    sw $v0, IBC
    # saving the initial charge only after it passes the capacity check

     # initialise the current battery charge from IBC
    lw $t0, IBC
    sw $t0, charge
    j show_config
    nop
    # skipping the error message and going to the accepted settings

bad_ibc:
    li $v0, 4
    la $a0, range_str
    syscall
    # printing the message that IBC must not exceed MBC
    j read_ibc
    nop
    # asking for IBC again without asking for PDR and MBC again

show_config:
    # to print the accepted configuration
    li $v0, 4
    la $a0, config_str
    syscall

    # to print drain rate
    li $v0, 4
    la $a0, drain_str
    syscall

    li $v0, 1
    lw $a0, PDR
    syscall

    # to print maximum capacity
    li $v0, 4
    la $a0, maxcharge_str
    syscall

    li $v0, 1
    lw $a0, MBC
    syscall

    # to print initial charge
    li $v0, 4
    la $a0, charge_str
    syscall

    li $v0, 1
    lw $a0, charge
    syscall

    # to print the welcome message
    li $v0, 4
    la $a0, online_str
    # using the telemetry welcome message now that the clock has been added
    syscall


    j command_loop
    nop
    # Continue to the command interface.

exit_program:
    # to exit
    addi $v0, $0, 10
    # putting service 10 into register v0
    # MARS defines 10 as exit
    # exit is prepared at this line of code, syscall performs it
    syscall


# to read one setting and return a positive integer
# a0 contains the address of the prompt before calling this procedure
# a1 contains the default number before calling this procedure
# v0 contains the selected number when the procedure returns
read_setting:
    addiu $sp, $sp, -16
    # reserve an aligned frame for ra, s0 and s1 (plus padding)

    sw $ra, 8($sp)
    # saving the return address so it can be restored before returning
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    # saving the previous contents of s0 and s1 before using them

    move $s0, $a0
    # copying the prompt address into s0
    move $s1, $a1
    # copying the default value into s1
    # a0 and a1 will be reused for syscalls, so these copies keep the arguments

input_again:
    li $v0, 4
    move $a0, $s0
    syscall
    # printing the prompt whose address was saved in s0

    li $v0, 8
    # service number 8 means read a string
    la $a0, buffer
    # telling MARS where to store the characters that are entered
    li $a1, 64
    # telling service 8 the buffer size, including its ending zero byte
    # a1 now holds a size, while the default number is still saved in s1
    syscall

    la $t0, buffer
    # putting the address of the first character into t0
    lb $t1, 0($t0)
    # reading one byte from that address into t1
    # each character in these inputs uses one byte

    li $t2, 10
    # 10 is the character code for a newline
    beq $t1, $t2, use_default
    nop
    # if the first character is a newline, only Enter was pressed

    li $t3, 0
    # starting the number being calculated at zero

parse_loop:
    lb $t1, 0($t0)
    # reading the character at the current address

    beq $t1, $zero, invalid_input
    nop
    # a zero byte before the newline means the input may have been cut off
    # rejecting this stops a long input from being accepted using only its start

    li $t2, 10
    beq $t1, $t2, parse_done
    nop
    # a newline means all the entered characters have been checked

    blt $t1, 48, invalid_input
    nop
    bgt $t1, 57, invalid_input
    nop
    # the character codes for the digits 0 to 9 are 48 to 57
    # rejecting anything outside this range, including spaces and minus signs

    addiu $t1, $t1, -48
    # converting the character code into its digit value
    # for example the character 5 has code 53, so 53 minus 48 gives 5

    li $t4, 214748364
    # the largest positive signed 32-bit integer is 2147483647
    # checking before multiplying the current number by 10 and adding a digit
    bgtu $t3, $t4, invalid_input
    nop
    # if the current number is already above this limit, another digit is too much
    # bgtu compares the register values as unsigned numbers

    bne $t3, $t4, accumulate
    nop
    # if the number is below the limit, any digit from 0 to 9 is safe
    li $t5, 7
    bgtu $t1, $t5, invalid_input
    nop
    # if the number equals 214748364, the final digit must be at most 7

accumulate:
    li $t4, 10
    multu $t3, $t4
    # multiplying the number calculated so far by 10
    # multu puts its product in the hi and lo registers
    mflo $t3
    # copying the lower 32 bits of the product from lo into t3
    # the earlier checks make sure the result will fit
    addu $t3, $t3, $t1
    # adding the new digit to the number
    # for example, if t3 was 12 and the next digit is 3, 12 times 10 plus 3 is 123

    addiu $t0, $t0, 1
    # moving the address forward by one byte to the next character
    j parse_loop
    nop
    # going back to check that next character

parse_done:
    blez $t3, invalid_input
    nop
    # rejecting a result less than or equal to zero
    move $v0, $t3
    # putting the accepted number into the return-value register v0
    j read_done
    nop

use_default:
    move $v0, $s1
    # using the saved default number as the return value
    j read_done
    nop

invalid_input:
    li $v0, 4
    la $a0, invalid_str
    syscall
    # printing the invalid value message
    j input_again
    nop
    # asking for the same setting again

read_done:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    # restoring the register values saved at the start of the procedure
    addiu $sp, $sp, 16
    # moving the stack pointer back to where it was before the procedure
    jr $ra
    nop
    # returning to the instruction after the jal that called read_setting
    # v0 still contains the selected number for the caller to store




command_loop:
    lw $t0, dispatch_active
    bne $t0, $zero, timed_dispatch_done
    nop
    # old command handlers still return here after finishing their work
    # during command dispatch this returns to the polling loop
    lw $t0, clock_started
    bne $t0, $zero, clock_is_ready
    nop
    jal start_clock
    nop

clock_is_ready:
    # Print command prompt
    li $v0, 4
    la $a0, command_prompt_str
    syscall
    li $t0, 1
    sw $t0, line_open
    j timed_read_command
    nop

dispatch_ready_command:
    lw $t0, line_bad
    bne $t0, $zero, bad_command
    nop
    # a whole line is rejected if it did not fit in the command buffer

    # Read the first character
    la $t0, command_buffer
    lb $t1, 0($t0)

    # a zero charge means the rover cannot carry out normal commands
    lw $t2, charge
    bgtz $t2, online_commands
    nop
    li $t2, 81
    beq $t1, $t2, command_quit
    nop
    li $t2, 82
    beq $t1, $t2, command_reset
    nop
    # reset and quit are the two commands accepted while offline
    j reject_offline
    nop

online_commands:
    li $t2, 82
    beq $t1, $t2, command_reset
    nop
    li $t2, 84
    beq $t1, $t2, command_traverse
    nop
    # T n will subtract three times n from the charge

    # C = Recharge
    li $t2, 67
    beq $t1, $t2, command_recharge
    nop
    # C n has an argument, so its own parser checks the remaining characters

    # D n uses the same number parser as recharge and solar
    li $t2, 68
    beq $t1, $t2, command_dock
    nop

    # S n = solar align
    li $t2, 83
    beq $t1, $t2, command_solar
    nop
    # a bare S has no argument, so the shared number parser rejects it

check_single_command:
    # require one command character followed by a newline
    lb $t3, 1($t0)
    li $t2, 10
    bne $t3, $t2, unknown_command
    nop

    # Q = quit
    li $t2, 81
    beq $t1, $t2, command_quit
    nop

unknown_command:
    j bad_command
    nop


quit_rover:
    # Print goodbye message
    li $v0, 4
    la $a0, mission_end_str
    syscall

    # Exit program
    j exit_program
    nop
    # using the original exit instructions from roverv1_peidi.asm


# ==================================
# Parse recharge command: C n
# ==================================

command_recharge:
    # Expected format: C followed by space and n
    li $t7, 0
    # zero marks a recharge command
    j parse_command_number
    nop

command_solar:
    li $t7, 1
    # one marks a solar command

parse_command_number:
    la $t0, command_buffer

    lb $t1, 1($t0)
    li $t2, 32
    bne $t1, $t2, bad_command
    nop

    # Start reading number at position 2
    addiu $t0, $t0, 2
    li $t3, 0
    li $t6, 0

recharge_parse_loop:
    lb $t1, 0($t0)

    # reject a full command buffer without a newline
    beq $t1, $zero, bad_command
    nop
    li $t2, 10
    beq $t1, $t2, recharge_parse_done
    nop

    # Check ASCII digit range
    blt $t1, 48, bad_command
    nop
    bgt $t1, 57, bad_command
    nop

    addiu $t1, $t1, -48

    # Prevent signed 32-bit integer overflow
    li $t4, 214748364
    bgtu $t3, $t4, bad_command
    nop
    bne $t3, $t4, recharge_accumulate
    nop
    li $t5, 7
    bgtu $t1, $t5, bad_command
    nop

recharge_accumulate:
    li $t4, 10
    multu $t3, $t4
    mflo $t3
    addu $t3, $t3, $t1

    addiu $t6, $t6, 1
    addiu $t0, $t0, 1
    j recharge_parse_loop
    nop

recharge_parse_done:
    # Require at least one digit and positive n
    beq $t6, $zero, bad_command
    nop
    blez $t3, bad_command
    nop

    # Pass n in $a0
    move $a0, $t3
    li $t2, 3
    beq $t7, $t2, handle_traverse
    nop
    li $t2, 2
    beq $t7, $t2, handle_dock
    nop
    # two selects docking, while the earlier zero and one keep their meanings
    bne $t7, $zero, handle_solar
    nop
    li $a1, 0
    # zero selects the recharge message
    jal recharge
    nop

    j command_loop
    nop


# ==================================
# Quit command
# ==================================

command_quit:
    # Q must be followed by a newline
    la $t0, command_buffer
    lb $t1, 1($t0)

    li $t2, 10
    beq $t1, $t2, quit_rover
    nop

    j bad_command
    nop


# ==================================
# Invalid command
# ==================================

bad_command:
    lw $t0, charge
    beq $t0, $zero, reject_offline
    nop
    # an invalid command must not bypass the offline restriction
    li $v0, 4
    la $a0, invalid_command_str
    syscall

    j command_loop
    nop


# recharge
# Input: $a0 = positive recharge amount
# $a1 = 0 for recharge, 1 for solar, 2 for docking
# Updates: charge
recharge:
    lw $t0, charge
    lw $t1, MBC

    # Available battery capacity
    subu $t2, $t1, $t0

    # Check if recharge exceeds capacity
    bgtu $a0, $t2, recharge_cap
    nop

    addu $t0, $t0, $a0
    sw $t0, charge

    # Print success message
    move $t3, $a0

    beq $a1, $zero, print_recharge_msg
    nop
    li $t4, 2
    beq $a1, $t4, print_dock_msg
    nop
    # a1 can now also be two for the docking message
    li $v0, 4
    la $a0, solar_str
    syscall
    j print_amount
    nop

print_recharge_msg:
    li $v0, 4
    la $a0, recharge_str
    syscall

print_amount:
    li $v0, 1
    move $a0, $t3
    syscall

    li $v0, 4
    la $a0, units_str
    syscall

    jr $ra
    nop

recharge_cap:
    sw $t1, charge

    li $v0, 4
    la $a0, cap_str
    syscall

    jr $ra
    nop


# to increase charge by twice the solar command number
handle_solar:
    sll $a0, $a0, 1
    # shifting left by one multiplies n by two
    # a valid n is at most 2147483647, so 2*n fits in an unsigned 32-bit word
    # recharge checks the amount against available capacity with bgtu before adding

    li $a1, 1
    # one selects the solar message
    jal recharge
    nop

    j command_loop
    nop


command_dock:
    li $t7, 2
    # remembering that this number belongs to a docking command
    j parse_command_number
    nop

handle_dock:
    sll $a0, $a0, 1
    # multiplying n by two, just like the solar command
    # recharge compares this unsigned amount with the space left in the battery
    li $a1, 2
    jal recharge
    nop
    j command_loop
    nop

print_dock_msg:
    li $v0, 4
    la $a0, dock_str
    syscall
    j print_amount
    nop
    # keeping the earlier number and units printing code


command_traverse:
    li $t7, 3
    # three marks a traversal command for the shared number parser
    j parse_command_number
    nop

handle_traverse:
    li $t0, 3
    multu $a0, $t0
    mfhi $t1
    mflo $t2
    # the product can need more than 32 bits when n is very large
    # a nonzero hi means the cost is already greater than any allowed charge
    bne $t1, $zero, traverse_empty
    nop
    lw $t0, charge
    bgeu $t2, $t0, traverse_empty
    nop
    # using all the remaining charge also makes the rover offline

    subu $t0, $t0, $t2
    sw $t0, charge
    move $t3, $t2
    li $v0, 4
    la $a0, traverse_str
    syscall
    j print_traverse_amount
    nop

print_traverse_amount:
    li $v0, 1
    move $a0, $t3
    syscall
    li $v0, 4
    la $a0, units_str
    syscall
    j command_loop
    nop

traverse_empty:
    jal go_offline
    nop
    # printing only the offline error when traversal empties the battery
    j command_loop
    nop

go_offline:
    sw $zero, charge
    # clamping the charge to zero instead of allowing a negative value
    li $v0, 4
    la $a0, offline_str
    syscall
    jr $ra
    nop

reject_offline:
    li $v0, 4
    la $a0, reset_available_str
    # reset is now available, so the offline help explains how to recover
    syscall
    j command_loop
    nop


command_reset:
    la $t0, command_buffer
    lb $t1, 1($t0)
    li $t2, 10
    bne $t1, $t2, bad_command
    nop
    # R must be entered on its own, with no number or extra characters

perform_reset:
    lw $t0, IBC
    sw $t0, charge
    # restoring the initial charge selected during this run
    li $t1, 1
    sw $t1, skip_drain
    # exempt the next clock tick from natural drain
    li $v0, 4
    la $a0, reset_str
    syscall
    j command_loop
    nop


start_clock:
    li $v0, 30
    syscall
    # service 30 returns the low 32 bits of the time in a0
    sw $a0, last_tick_ms
    li $t0, 1
    sw $t0, clock_started
    jr $ra
    nop

timed_read_command:
timed_poll:
    jal poll_keyboard
    nop
    # Execute a completed line immediately, then resume polling the receiver.
    # This avoids leaving the one-character MMIO receiver unread until a tick.
    lw $t0, line_ready
    beq $t0, $zero, timed_clock
    nop
    jal timed_dispatch
    nop
    sw $zero, line_ready
    sw $zero, line_length
    sw $zero, line_bad
    la $t0, command_buffer
    sb $zero, 0($t0)

timed_clock:
    li $v0, 30
    syscall
    lw $t0, last_tick_ms
    subu $t1, $a0, $t0
    bltu $t1, 1000, timed_idle
    nop
    # subu also works when the low time word wraps around
    addiu $t0, $t0, 1000
    sw $t0, last_tick_ms
    # adding exactly one second keeps any fraction for the next tick
    jal mission_tick
    nop
    j timed_poll
    nop

timed_idle:
    li $v0, 32
    li $a0, 1
    syscall
    # pausing briefly so this loop does not constantly use the CPU
    j timed_poll
    nop

poll_keyboard:
    lw $t0, line_ready
    bne $t0, $zero, keyboard_done
    nop
    # Do not overwrite a completed line before it is dispatched.
    lui $t0, 0xffff
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beq $t1, $zero, keyboard_done
    nop
    lw $t1, 4($t0)
    andi $t1, $t1, 255
    # the receiver data register contains the character that was typed
    lw $t2, ignore_lf
    sw $zero, ignore_lf
    beq $t2, $zero, keyboard_character
    nop
    li $t2, 10
    beq $t1, $t2, keyboard_done
    nop
    # ignoring just the LF immediately following a CR

keyboard_character:
    li $t2, 13
    beq $t1, $t2, keyboard_carriage_return
    nop
    li $t2, 8
    beq $t1, $t2, keyboard_backspace
    nop
    li $t2, 127
    beq $t1, $t2, keyboard_backspace
    nop
    # handling both backspace character codes before storing ordinary input

keyboard_line_input:
    lw $t2, line_open
    bne $t2, $zero, keyboard_store
    nop
    li $v0, 4
    la $a0, command_prompt_str
    syscall
    li $t2, 1
    sw $t2, line_open

keyboard_store:
    beq $t1, $zero, keyboard_bad_line
    nop
    li $t2, 10
    beq $t1, $t2, keyboard_end_line
    nop
    lw $t2, line_bad
    bne $t2, $zero, keyboard_done
    nop
    # Once invalid, discard the rest of the line until Enter.
    lw $t2, line_length
    bgeu $t2, 62, keyboard_bad_line
    nop
    # leaving two bytes for the newline and the ending zero
    la $t3, command_buffer
    addu $t3, $t3, $t2
    sb $t1, 0($t3)
    sb $zero, 1($t3)
    # Keep partial input terminated so it can be redrawn after telemetry.
    addiu $t2, $t2, 1
    sw $t2, line_length
    li $v0, 11
    move $a0, $t1
    syscall
    # echoing the character in Run I/O while it is being collected
    jr $ra
    nop

keyboard_bad_line:
    li $t2, 1
    sw $t2, line_bad
    # discard extra characters until Enter, then reject the whole command
    jr $ra
    nop

keyboard_end_line:
    lw $t2, line_length
    la $t3, command_buffer
    addu $t3, $t3, $t2
    li $t1, 10
    sb $t1, 0($t3)
    sb $zero, 1($t3)
    # the earlier number parser expects a newline before the ending zero
    li $t1, 1
    sw $t1, line_ready
    li $v0, 11
    li $a0, 10
    syscall
    sw $zero, line_open

keyboard_done:
    jr $ra
    nop

mission_tick:
    addiu $sp, $sp, -8
    sw $ra, 0($sp)
    # save the return address before calling other procedures
    lw $t0, mission_seconds
    addiu $t0, $t0, 1
    sw $t0, mission_seconds
    # Commands have already run in the polling loop. A reset keeps its
    # drain exemption until this tick completes.
    lw $t0, line_open
    beq $t0, $zero, natural_drain
    nop
    li $v0, 4
    la $a0, newline_str
    syscall
    sw $zero, line_open

natural_drain:
    lw $t0, skip_drain
    bne $t0, $zero, tick_output
    nop
    lw $t0, charge
    beq $t0, $zero, tick_output
    nop
    # no more drain or repeated offline errors while the rover is offline
    lw $t1, PDR
    bgeu $t1, $t0, drain_empty
    nop
    subu $t0, $t0, $t1
    sw $t0, charge
    j tick_output
    nop

drain_empty:
    jal go_offline
    nop

tick_output:
    sw $zero, skip_drain
    jal output_telemetry
    nop
    li $v0, 4
    la $a0, command_prompt_str
    syscall
    # Restore both the prompt and any command interrupted by this tick.
    li $t0, 1
    sw $t0, line_open
    li $v0, 4
    la $a0, command_buffer
    syscall
    lw $ra, 0($sp)
    addiu $sp, $sp, 8
    jr $ra
    nop

timed_dispatch:
    addiu $sp, $sp, -8
    sw $ra, 0($sp)
    li $t0, 1
    sw $t0, dispatch_active
    j dispatch_ready_command
    nop
    # using the existing command handlers rather than copying their work

timed_dispatch_done:
    sw $zero, dispatch_active
    lw $ra, 0($sp)
    addiu $sp, $sp, 8
    jr $ra
    nop

output_telemetry:
    addiu $sp, $sp, -8
    sw $ra, 0($sp)
    li $v0, 4
    la $a0, time_prefix_str
    syscall
    lw $t0, mission_seconds
    li $t1, 60
    divu $t0, $t1
    mflo $a0
    jal print_two_digits
    nop
    li $v0, 4
    la $a0, colon_str
    syscall
    # dividing again because the printing procedure uses temporary registers
    lw $t0, mission_seconds
    li $t1, 60
    divu $t0, $t1
    mfhi $a0
    jal print_two_digits
    nop
    li $v0, 4
    la $a0, telemetry_charge_str
    syscall
    li $v0, 1
    lw $a0, charge
    syscall
    li $v0, 4
    la $a0, slash_str
    syscall
    li $v0, 1
    lw $a0, MBC
    syscall
    lw $t0, charge
    bne $t0, $zero, telemetry_newline
    nop
    li $v0, 4
    la $a0, offline_suffix_str
    syscall

telemetry_newline:
    li $v0, 4
    la $a0, newline_str
    syscall
    lw $ra, 0($sp)
    addiu $sp, $sp, 8
    jr $ra
    nop

print_two_digits:
    move $t4, $a0
    bgeu $t4, 10, print_time_number
    nop
    li $v0, 11
    li $a0, 48
    syscall
    # adding a leading zero when the minutes or seconds are below ten

print_time_number:
    li $v0, 1
    move $a0, $t4
    syscall
    jr $ra
    nop


keyboard_carriage_return:
    li $t2, 1
    sw $t2, ignore_lf
    li $t1, 10
    j keyboard_line_input
    nop
    # Treat CR as Enter, swallowing only an immediately following LF.

keyboard_backspace:
    lw $t2, line_length
    beq $t2, $zero, keyboard_done
    nop
    lw $t3, line_bad
    bne $t3, $zero, keyboard_done
    nop
    # once a line has overflowed it stays invalid until Enter
    addiu $t2, $t2, -1
    sw $t2, line_length
    la $t3, command_buffer
    addu $t3, $t3, $t2
    sb $zero, 0($t3)
    # MARS Run I/O appends characters; backspace control codes do not erase.
    # Start a fresh line and redraw the prompt with the shortened buffer.
    li $v0, 4
    la $a0, newline_str
    syscall
    la $a0, command_prompt_str
    syscall
    la $a0, command_buffer
    syscall
    li $t2, 1
    sw $t2, line_open
    jr $ra
    nop
