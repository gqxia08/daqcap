// *
// * PRU_memAccessPRUDataRam.p
// *
// * Copyright (C) 2012 Texas Instruments Incorporated - http://www.ti.com/
// *
// *
// *  Redistribution and use in source and binary forms, with or without
// *  modification, are permitted provided that the following conditions
// *  are met:
// *
// *    Redistributions of source code must retain the above copyright
// *    notice, this list of conditions and the following disclaimer.
// *
// *    Redistributions in binary form must reproduce the above copyright
// *    notice, this list of conditions and the following disclaimer in the
// *    documentation and/or other materials provided with the
// *    distribution.
// *
// *    Neither the name of Texas Instruments Incorporated nor the names of
// *    its contributors may be used to endorse or promote products derived
// *    from this software without specific prior written permission.
// *
// *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// *  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// *  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// *  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// *
// *

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

.origin 0
.entrypoint MEMACCESSPRUDATARAM

#include "PRU_daq.hp"


MEMACCESSPRUDATARAM:
// this is very important, clearing the STANDBY_INIT bit in the SYSCFG register.
   LBCO r0, C4, 4, 4
   CLR r0, r0, 4
   SBCO r0, C4, 4, 4      


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
    sbco r4, CONST_PRU0DRAM, 0, 4

init:    
//zero count register
    mov r3,  0x0
// copy 4 bytes from r3 to the memory address pf r2+CTREG
    sbbo r3, r2, CTREG,4

//enable cycle count
// copy from memory {r2} into register r3 
    lbbo   r3, r2, 0, 4
// set r3 bit 3 to 1
    set r3, r3, 3
// copy r3 to memory {r2+0}
    sbbo r3, r2, 0,4


continue:
     lbco r4, CONST_PRU0DRAM, 0, 4
// branch to genint if (r4 & (1<<0)) is 1
     qbbs genint, r4, 0
     jmp overflow

genint:
      MOV R31.b0, PRU0_ARM_INTERRUPT+16
      clr r4.t0
      sbco r4, CONST_PRU0DRAM, 0, 4

overflow:
// copy from memory {r2} into register r3, when  
     lbbo r3,r2,0,4
//counter overflow, need to restart counting.
// branch to init if (r3 & (1<<3) is 0
     qbbc init, r3, 3
     jmp continue       

bye:
    // Send notification to Host for program completion
    MOV R31.b0, PRU0_ARM_INTERRUPT+16


    HALT
