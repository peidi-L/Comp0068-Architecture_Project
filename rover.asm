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
beq $t1,$t4,inputMBC#If the values of t1 and t4 are equal, directly jump to "show result"
beq $t1,$zero,inputMBC#Check if the input is an empty character

add $s0,$zero,$zero#When it is confirmed that the user has entered a number, the default value will be cleared.

convert_loop:
lb $t1,0($t0)

beq $t1,$t4,checkPDR#Determine if there are still any numbers to stop the loop
beq $t1,$zero,checkPDR#After the PDR is read, the next task is to input the MBC

addi $t5,$zero,48#Test whether each character of t1 is less than 0
slt $t6,$t1,$t5#If each character of t1 is less than $t5, set $t6 to 1; otherwise, set it to 0.
bne $t6,$zero,invalidPDR#Branch if Not Equal

addi $t5,$zero,57#Test whether t1 is larger than 9
slt $t6,$t5,$t1
bne $t6,$zero,invalidPDR

addi $t1,$t1,-48#The character '1' is represented as 49 in ASCII. Here, the character is converted into a number

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
beq $t1,$zero,inputIBC

add $s1,$zero,$zero

convert_MBC:
lb $t1,0($t0)
beq $t1,$t4,checkMBC
beq $t1,$zero,checkMBC

addi $t5,$zero,48#check whether each character of MBC is less than 0
slt $t6,$t1,$t5
bne $t6,$zero,invalidMBC

addi $t5,$zero,57#check whether each character of MBC is larger than 9
slt $t6,$t5,$t1
bne $t6,$zero,invalidMBC

addi $t1,$t1,-48

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
beq $t1,$zero,checkIBC

add $s2,$zero,$zero

convert_IBC:
lb $t1,0($t0)
beq $t1,$t4,checkIBC
beq $t1,$zero,checkIBC

addi $t5,$zero,48
slt $t6,$t1,$t5
bne $t6,$zero,invalidIBC

addi $t5,$zero,57
slt $t6,$t5,$t1
bne $t6,$zero,invalidIBC

addi $t1,$t1,-48

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

addi $v0,$zero,10#exit
syscall

