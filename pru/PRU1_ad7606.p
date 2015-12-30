// *****************************************************************************/
// file:   PRU1_ad7606.p 
//
// brief:  PRU driver for ad7606.
//
//
//  (C) Copyright 2014
//
//  author     Guoqiang Xia
//
//  version    0.1     Created
// *****************************************************************************/
.setcallreg r16.w0
.origin 0
.entrypoint EntryDaq

#include "PRU_daq.hp"


EntryDaq:
// this is very important, clearing the STANDBY_INIT bit in the SYSCFG register.
   LBCO r0, C4, 4, 4
   CLR r0, r0, 4
   SBCO r0, C4, 4, 4      
//#ifdef AM33XX

    // Configure the block index register for PRU0 by setting c24_blk_index[7:0] and
    // c25_blk_index[7:0] field to 0x00 and 0x00, respectively.  This will make C24 point
    // to 0x00000000 (PRU0 DRAM) and C25 point to 0x00002000 (PRU1 DRAM).
//xia, this also works for PRU1, orginally coded for PRU0
    MOV       r0, 0x00000000
    MOV       r1, CTBIR_0
    ST32      r0, r1
   
//procedure for PRU1 to drive ad7606 in parallel byte mode.
//1) reset ad7606
//      set RST to high for 2us. which is r30_9 
//2) 

//init control lines.
//set RST to high, r30_9 to high
//set *cs to high, r30_11
//set *rd to high, r30_10
//set *cva to high, r30_8
    mov r30, 0xf00     

    lbco     r6, CONST_PRU1DRAM, 0, 4  
    
    mov r2,  PRUCTL
    // r0 is the counter
    lbbo   r0, r2, CTREG, 4

//  after 2us, set RST to low. 400/2e8=2e-6
    mov r3, 400
    add r1, r0, r3
//delay_2us:
    call delay
    clr r30.t9 
//RST is set to low, reset of ad7606 is done.     

    mov r4, 0
    mov r8, 0
//ring buffer from 8 to 8008 of PRURAM, PRURAM[0]: write reference, PRURAM[4]: read reference
    mov r10, 8008
    mov r11, 8
    mov r12, 8
    mov r13, 4008
    SBCO  r11, CONST_PRU0DRAM, 0, 4
    SBCO  r12, CONST_PRU0DRAM, 4, 4

//fixed rate 10kHz
//r6: rate control, r5: state, r0: last index, r1: next index
//r3: cycle count, r2: PRUCTL, r4: loop index
//r30  output
//r31  input,   t0~t7 byte
//r7, r8 data in
//r9 data in,  4 channles of 16 bits
//r10 the size of PRURAM for daq buffer , 8008 
//r11, write reference (from 2 to 2002). r12, read reference
//r13, half of r10, 4000+8

// r0 is the counter
    lbbo   r0, r2, CTREG, 4
     
// this loop should take 100us.
cvrt_loop:
//set cvrt to low
    clr r30.t8
    
//  after 2us, set cvrt to high. 200/2e8=1e-6
    mov r3, 400
    add r1, r0, r3
//delay_2us:
    call delay
//  set convert to high
    set r30.t8 

//delay 47us for convert to finish
    mov r3, 9400
    add r1, r0, r3
    call delay

//time taken: 2+47+1+8*6+2=100us
// take 49us to finish convert   
// should start read in data, in byte parallel mode, for 8 byte
// each byte take 6us, 6*8=48, so after 4 channels of data, have 2 us to spare 
// in this 6us, rd is set to low for 4us, after it is set to low for 2us, read in the byte as value, then set rd to high for 2us, loop 8 times 

// enable cs, then delay 1us to start read data
    clr r30.t11  
   
    add r1, r0, 200
    call delay

//  read data in
//set rd low for 3us, then read in data, after 1us set rd high for 2us, then loop for next byte, total 6us

//  r4 loop count
    mov r4, 0

read_word:
//set rd low   
    clr r30.t10
//delay 3us
    mov r3, 600
    add r1, r0, r3 
    call delay
// read high byte from r31.b0
    mov r7.b1, r31.b0 
//delay 1us
    add r1, r0, 200
    call delay

//set rd high    
    set r30.t10
//delay 2us
    mov r3, 400
    add r1, r0, r3
    call delay

//read low byte of the word, set rd low   
    clr r30.t10
//delay 3us
    mov r3, 600
    add r1, r0, r3 
    call delay
// read low byte from r31.b0
    mov r7.b0, r31.b0 
//delay 1us
    add r1, r0, 200
    call delay
    
//set rd to high for 2us
    set r30.t10
//delay 2us
    mov r3, 400
    add r1, r0, r3
    call delay
    
    qbeq is3, r4, 3
    qbeq is2, r4, 2
    qbeq is1, r4, 1     
//r4=0:  mov r8.w0,r7.w0
    mov r8.w0, r7.w0
    jmp while

//r4=1:  mov r8.w2, r7.w0
is1:
    mov r8.w2, r7.w0
    jmp while

//r4=2:  mov r9.w0,r7.w0
is2: 
    mov r9.w0, r7.w0
    jmp while   

//r4=3:  mov r9.w2, r7.w0
is3: 
    mov r9.w2, r7.w0

while:      
    add r4, r4,1 
    qbgt read_word, r4, 4

next:
// copy data into memory [1]
//8kB meomory for each PRU
//4 channels of 16 bit AD 
// copy r8 into [PRU0DRAM+r11]
    SBCO  r8, CONST_PRU0DRAM, r11, 4

// copy r9 into [PRU1DRAM+r11]
    SBCO  r9, CONST_PRU1DRAM, r11, 4

    add r11, r11, 4
    
    mov r4, 0
    mov r8, 0
    mov r9, 0

// increase the count once, this is a test for the correctness of code 
//    add r8.w2, r8.w2, 1

//r10 is always 8008
    qbeq loopback, r11, r10
    SBCO  r11, CONST_PRU0DRAM, 0, 4

//when r11 is 4008 or 8008, then generate an interrupt so the data can be copied.
// r13 is 4008   
    qbeq genint, r11, r13
    jmp spare

loopback:
   mov r11, 8
   SBCO  r11, CONST_PRU0DRAM, 0, 4
//   halt
   jmp genint

genint:
// must let PRU0 to generate interrupt. I am using PRU1 R31.b0 as data input, can not generate PRU1 interrupt.
   mov r4, 0x00000007
   sbco  r4,  CONST_PRU1DRAM, 0, 4
//   halt
   jmp spare

// set cs high, delay 2us then repeat cvrt_loop
spare:
   set r30.t11
   mov r3, 400
   add r1, r0, r3
   call delay
   jmp cvrt_loop


delay:
//r3 is cycle count
    lbbo   r3, r2, CTREG, 4

//r0 last index, r1 next index     
     
// if r1> r0, normal, no wrap around.
    qbgt normal, r0, r1    
//else r1< r0, wrap around, wait until cycle count wrapped too
// if cycle count > r0, cycle count did not wrap around yet, delay  
    qbgt delay,  r0, r3
normal:
//  if cycle count > next index (r1), delay enough time, return 
    qbge   delay_ret, r1, r3
    jmp delay 

delay_ret: 
    mov r0, r1 
    ret

end:     
    // Send notification to Host for program completion
    MOV R31.b0, PRU1_ARM_INTERRUPT+16
    HALT
