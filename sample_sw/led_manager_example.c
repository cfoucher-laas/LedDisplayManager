/*
 * Copyright © 2017 LAAS/CNRS
 * Author: Clément Foucher
 *
 * Distributed under the GNU GPL v2. For full terms see the file LICENSE.txt.
 *
 *
 * This file is part of LED Display Manager (LDM).
 *
 * LDM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 2 of the License.
 *
 * LDM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with LDM. If not, see <http://www.gnu.org/licenses/>.
 */


#include "platform.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xtime_l.h"


u32* led_manager_base_addr = (u32*)XPAR_LED_MANAGER_AXI_WRAPPER_0_BASEADDR;
volatile u32 volatile* led_manager_control_reg;
volatile u32 volatile* led_manager_data_reg;
volatile u32 volatile* led_manager_status_reg;


#define LED_ENABLE  0x00010000
#define LED_DISABLE 0x00000000

#define CMD_UPDATE     0x1
#define CMD_INITIALIZE 0x2
#define CMD_RESET      0x4

#define STATUS_INITIALIZED 0x1
#define STATUS_READY       0x2


inline void update_led_by_panel(u32 panel, u32 x, u32 y, u32 enable);
inline void update_led(u32 x, u32 y, u32 enable);
void initialize_display();
void write_hello_world();


int main()
{
    init_platform();

	led_manager_control_reg = led_manager_base_addr;
	led_manager_data_reg    = led_manager_base_addr + 1;
	led_manager_status_reg  = led_manager_base_addr;

    xil_printf("Initializing display... ");
    initialize_display();
    xil_printf("Done.\r\n");

    xil_printf("Writing hello world!\r\n");
    while(1)
    {
    	write_hello_world();
    }

    cleanup_platform();
    return 0;
}

inline void update_led_by_panel(u32 panel, u32 x, u32 y, u32 enable)
{
	*led_manager_data_reg = (panel << 8) | (y << 3) | x | enable;
}

inline void update_led(u32 x, u32 y, u32 enable)
{
	update_led_by_panel(x/8, x%8, y, enable);
}

void initialize_display()
{
	*led_manager_control_reg = CMD_INITIALIZE;
	while ( ((*led_manager_status_reg)&STATUS_INITIALIZED) == 0)
		; // Wait for initialization
}

void write_hello_world()
{
	XTime tStart, tEnd;

	*led_manager_control_reg = CMD_RESET; // Clean display
	while ( ((*led_manager_status_reg)&STATUS_READY) == 0)
		; // Wait for command complete

	// Write "Hello"

	// H
	update_led(1, 1, LED_ENABLE);
	update_led(1, 2, LED_ENABLE);
	update_led(1, 3, LED_ENABLE);
	update_led(1, 4, LED_ENABLE);
	update_led(1, 5, LED_ENABLE);

	update_led(2, 3, LED_ENABLE);

	update_led(3, 3, LED_ENABLE);

	update_led(4, 3, LED_ENABLE);

	update_led(5, 1, LED_ENABLE);
	update_led(5, 2, LED_ENABLE);
	update_led(5, 3, LED_ENABLE);
	update_led(5, 4, LED_ENABLE);
	update_led(5, 5, LED_ENABLE);

	// E
	update_led(7, 1, LED_ENABLE);
	update_led(7, 2, LED_ENABLE);
	update_led(7, 3, LED_ENABLE);
	update_led(7, 4, LED_ENABLE);
	update_led(7, 5, LED_ENABLE);

	update_led(8, 1, LED_ENABLE);
	update_led(8, 3, LED_ENABLE);
	update_led(8, 5, LED_ENABLE);

	update_led(9, 1, LED_ENABLE);
	update_led(9, 3, LED_ENABLE);
	update_led(9, 5, LED_ENABLE);

	update_led(10, 1, LED_ENABLE);
	update_led(10, 3, LED_ENABLE);
	update_led(10, 5, LED_ENABLE);

	update_led(11, 1, LED_ENABLE);
	update_led(11, 5, LED_ENABLE);

	// L
	update_led(13, 1, LED_ENABLE);
	update_led(13, 2, LED_ENABLE);
	update_led(13, 3, LED_ENABLE);
	update_led(13, 4, LED_ENABLE);
	update_led(13, 5, LED_ENABLE);

	update_led(14, 5, LED_ENABLE);

	update_led(15, 5, LED_ENABLE);

	update_led(16, 5, LED_ENABLE);

	update_led(17, 5, LED_ENABLE);

	// L
	update_led(19, 1, LED_ENABLE);
	update_led(19, 2, LED_ENABLE);
	update_led(19, 3, LED_ENABLE);
	update_led(19, 4, LED_ENABLE);
	update_led(19, 5, LED_ENABLE);

	update_led(20, 5, LED_ENABLE);

	update_led(21, 5, LED_ENABLE);

	update_led(22, 5, LED_ENABLE);

	update_led(23, 5, LED_ENABLE);

	// O
	update_led(25, 2, LED_ENABLE);
	update_led(25, 3, LED_ENABLE);
	update_led(25, 4, LED_ENABLE);

	update_led(26, 1, LED_ENABLE);
	update_led(26, 5, LED_ENABLE);

	update_led(27, 1, LED_ENABLE);
	update_led(27, 5, LED_ENABLE);

	update_led(28, 1, LED_ENABLE);
	update_led(28, 5, LED_ENABLE);

	update_led(29, 2, LED_ENABLE);
	update_led(29, 3, LED_ENABLE);
	update_led(29, 4, LED_ENABLE);


	// Update panel
	*led_manager_control_reg = CMD_UPDATE;
	while ( ((*led_manager_status_reg)&STATUS_READY) == 0)
		; // Wait for command complete


	// Wait for 1s
	XTime_GetTime(&tStart);
	XTime_GetTime(&tEnd);
	while ( ((tEnd - tStart)/((float)COUNTS_PER_SECOND)) < 1)
	{
		XTime_GetTime(&tEnd);
	}

	*led_manager_control_reg = CMD_RESET; // Clean panel
	while ( ((*led_manager_status_reg)&STATUS_READY) == 0)
		; // Wait for command complete


	// Write "World"

	// W
	update_led(2, 2, LED_ENABLE);
	update_led(2, 3, LED_ENABLE);
	update_led(2, 4, LED_ENABLE);
	update_led(2, 5, LED_ENABLE);
	update_led(2, 6, LED_ENABLE);

	update_led(3, 5, LED_ENABLE);

	update_led(4, 4, LED_ENABLE);

	update_led(5, 5, LED_ENABLE);

	update_led(6, 2, LED_ENABLE);
	update_led(6, 3, LED_ENABLE);
	update_led(6, 4, LED_ENABLE);
	update_led(6, 5, LED_ENABLE);
	update_led(6, 6, LED_ENABLE);

	// O
	update_led(8, 3, LED_ENABLE);
	update_led(8, 4, LED_ENABLE);
	update_led(8, 5, LED_ENABLE);

	update_led(9, 2, LED_ENABLE);
	update_led(9, 6, LED_ENABLE);

	update_led(10, 2, LED_ENABLE);
	update_led(10, 6, LED_ENABLE);

	update_led(11, 2, LED_ENABLE);
	update_led(11, 6, LED_ENABLE);

	update_led(12, 3, LED_ENABLE);
	update_led(12, 4, LED_ENABLE);
	update_led(12, 5, LED_ENABLE);

	// R
	update_led(14, 2, LED_ENABLE);
	update_led(14, 3, LED_ENABLE);
	update_led(14, 4, LED_ENABLE);
	update_led(14, 5, LED_ENABLE);
	update_led(14, 6, LED_ENABLE);

	update_led(15, 2, LED_ENABLE);
	update_led(15, 4, LED_ENABLE);

	update_led(16, 2, LED_ENABLE);
	update_led(16, 4, LED_ENABLE);
	update_led(16, 5, LED_ENABLE);

	update_led(17, 2, LED_ENABLE);
	update_led(17, 4, LED_ENABLE);
	update_led(17, 6, LED_ENABLE);

	update_led(18, 3, LED_ENABLE);

	// L
	update_led(20, 2, LED_ENABLE);
	update_led(20, 3, LED_ENABLE);
	update_led(20, 4, LED_ENABLE);
	update_led(20, 5, LED_ENABLE);
	update_led(20, 6, LED_ENABLE);

	update_led(21, 6, LED_ENABLE);

	update_led(22, 6, LED_ENABLE);

	update_led(23, 6, LED_ENABLE);

	update_led(24, 6, LED_ENABLE);

	// D
	update_led(26, 2, LED_ENABLE);
	update_led(26, 3, LED_ENABLE);
	update_led(26, 4, LED_ENABLE);
	update_led(26, 5, LED_ENABLE);
	update_led(26, 6, LED_ENABLE);

	update_led(27, 2, LED_ENABLE);
	update_led(27, 6, LED_ENABLE);

	update_led(28, 2, LED_ENABLE);
	update_led(28, 6, LED_ENABLE);

	update_led(29, 2, LED_ENABLE);
	update_led(29, 6, LED_ENABLE);

	update_led(30, 3, LED_ENABLE);
	update_led(30, 4, LED_ENABLE);
	update_led(30, 5, LED_ENABLE);

	// Update panel
	*led_manager_control_reg = CMD_UPDATE;
	while ( ((*led_manager_status_reg)&STATUS_READY) == 0)
		; // Wait for command complete

	// Wait for 1s
	XTime_GetTime(&tStart);
	XTime_GetTime(&tEnd);
	while ( ((tEnd - tStart)/((float)COUNTS_PER_SECOND)) < 1)
	{
		XTime_GetTime(&tEnd);
	}
}
