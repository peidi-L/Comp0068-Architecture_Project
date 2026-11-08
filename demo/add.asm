.data
message: .asciiz "7 + 5 = "

.text
.globl main
main:
    li $t0, 7
    li $t1, 5
    add $t2, $t0, $t1

    li $v0, 4
    la $a0, message
    syscall

    li $v0, 1
    move $a0, $t2
    syscall

    li $v0, 10
    syscall
