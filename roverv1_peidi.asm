.data
heading_str: .asciiz "=== ROVER POWER CONTROLLER v1.0 ===\n"
welcome_str: .asciiz "Rover system started successfully!\n"
charge_str: .asciiz "Initial charge: "
maxcharge_str: .asciiz "Maximum capacity: "
drain_str: .asciiz "Power drain rate: "

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

    # to print initial charge
    li $v0, 4
    la $a0, charge_str
    syscall

    # to print maximum capacity
    li $v0, 4
    la $a0, maxcharge_str
    syscall

    # to print drain rate
    li $v0, 4
    la $a0, drain_str
    syscall

    # to print the welcome message
    li $v0, 4
    la $a0, welcome_str
    syscall

    # to exit
    addi $v0, $0, 10
    # putting service 10 into register v0
    # MARS defines 10 as exit
    # exit is prepared at this line of code, syscall performs it
    syscall
