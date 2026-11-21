.data
heading_str: .asciiz "=== ROVER POWER CONTROLLER v1.0 ===\n"
welcome_str: .asciiz "\nRover system started successfully!\n"
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

#Marina contribution
batteryfull: .asciiz "Error, maximum battery capacity reached! Capped to the Max.\n"
zerobattery: .asciiz "Error, charge level equal to or less than 0. Rover is offline!\n"
commandPrompt: .asciiz "Enter command (C/S/D/T/R/Q) \n"
offline: .word 0
offline_msg: .asciiz "Rover is offline. Perform a reset R to continue. \n"
traverse_str: .asciiz "Traverse executed: -"

#PTY part 8
reset_str: .asciiz "Systems reset. Rover back online.\n"

buffer: .space 64
# reserving 64 bytes in memory for the input string
# this includes space for the newline and the zero byte ending the string

# original rover levels
PDR: .word 1
# power drain rate
MBC: .word 15
# maximum battery capacity
IBC: .word 5
# initial battery charge
charge: .word 0
# this is given by IBC when the program starts

command_prompt_str: .asciiz "\nCommand (C n | S n=solar | D n=dock | S=status | Q=quit): "
status_str: .asciiz "\nCurrent battery charge: "
unknown_str: .asciiz "Unknown command. Try again.\n"
goodbye_str: .asciiz "Rover controller stopped.\n"

command_buffer: .space 64

# Stage 4: command interface
recharge_str:   .asciiz "Recharge accepted: +"
solar_str: .asciiz "Solar array aligned: +"
units_str:      .asciiz " units.\n"
invalid_command_str:    .asciiz "Invalid command. Use C n | S n | D n | S | Q.\n"
cap_str:        .asciiz "Error, maximum battery capacity reached! Capped to the Max.\n"

#step 6 Qixiong
dock_str: .asciiz "Docked at charging station: +"
#step 9 Qixiong
last_tick_ms: .word 0
elapsed_seconds: .word 0
time_prefix_str: .asciiz "[t="
colon_str: .asciiz ":"
telemetry_charge_str: .asciiz "] Charge: "
slash_str: .asciiz "/"
offline_suffix_str: .asciiz "  -- ROVER OFFLINE --"
newline_str: .asciiz "\n"
step9_prompt_str: .asciiz "Command (C n | S n | D n | T n | R | Q): "
line_open: .word 0
was_offline: .word 0

.text
.globl main

main:
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
    # jumping to read_setting and saving the return address in ra
    # when read_setting returns, v0 contains the selected number
    sw $v0, PDR
    # storing that number in memory at PDR before reading the next setting

    # to read the maximum battery capacity
    la $a0, maxcharge_prompt_str
    li $a1, 15
    # passing the prompt address and the default value 15
    jal read_setting
    sw $v0, MBC
    # storing the selected maximum capacity in memory

read_ibc:
    # to read the initial battery charge
    la $a0, charge_prompt_str
    li $a1, 5
    # passing the prompt address and the default value 5
    jal read_setting
    # v0 now contains the selected initial charge

    lw $t0, MBC
    # loading the accepted maximum capacity into t0
    bgt $v0, $t0, bad_ibc
    # jumping to bad_ibc if the initial charge is greater than the capacity

    sw $v0, IBC
    # saving the initial charge only after it passes the capacity check

     # initialise the current battery charge from IBC
    lw $t0, IBC
    sw $t0, charge
    j show_config
    # skipping the error message and going to the accepted settings

bad_ibc:
    li $v0, 4
    la $a0, range_str
    syscall
    # printing the message that IBC must not exceed MBC
    j read_ibc
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
    la $a0, welcome_str
    syscall
    
    jal init_timer #step 9 qixiong
    j command_loop
    # Contine to command prompt

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
    addiu $sp, $sp, -12
    # moving the stack pointer down by 12 bytes
    # this makes room for three saved registers, each using 4 bytes

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
    # if the first character is a newline, only Enter was pressed

    li $t3, 0
    # starting the number being calculated at zero

parse_loop:
    lb $t1, 0($t0)
    # reading the character at the current address

    beq $t1, $zero, invalid_input
    # a zero byte before the newline means the input may have been cut off
    # rejecting this stops a long input from being accepted using only its start

    li $t2, 10
    beq $t1, $t2, parse_done
    # a newline means all the entered characters have been checked

    blt $t1, 48, invalid_input
    bgt $t1, 57, invalid_input
    # the character codes for the digits 0 to 9 are 48 to 57
    # rejecting anything outside this range, including spaces and minus signs

    addiu $t1, $t1, -48
    # converting the character code into its digit value
    # for example the character 5 has code 53, so 53 minus 48 gives 5

    li $t4, 214748364
    # the largest positive signed 32-bit integer is 2147483647
    # checking before multiplying the current number by 10 and adding a digit
    bgtu $t3, $t4, invalid_input
    # if the current number is already above this limit, another digit is too much
    # bgtu compares the register values as unsigned numbers

    bne $t3, $t4, accumulate
    # if the number is below the limit, any digit from 0 to 9 is safe
    li $t5, 7
    bgtu $t1, $t5, invalid_input
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
    # going back to check that next character

parse_done:
    blez $t3, invalid_input
    # rejecting a result less than or equal to zero
    move $v0, $t3
    # putting the accepted number into the return-value register v0
    j read_done

use_default:
    move $v0, $s1
    # using the saved default number as the return value
    j read_done

invalid_input:
    li $v0, 4
    la $a0, invalid_str
    syscall
    # printing the invalid value message
    j input_again
    # asking for the same setting again

read_done:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    # restoring the register values saved at the start of the procedure
    addiu $sp, $sp, 12
    # moving the stack pointer back to where it was before the procedure
    jr $ra
    # returning to the instruction after the jal that called read_setting
    # v0 still contains the selected number for the caller to store




command_loop:
    # Print command prompt
    #step 9 qixiong
    j step9_read_start
	li $v0, 4
    la $a0, command_prompt_str
    syscall

    
    # Read a command string
    li $v0, 8
    la $a0, command_buffer
    li $a1, 64
    syscall

    #step 9 qixiong
step9_input_ready:    
    # Read the first character
    la $t0, command_buffer
    lb $t1, 0($t0)
    
    
   #offline guard: if offline and not R or Q, reject #Marina contribution
   lw $t5, offline
   beq $t5, $zero, offline_ok #if online proceed
   li $t2, 82
   beq $t1, $t2, offline_ok
   li $t2, 81                #Q
   beq $t1, $t2, offline_ok
   li $v0, 4
   la $a0, offline_msg
   syscall
   j command_loop
   
   offline_ok:
    # C = Recharge
    li $t2, 67
    beq $t1, $t2, command_recharge
    # C n has an argument, so its own parser checks the remaining characters

    #step 6 Qixiong
    li $t2, 68
    beq $t1, $t2, command_dock
    
    #T = Traverse #Marina Contribution  
    li $t2, 84
    bne $t1, $t2, not_t
    lb $t3, 1($t0)
    li $t2, 32
    beq $t3, $t2, command_traverse
    j bad_command
    
    not_t:
    # S followed by a space starts a solar command
    li $t2, 83
    bne $t1, $t2, check_single_command
    lb $t3, 1($t0)
    li $t2, 32
    beq $t3, $t2, command_solar
    # bare S continues below and keeps its existing status behaviour

check_single_command:
    # require one command character followed by a newline
    lb $t3, 1($t0)
    li $t2, 10
    bne $t3, $t2, unknown_command

    # S = status
    li $t2, 83
    beq $t1, $t2, show_status

    # Q = quit
    li $t2, 81
    beq $t1, $t2, command_quit
    
    # S= reset          pty part 8
    li $t2,82
    beq $t1,$t2,command_reset

unknown_command:
    # Unknown command
    li $v0, 4
    la $a0, unknown_str
    syscall

    j command_loop


show_status:
    # Print status message
    li $v0, 4
    la $a0, status_str
    syscall

    # Print current charge
    li $v0, 1
    lw $a0, charge
    syscall

    j command_loop


quit_rover:
    # Print goodbye message
    li $v0, 4
    la $a0, goodbye_str
    syscall

    # Exit program
    j exit_program
    # using the original exit instructions from roverv1_peidi.asm

command_reset:                     #pty part 8
lw $t0,IBC
sw $t0,charge
sw $zero,offline

li $v0,4
la $a0,reset_str
syscall

j command_loop

# ==================================
# Parse recharge command: C n
# ==================================

command_recharge:
    # Expected format: C followed by space and n
    li $t7, 0
    # zero marks a recharge command
    j parse_command_number


#step 6 Qixiong
command_dock:
    li $t7, 3
    j parse_command_number

command_solar:
    li $t7, 1
    j parse_command_number
    # one marks a solar command
    
command_traverse:
    li $t7, 2
    j parse_command_number

parse_command_number:
    la $t0, command_buffer

    lb $t1, 1($t0)
    li $t2, 32
    bne $t1, $t2, bad_command

    # Start reading number at position 2
    addiu $t0, $t0, 2
    li $t3, 0
    li $t6, 0

recharge_parse_loop:
    lb $t1, 0($t0)

    # reject a full command buffer without a newline
    beq $t1, $zero, bad_command
    li $t2, 10
    beq $t1, $t2, recharge_parse_done

    # Check ASCII digit range
    blt $t1, 48, bad_command
    bgt $t1, 57, bad_command

    addiu $t1, $t1, -48

    # Prevent signed 32-bit integer overflow
    li $t4, 214748364
    bgtu $t3, $t4, bad_command
    bne $t3, $t4, recharge_accumulate
    li $t5, 7
    bgtu $t1, $t5, bad_command

recharge_accumulate:
    li $t4, 10
    multu $t3, $t4
    mflo $t3
    addu $t3, $t3, $t1

    addiu $t6, $t6, 1
    addiu $t0, $t0, 1
    j recharge_parse_loop

recharge_parse_done:
    # Require at least one digit and positive n
    beq $t6, $zero, bad_command
    blez $t3, bad_command

#Marina contribution
    # Pass n in $a0
    move $a0, $t3
    li $t1, 2 #Marina Contribution
    beq $t7, $t1, dispatch_traverse #if t7==2 traverse 
    #step 6 Qixiong
    li $t2, 3
    beq $t7, $t2, handle_dock
    bne $t7, $zero, handle_solar
    li $a1, 0
    # zero selects the recharge message
    jal recharge

    j command_loop
    
 dispatch_traverse: #Marina Contribution
 jal handle_traverse #Marina Contribution
 j command_loop #Marina Contribution


# ==================================
# Quit command
# ==================================

command_quit:
    # Q must be followed by a newline
    la $t0, command_buffer
    lb $t1, 1($t0)

    li $t2, 10
    beq $t1, $t2, quit_rover

    j bad_command


# ==================================
# Invalid command
# ==================================

bad_command:
    li $v0, 4
    la $a0, invalid_command_str
    syscall

    j command_loop


# recharge
# Input: $a0 = positive recharge amount
# $a1 = 0 for recharge, 1 for solar
# Updates: charge
recharge:
    lw $t0, charge
    lw $t1, MBC

    # Available battery capacity
    subu $t2, $t1, $t0

    # Check if recharge exceeds capacity
    bgtu $a0, $t2, recharge_cap

    addu $t0, $t0, $a0
    sw $t0, charge

    # Print success message
    move $t3, $a0

    beq $a1, $zero, print_recharge_msg
    #step 6 Qixiong
    li $t4, 2
    beq $a1, $t4, print_dock_msg
    li $v0, 4
    la $a0, solar_str
    syscall
    j print_amount

#step 6 Qixiong
print_dock_msg:
    li $v0, 4
    la $a0, dock_str
    syscall
    j print_amount

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

recharge_cap:
    sw $t1, charge

    li $v0, 4
    la $a0, cap_str
    syscall

    jr $ra


# to increase charge by twice the solar command number
handle_solar:
    sll $a0, $a0, 1
    # shifting left by one multiplies n by two
    # a valid n is at most 2147483647, so 2*n fits in an unsigned 32-bit word
    # recharge checks the amount against available capacity with bgtu before adding

    li $a1, 1
    # one selects the solar message
    jal recharge

    j command_loop

#Marina Contribution  
#handle_traverse
#Input: $a0 = positive n
#Effect: charge = charge - 3n, clamped at 0
# if charge reaches 0, sets offline flag
handle_traverse:
lw $t0, charge
li $t1, 3
mul $t2, $a0, $t1
sub $t3, $t0, $t2
blez $t3, traverse_offline

sw $t3, charge
li $v0, 4
la $a0, traverse_str
syscall
li $v0, 1
move $a0, $t2
syscall
li $v0, 4
la $a0, units_str
syscall
jr $ra

traverse_offline:
sw $zero, charge
li $t4, 1
sw $t4, offline
li $v0, 4
la $a0, zerobattery
syscall
jr $ra

#step 6 qixiong
handle_dock:
    	sll $a0, $a0, 1
    	li $a1, 2
    	jal recharge
    	j command_loop

#step 9 qixiong Contribution
# Mission clock, keyboard polling and telemetry
# Assemble first then open Tools-> Keyboard and Display MMIO Simulator,then click run
# $t0 = where to store the next character
# $t6 = number of characters stored
# $t5 = 1 if the command is too long (exceeds)
init_timer:
	li $v0, 30
	syscall
	
	sw $a0, last_tick_ms
	sw $zero, elapsed_seconds
	
	jr $ra


#step 9 qixiong
step9_read_start:
	la $t0, command_buffer
	li $t6, 0
	li $t5, 0
	sb $zero, 0($t0)

#step 9 qixiong
step9_poll:
	li $t1, 0xFFFF0000
	lw $t2, 0($t1)
	andi $t2, $t2, 1
  	beq $t2, $zero, step9_no_key

    	lw $t3, 4($t1)
    	andi $t3, $t3, 255

    	li $t4, 10
    	beq $t3, $t4, step9_input_done

    	li $t4, 13
    	beq $t3, $t4, step9_poll
		li $t4, 8
		beq $t3, $t4, step9_backspace
		li $t4, 127
		beq $t3, $t4, step9_backspace

		lw $t4, line_open

		bne $t4, $zero, step9_store
		li $v0, 4
		la $a0, step9_prompt_str
		syscall
		li $t4, 1
		sw $t4, line_open

step9_store:
    	bne $t5, $zero, step9_poll
    	li $t4, 62
    	bgeu $t6, $t4, step9_too_long
    	# Reject the whole command if another character exceeds the limit.

    	sb $t3, 0($t0)
    	sb $zero, 1($t0)
    	addiu $t0, $t0, 1
    	addiu $t6, $t6, 1
    	li $v0, 11
    	move $a0, $t3
    	syscall

    	j step9_poll

#step 9 qixiong
step9_input_done:
    	beq $t6, $zero, step9_poll
		li $t4, 10
    	sb $t4, 0($t0)
    	addiu $t0, $t0, 1
    	sb $zero, 0($t0)
    
    	li $v0, 11
    	li $a0, 10
    	syscall
    	sw $zero, line_open
		bne $t5, $zero, bad_command
	
    	j step9_input_ready

#step 9 qixiong
step9_too_long:
    	li $t5, 1
    	j step9_poll

step9_backspace:
	beq $t6, $zero, step9_poll
	bne $t5, $zero, step9_poll
	addiu $t0, $t0, -1
	addiu $t6, $t6, -1
	sb $zero, 0($t0)

	li $v0, 4
	la $a0, newline_str
 	syscall
	la $a0, step9_prompt_str
	syscall
	la $a0, command_buffer
	syscall

	j step9_poll


#step9 qixiong
step9_no_key:
    	li $v0, 30
    	syscall
    	lw $t1, last_tick_ms
    	subu $t2, $a0, $t1
    	li $t3, 1000
    	bltu $t2, $t3, step9_sleep
    	
    	addu $t1, $t1, $t3
    	sw $t1, last_tick_ms    # Advance by exactly one second, retaining any remaining milliseconds.
    	
    	jal step9_tick
    	j step9_poll
    	
step9_sleep:
	li $v0, 32
	li $a0, 1
	syscall
	
	j step9_poll
	
	
#step 9 qixiong
# update time, reduce charge and print telemetry
# save $t0, $t5 and $t6 to keep the current input
# save $ra before calling step9_print_two_digits
# changes $t1-$t4, $a0, $v0, HI and LO
step9_tick:
	addiu $sp, $sp, -16
	sw $ra, 12($sp)
	sw $t0, 8($sp)
	sw $t5, 4($sp)
	sw $t6, 0($sp)
    
	lw $t1, elapsed_seconds
	addiu $t1, $t1, 1
	sw $t1, elapsed_seconds
	
	lw $t1, line_open
	beq $t1, $zero, step9_check_drain
	li $v0, 4
	la $a0, newline_str
	syscall

step9_check_drain:	
	lw $t1, offline
	bne $t1, $zero, step9_offline_tick
	lw $t1, was_offline
	sw $zero, was_offline
	bne $t1, $zero, step9_print_telemetry
	
	lw $t1, charge
	lw $t2, PDR
	bgtu $t1, $t2, step9_drain
	j step9_natural_offline


step9_drain:
	subu $t1, $t1, $t2
	sw $t1, charge
	j step9_print_telemetry
	
step9_natural_offline:
	sw $zero, charge
	li $t1, 1
	sw $t1, offline
	li $v0, 4
	la $a0, zerobattery
	syscall

step9_offline_tick:
	li $t1, 1
	sw $t1, was_offline
	
	
step9_print_telemetry:
	li $v0, 4
	la $a0, time_prefix_str
	syscall

	lw $t1, elapsed_seconds
	li $t2, 60
	divu $t1, $t2
	mflo $a0
    # lo = minutes
	jal step9_print_two_digits
	
	li $v0, 4
	la $a0, colon_str
	syscall

	lw $t1, elapsed_seconds
	li $t2, 60
	divu $t1, $t2
	mfhi $a0
    # hi = seconds left over
	jal step9_print_two_digits

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

	lw $t1, offline
	beq $t1, $zero, step9_reprint
	li $v0, 4
	la $a0, offline_suffix_str
	syscall
	
	
step9_reprint:
	li $v0, 4
	la $a0, newline_str
	syscall
    
	la $a0, step9_prompt_str
	syscall
	
    li $t1, 1
	sw $t1, line_open
	li $v0, 4
	la $a0, command_buffer
	syscall

	lw $t6, 0($sp)
	lw $t5, 4($sp)
	lw $t0, 8($sp)
	lw $ra, 12($sp)
	addiu $sp, $sp, 16
	
	jr $ra


#step 9 qixiong
# Input: $a0 = number to print, with a leading zero if it is below 10
step9_print_two_digits:
	move $t4, $a0
	li $t3, 10
	bgeu $t4, $t3, step9_two_digits_number
	li $v0, 11
	li $a0, 48
	syscall

step9_two_digits_number:
	li $v0, 1
	move $a0, $t4
	syscall
	jr $ra
