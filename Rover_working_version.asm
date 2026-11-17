.data
titleMSG:.asciiz "=== ROVER POWER CONTROLLER v1.0 ===\n"
enterPDR:.asciiz"Enter power drain rate PDR (units/sec) [default 1]: "
enterMBC:.asciiz"\nEnter maximum battery capacity MBC [default 15]: "
enterIBC:.asciiz"\nEnter initial battery charge IBC [default 5]: "
showPDR:.asciiz"\nConfiguration accepted. PDR = "
showMBC:.asciiz"\nMBC= "
showIBC:.asciiz"\nIBC= "
endLINE:.asciiz "\n"
onlineMSG:.asciiz "Rover online. Beginning telemetry.\n"
invalidMSG:.asciiz "Invalid value. Enter a positive integer.\n"
rangeMSG:.asciiz "IBC must not exceed MBC. Try again.\n"

input: .space 20
inputIBCbuffer: .space 20#Set up a separate buffer for the IBC.

# messages and input storage for the stage 5 command interface
command_prompt_str: .asciiz "\nCommand (C n | S n=solar | S=status | Q=quit): "
status_str: .asciiz "\nCurrent battery charge: "
unknown_str: .asciiz "Unknown command. Try again.\n"
goodbye_str: .asciiz "Rover controller stopped.\n"
command_buffer: .space 64
recharge_str:   .asciiz "Recharge accepted: +"
solar_str: .asciiz "Solar array aligned: +"
units_str:      .asciiz " units.\n"
invalid_command_str:    .asciiz "Invalid command. Use C n | S n | S | Q.\n"
cap_str:        .asciiz "Error, maximum battery capacity reached! Capped to the Max.\n"

# saved configuration and current battery charge
.align 2
PDR: .word 1
MBC: .word 15
IBC: .word 5
charge: .word 0

.text
.globl main
main:
#input title
addi $v0,$zero,4
la $a0,titleMSG#la:load address.Place the memory address of titleMSG into $a0
syscall

#input PDR
inputPDR:
addi $s0,$zero,1 #First, put the default value 1into s0

addi $v0,$zero,4#4:Print String
la $a0,enterPDR
syscall

addi $v0,$zero,8 #8:read string
la $a0,input #Put the address of the input into $a0, so the user's input content is also placed in the corresponding space of the input.
addi $a1,$zero,20#occupy a maximum of 20 bytes, including the null character at the end
syscall

la $t0,input
lb $t1,0($t0)#Read a byte from the memory address pointed to by $t0 + 0 and store it in $t1

addi $t4,$zero,10#The ASCII code for \ is decimal 10 (generated when the user presses Enter directly)
# 10 is the newline character from Enter; a literal backslash has code 92
beq $t1,$t4,inputMBC#If the values of t1 and t4 are equal, directly jump to "show result"
# reject a zero byte before the required newline
beq $t1,$zero,invalidPDR
beq $t1,$zero,inputMBC#Check if the input is an empty character

add $s0,$zero,$zero#When it is confirmed that the user has entered a number, the default value will be cleared.

convert_loop:
lb $t1,0($t0)

beq $t1,$t4,checkPDR#Determine if there are still any numbers to stop the loop
# reject a zero byte before the required newline
beq $t1,$zero,invalidPDR
beq $t1,$zero,checkPDR#After the PDR is read, the next task is to input the MBC

addi $t5,$zero,48#Test whether each character of t1 is less than 0
slt $t6,$t1,$t5#If each character of t1 is less than $t5, set $t6 to 1; otherwise, set it to 0.
bne $t6,$zero,invalidPDR#Branch if Not Equal

addi $t5,$zero,57#Test whether t1 is larger than 9
slt $t6,$t5,$t1
bne $t6,$zero,invalidPDR

addi $t1,$t1,-48#The character '1' is represented as 49 in ASCII. Here, the character is converted into a number

# check the signed 32-bit limit before multiplying the number by ten
# t4 still holds the newline code used by the original input loops
li $t7,214748364
bgtu $s0,$t7,invalidPDR
bne $s0,$t7,accumulatePDR
li $t8,7
bgtu $t1,$t8,invalidPDR
accumulatePDR:
sll $t2,$s0,3#Shift left by 3 positions is equivalent to multiplying by 2 raised to the power of 3
sll $t3,$s0,1
add $s0,$t2,$t3#t2 (8 times) + t3 (2 times) = 10 times
add $s0,$s0,$t1

addi $t0,$t0,1#Move to the next character and then return to the loop.What has changed is the address, not the numerical value
j convert_loop#jump back to convert_loop

invalidPDR:
addi $v0,$zero,4
la $a0,invalidMSG
syscall
j inputPDR

checkPDR:
beq $s0,$zero,invalidPDR#if the output is 000, also invalid
j inputMBC
#inputMBC
inputMBC:#Set a label, and redirect to this page after the PDR is completed
addi $s1,$zero,15#The default value of MBC is 15

addi $v0,$zero,4
la $a0,enterMBC
syscall

addi $v0,$zero,8
la $a0,input
addi $a1,$zero,20
syscall

la $t0,input#It can cover the content related to PDR in the input section
lb $t1,0($t0)
beq $t1,$t4,inputIBC
# reject a zero byte before the required newline
beq $t1,$zero,invalidMBC
beq $t1,$zero,inputIBC

add $s1,$zero,$zero

convert_MBC:
lb $t1,0($t0)
beq $t1,$t4,checkMBC
# reject a zero byte before the required newline
beq $t1,$zero,invalidMBC
beq $t1,$zero,checkMBC

addi $t5,$zero,48#check whether each character of MBC is less than 0
slt $t6,$t1,$t5
bne $t6,$zero,invalidMBC

addi $t5,$zero,57#check whether each character of MBC is larger than 9
slt $t6,$t5,$t1
bne $t6,$zero,invalidMBC

addi $t1,$t1,-48

# check the signed 32-bit limit before multiplying the number by ten
# t4 still holds the newline code used by the original input loops
li $t7,214748364
bgtu $s1,$t7,invalidMBC
bne $s1,$t7,accumulateMBC
li $t8,7
bgtu $t1,$t8,invalidMBC
accumulateMBC:
sll $t2,$s1,3
sll $t3,$s1,1
add $s1,$t2,$t3
add $s1,$s1,$t1

addi $t0,$t0,1
j convert_MBC

checkMBC:
beq $s1,$zero,invalidMBC
j inputIBC

invalidMBC:
addi $v0,$zero,4
la $a0,invalidMSG
syscall

j inputMBC

#inputIBC
inputIBC:
addi $s2,$zero,5#The default value of IBC is 5

addi $v0,$zero,4
la $a0,enterIBC
syscall

addi $v0,$zero,8
la $a0,inputIBCbuffer#Set up a separate buffer for the IBC.
addi $a1,$zero,20
syscall

la $t0,inputIBCbuffer#Set up a separate buffer for the IBC.
lb $t1,0($t0)

beq $t1,$t4,checkIBC
# reject a zero byte before the required newline
beq $t1,$zero,invalidIBC
beq $t1,$zero,checkIBC

add $s2,$zero,$zero

convert_IBC:
lb $t1,0($t0)
beq $t1,$t4,checkIBC
# reject a zero byte before the required newline
beq $t1,$zero,invalidIBC
beq $t1,$zero,checkIBC

addi $t5,$zero,48
slt $t6,$t1,$t5
bne $t6,$zero,invalidIBC

addi $t5,$zero,57
slt $t6,$t5,$t1
bne $t6,$zero,invalidIBC

addi $t1,$t1,-48

# check the signed 32-bit limit before multiplying the number by ten
# t4 still holds the newline code used by the original input loops
li $t7,214748364
bgtu $s2,$t7,invalidIBC
bne $s2,$t7,accumulateIBC
li $t8,7
bgtu $t1,$t8,invalidIBC
accumulateIBC:
sll $t2,$s2,3
sll $t3,$s2,1
add $s2,$t2,$t3
add $s2,$s2,$t1

addi $t0,$t0,1
j convert_IBC

checkIBC:
beq $s2,$zero,invalidIBC
slt $t6,$s1,$s2
bne $t6,$zero,invalidRangeIBC
j showtoPDR

invalidIBC:
addi $v0,$zero,4
la $a0,invalidMSG
syscall
j inputIBC

invalidRangeIBC:
addi $v0,$zero,4
la $a0,rangeMSG
syscall
j inputIBC

#showPDR
showtoPDR:
addi $v0,$zero,4
la $a0,showPDR
syscall

addi $v0,$zero,1#1:pirnt int
add $a0,$zero,$s0
syscall

#showMBC
showtoMBC:
addi $v0,$zero,4
la $a0,showMBC
syscall

addi $v0,$zero,1
add $a0,$zero,$s1
syscall

#showIBC
showtoIBC:
addi $v0,$zero,4
la $a0,showIBC
syscall

addi $v0,$zero,1
add $a0,$zero,$s2
syscall

#newline
addi $v0,$zero,4
la $a0,endLINE
syscall

#online message
addi $v0,$zero,4
la $a0,onlineMSG
syscall#No text content, just a line break
# this syscall prints onlineMSG; the command interface starts below

# copy the accepted register values into memory for the command handlers
sw $s0,PDR
sw $s1,MBC
sw $s2,IBC
sw $s2,charge
j command_loop

exit_program:
addi $v0,$zero,10#exit
syscall


# command handling added from rover_stage5.asm
command_loop:
    # Print command prompt
    li $v0, 4
    la $a0, command_prompt_str
    syscall

    # Read a command string
    li $v0, 8
    la $a0, command_buffer
    li $a1, 64
    syscall

    # Read the first character
    la $t0, command_buffer
    lb $t1, 0($t0)

    # C = Recharge
    li $t2, 67
    beq $t1, $t2, command_recharge
    # C n has an argument, so its own parser checks the remaining characters

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
    # using the exit instructions preserved from the original rover.asm


# ==================================
# Parse recharge command: C n
# ==================================

command_recharge:
    # Expected format: C followed by space and n
    jal parse_command_number
    beq $v0, $zero, bad_command

    # Pass n in $a0
    move $a0, $v0
    li $a1, 0
    # zero identifies recharge when selecting the output message
    jal recharge

    j command_loop


command_solar:
    # to read the number after S using the same parser as recharge
    jal parse_command_number
    beq $v0, $zero, bad_command

    move $a0, $v0
    j handle_solar


# to read the positive number already stored in command_buffer
# C n and S n use the same checks
# v0 returns the number if valid, or zero if invalid
parse_command_number:
    la $t0, command_buffer

    lb $t1, 1($t0)
    li $t2, 32
    bne $t1, $t2, number_invalid

    # Start reading number at position 2
    addiu $t0, $t0, 2
    li $t3, 0
    li $t6, 0

number_parse_loop:
    lb $t1, 0($t0)

    # reject a full command buffer without a newline
    beq $t1, $zero, number_invalid
    li $t2, 10
    beq $t1, $t2, number_parse_done

    # Check ASCII digit range
    blt $t1, 48, number_invalid
    bgt $t1, 57, number_invalid

    addiu $t1, $t1, -48

    # Prevent signed 32-bit integer overflow
    li $t4, 214748364
    bgtu $t3, $t4, number_invalid
    bne $t3, $t4, number_accumulate
    li $t5, 7
    bgtu $t1, $t5, number_invalid

number_accumulate:
    li $t4, 10
    multu $t3, $t4
    mflo $t3
    addu $t3, $t3, $t1

    addiu $t6, $t6, 1
    addiu $t0, $t0, 1
    j number_parse_loop

number_parse_done:
    # Require at least one digit and positive n
    beq $t6, $zero, number_invalid
    blez $t3, number_invalid

    move $v0, $t3
    jr $ra

number_invalid:
    move $v0, $zero
    jr $ra


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
    li $v0, 4
    la $a0, solar_str
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
