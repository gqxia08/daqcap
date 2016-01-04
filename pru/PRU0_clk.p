// *****************************************************************************/
// file:   PRU0_clk.p 
//
// brief:  PRU0 clk generator for ad7606, PRU clk counter, clk frequency is  200MHz.
//
//
//  (C) Copyright 2014
//
//  author     Xia Guoqiang
//
//  version    0.2
// *****************************************************************************/
.setcallreg r16.w0
.origin 0
.entrypoint DAQCLK

#include "PRU_daq.hp"


DAQCLK:
// this is very important, clearing the STANDBY_INIT bit in the SYSCFG register.
// Load Byte Burst with Constant Table Offset (LBCO)
// Store Byte Burst with Constant Table Offset (SBCO)
  
 //copy 4 bytes into r0 from memory address C4+4
   LBCO r0, C4, 4, 4  
 
 //clear bit  r0 = r0 & ~(1<<4) 
   CLR r0, r0, 4

 //copy 4 bytes from r0 into memory address C4+4  
   SBCO r0, C4, 4, 4   

//r11 is turn counter, every turn it is going to increase one
   MOV r11, 0x00000000

//rotation state requires r10 as a place to hold rotation state. 
   mov r10, r31

    // Configure the block index register for PRU0 by setting c24_blk_index[7:0] and
    // c25_blk_index[7:0] field to 0x00 and 0x00, respectively.  This will make C24 point
    // to 0x00000000 (PRU0 DRAM) and C25 point to 0x00002000 (PRU1 DRAM).
    MOV       r0, 0x00000000

// Address for the Constant table Programmable Pointer Register 0(CTPPR_0)
//#define CTBIR_0         0x22020
    MOV       r1, CTBIR_0

//  copy 4 bytes from r0 to the memory address of r1
    ST32      r0, r1

//this is the PRU0 control register address, PRU0CTL+CTREG is the counter address
    mov r2,  PRUCTL
    mov r4, 0

//#define CONST_PRU0DRAM   C24
//copy 4 bytes from r4 into memory address C24, zero it in this case    
    sbco r4, CONST_PRU0DRAM, 0, 4

INIT:    
//zero count register
    mov r3,  0x0

//Store Byte Burst (SBBO)
// copy 4 bytes from r3 to the memory address of r2+CTREG
    sbbo r3, r2, CTREG,4

//enable cycle count
// copy from memory {r2} into register r3 
    lbbo   r3, r2, 0, 4
// set r3 bit 3 to 1
    set r3, r3, 3
// copy r3 to memory {r2+0}
    sbbo r3, r2, 0,4


CONTINUE:
     lbco r4, CONST_PRU0DRAM, 0, 4

//Quick Branch if Bit is Set (QBBS)
// branch to genint if (r4 & (1<<0)) is 1
// because PRU1 used for daq data input, it can not generate interrupt to arm cpu
// has to use PRU0 to generate interrupt to inform arm cpu there is enough data in buffer, need to be copied to arm cpu memory. PRU1 will set memory PRU0DRAM to 0x1 when interrupt need to be send.
     qbbs GENINT, r4, 0
     jmp OVERFLOW

GENINT:
      MOV R31.b0, PRU0_ARM_INTERRUPT+16
      clr r4.t0
      sbco r4, CONST_PRU0DRAM, 0, 4

OVERFLOW:
// copy from memory {r2} into register r3, when  
     lbbo r3,r2,0,4
//counter overflow, need to restart counting.
// branch to init if (r3 & (1<<3) is 0
//else go to TRIGGER
     qbbc INIT, r3, 3

TRIGGER:
// count trigger input, in one rotation, DO high; in other rotation, DO low. 
// this is very important that no false trigger in this line, signal must be clean
// every low to high means one turn, every other turn switch on/off light.
// go to LO if (r31 & (1<<14) is 0, only r31.t14==1, r10.t14==0, means one turn 
//  r31 is for input, r30 is for output
// pru0_r30 and r31 bit 14 and 15 are exposed on P8   
     qbbc LO, r31, 14   
     qbbc ONETURN, r10, 14
//here,  r31.t14==1, r10.t14==1, so jmp continue
     jmp CONTINUE

LO:
     mov r10, r31
     jmp CONTINUE

// every turn, increase r11 by 1.
ONETURN:
     mov r10, r31
     add r11, r11, 1

// if r11 is even, turn off light
     qbbc DOLO, r11, 1
DOHI:
     set r30.t14
     jmp CONTINUE
DOLO:
     clr r30.t14
     jmp CONTINUE       

BYE:
    // Send notification to Host for program completion
    MOV R31.b0, PRU0_ARM_INTERRUPT+16


    HALT
