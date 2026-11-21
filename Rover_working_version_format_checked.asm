.data
heading_str: .asciiz "=== ROVER POWER CONTROLLER v1.0 ===\n"
success_str: .asciiz "\nRover system started successfully!\n"
charge_str: .asciiz ", IBC = "
maxcharge_str: .asciiz ", MBC = "
drain_str: .asciiz "PDR = "

drain_prompt_str: .asciiz "Enter power drain rate PDR (units/sec) [default 1]: "
maxcharge_prompt_str: .asciiz "Enter maximum battery capacity MBC [default 15]: "
charge_prompt_str: .asciiz "Enter initial battery charge IBC [default 5]: "

config_str: .asciiz "\nConfiguration accepted. "
invalid_str: .asciiz "Invalid value. Enter a positive integer.\n"
range_str: .asciiz "IBC must not exceed MBC. Try again.\n"

buffer: .space 64

PDR: .word 1

MBC: .word 15

IBC: .word 5

charge: .word 0

command_prompt_str: .asciiz "\nCommand (C n | S n=solar | S=status | Q=quit): "
status_str: .asciiz "Current battery charge: "
goodbye_str: .asciiz "Rover controller stopped.\n"

command_buffer: .space 64

recharge_str:   .asciiz "Recharge accepted: +"
solar_str: .asciiz "Solar array aligned: +"
units_str:      .asciiz " units.\n"
invalid_command_str:    .asciiz "Invalid command. Use C n | S n | S | Q.\n"
cap_str:        .asciiz "Error, maximum battery capacity reached! Capped to the Max.\n"

.text
.globl main

main:

    addi $v0, $0, 4

    la $a0, heading_str

    syscall

    la $a0, drain_prompt_str

    li $a1, 1

    jal read_setting

    sw $v0, PDR

    la $a0, maxcharge_prompt_str
    li $a1, 15

    jal read_setting
    sw $v0, MBC

read_ibc:

    la $a0, charge_prompt_str
    li $a1, 5

    jal read_setting

    lw $t0, MBC

    bgt $v0, $t0, bad_ibc

    sw $v0, IBC

    sw $v0, charge
    j show_config

bad_ibc:
    li $v0, 4
    la $a0, range_str
    syscall

    j read_ibc

show_config:

    li $v0, 4
    la $a0, config_str
    syscall

    li $v0, 4
    la $a0, drain_str
    syscall

    li $v0, 1
    lw $a0, PDR
    syscall

    li $v0, 4
    la $a0, maxcharge_str
    syscall

    li $v0, 1
    lw $a0, MBC
    syscall

    li $v0, 4
    la $a0, charge_str
    syscall

    li $v0, 1
    lw $a0, charge
    syscall

    li $v0, 4
    la $a0, success_str
    syscall

    j command_loop

exit_program:

    addi $v0, $0, 10

    syscall

read_setting:
    addiu $sp, $sp, -12

    sw $ra, 8($sp)

    sw $s0, 4($sp)
    sw $s1, 0($sp)

    move $s0, $a0

    move $s1, $a1

input_again:
    li $v0, 4
    move $a0, $s0
    syscall

    li $v0, 8

    la $a0, buffer

    li $a1, 64

    syscall

    la $t0, buffer

    lb $t1, 0($t0)

    li $t2, 10

    beq $t1, $t2, use_default

    li $t3, 0

parse_loop:
    lb $t1, 0($t0)

    beq $t1, $zero, invalid_input

    li $t2, 10
    beq $t1, $t2, parse_done

    blt $t1, 48, invalid_input
    bgt $t1, 57, invalid_input

    addiu $t1, $t1, -48

    li $t4, 214748364

    bgtu $t3, $t4, invalid_input

    bne $t3, $t4, accumulate

    li $t5, 7
    bgtu $t1, $t5, invalid_input

accumulate:
    li $t4, 10
    multu $t3, $t4

    mflo $t3

    addu $t3, $t3, $t1

    addiu $t0, $t0, 1

    j parse_loop

parse_done:
    blez $t3, invalid_input

    move $v0, $t3

    j read_done

use_default:
    move $v0, $s1

    j read_done

invalid_input:
    li $v0, 4
    la $a0, invalid_str
    syscall

    j input_again

read_done:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)

    addiu $sp, $sp, 12

    jr $ra

command_loop:

    li $v0, 4
    la $a0, command_prompt_str
    syscall

    li $v0, 8
    la $a0, command_buffer
    li $a1, 64
    syscall

    la $t0, command_buffer
    lb $t1, 0($t0)

    li $t2, 67
    beq $t1, $t2, command_recharge

    li $t2, 83
    bne $t1, $t2, check_single_command
    lb $t3, 1($t0)
    li $t2, 32
    beq $t3, $t2, command_solar

check_single_command:

    lb $t3, 1($t0)
    li $t2, 10
    bne $t3, $t2, bad_command

    li $t2, 83
    beq $t1, $t2, show_status

    li $t2, 81
    beq $t1, $t2, quit_rover

bad_command:
    li $v0, 4
    la $a0, invalid_command_str
    syscall

    j command_loop

show_status:

    li $v0, 4
    la $a0, status_str
    syscall

    li $v0, 1
    lw $a0, charge
    syscall

    li $v0, 11
    li $a0, 10
    syscall

    j command_loop

quit_rover:

    li $v0, 4
    la $a0, goodbye_str
    syscall

    j exit_program

command_recharge:

    li $t7, 0

    j parse_command_number

command_solar:
    li $t7, 1

parse_command_number:
    la $t0, command_buffer

    lb $t1, 1($t0)
    li $t2, 32
    bne $t1, $t2, bad_command

    addiu $t0, $t0, 2
    li $t3, 0

recharge_parse_loop:
    lb $t1, 0($t0)

    beq $t1, $zero, bad_command
    li $t2, 10
    beq $t1, $t2, recharge_parse_done

    blt $t1, 48, bad_command
    bgt $t1, 57, bad_command

    addiu $t1, $t1, -48

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

    addiu $t0, $t0, 1
    j recharge_parse_loop

recharge_parse_done:

    blez $t3, bad_command

    move $a0, $t3
    bne $t7, $zero, handle_solar
    li $a1, 0

    jal recharge

    j command_loop

recharge:
    lw $t0, charge
    lw $t1, MBC

    subu $t2, $t1, $t0

    bgtu $a0, $t2, recharge_cap

    addu $t0, $t0, $a0
    sw $t0, charge

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

handle_solar:
    sll $a0, $a0, 1

    li $a1, 1

    jal recharge

    j command_loop
