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

command_prompt_str: .asciiz "\nEnter command (S=status, Q=quit): "
status_str: .asciiz "\nCurrent battery charge: "
unknown_str: .asciiz "Unknown command. Try again.\n"
goodbye_str: .asciiz "Rover controller stopped.\n"

command_buffer: .space 16

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
    li $v0, 4
    la $a0, command_prompt_str
    syscall

    # Read a command string
    li $v0, 8
    la $a0, command_buffer
    li $a1, 16
    syscall

    # Read the first character
    la $t0, command_buffer
    lb $t1, 0($t0)

    # require one command character followed by a newline
    lb $t3, 1($t0)
    li $t2, 10
    bne $t3, $t2, unknown_command

    # S = status
    li $t2, 83
    beq $t1, $t2, show_status

    # Q = quit
    li $t2, 81
    beq $t1, $t2, quit_rover

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
