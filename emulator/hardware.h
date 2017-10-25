// *******************************************************************************************************************************
// *******************************************************************************************************************************
//
//		Name:		hardware.h
//		Purpose:	Hardware Interface (header)
//		Date:		1st October 2017
//		Author:		Paul Robson (paul@robsons.org.uk)
//
// *******************************************************************************************************************************
// *******************************************************************************************************************************

#ifndef _HARDWARE_H
#define _HARDWARE_H

void HWIReset(void);
void HWISetVideoAddress(WORD16 vAddr,WORD16 pc);
WORD16 HWIGetVideoAddress();
BYTE8 HWIGetDisplayLines(void);
BYTE8 HWIGetScreenOn(void);
BYTE8 HWISetScreenOn(BYTE8 isOn);
BYTE8 HWIIsHexKeypadPressed(void);
void HWISetKeyboardLatch(BYTE8 latch);
void  HWIEndFrame(void);
#endif
