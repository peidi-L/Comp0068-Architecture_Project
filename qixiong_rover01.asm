#=== ROVER POWER CONTROLLER v1.0 ===
.data

title: .asciiz "=== ROVER POWER CONTROLLER v1.0 ===\n"
print_pdr: .asciiz "Enter power drain rate PDR (units/sec) [default 1]: "
print_mbc: .asciiz "Enter maximum battery capacity MBC [default 15]: "
print_ibc: .asciiz "Enter initial battery charge IBC [default 5]: "
print_config: .asciiz "\nConfiguration accepted. PDR = "
config_mbc: .asciiz ", MBC = "
config_ibc: .asciiz ", IBC = "
online_msg: .asciiz "\nRover online. Beginning telemetry.\n"

input_error: .asciiz "Error! Please enter a positive integer or press Enter. \n"
ibc_error: .asciiz "Initial battery charge should be less than maximum battery capacity.\n"

buf: .space 64


charge: .word 5
pdr: .word 1
mbc: .word 15
ibc: .word 5


.text
.globl main



main:
	#title
	li $v0, 4
	la $a0, title
	syscall
	
	#pdr
	la $a0, print_pdr
    	li $a1, 1
    	jal read_positive
    	sw $v0, pdr	
	
	#mbc
	la $a0, print_mbc
    	li $a1, 15
    	jal read_positive
    	sw $v0, mbc
	
	#ibc
	j read_ibc
	
	
	
	######
show_configuration:
	li $v0, 4
	la $a0, print_config
	syscall
	
	li $v0, 1
	lw $a0, pdr
	syscall
	
	li $v0, 4
	la $a0, config_mbc
	syscall
	
	li $v0, 1
	lw $a0, mbc
	syscall
	
	li $v0, 4
	la $a0, config_ibc
	syscall
	
	li $v0, 1
	lw $a0, ibc
	syscall
	
	li $v0, 4
	la $a0, online_msg
	syscall

	li $v0, 10
	syscall
	
	

     
      ######
read_ibc:
	la $a0, print_ibc
	li $a1, 5
	jal read_positive
	lw $t0, mbc
	bgt $v0, $t0, ibc_too_high
	sw $v0, ibc
	sw $v0, charge
	j show_configuration
	
ibc_too_high:
	li $v0,4
	la $a0, ibc_error
	syscall
	j read_ibc
	


    ##########
read_positive:
	move $t6, $a0
	move $t7, $a1
	
read_positive_recover:
	li $v0, 4
	move $a0, $t6
	syscall
	
	li $v0, 8
	la $a0, buf
	li $a1, 64
	syscall
	
	move $v0, $t7
	jr $ra
	
		
	
	
	
