#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            // Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            // Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      // Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   // Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   // Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   // Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              // Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              // Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              // Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              // Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              // Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              // Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              // Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              // Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         // GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         // ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
    bl     init_leds             // Same as previous labs
    bl     init_btns             // Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl     install_alrm_isr      // See below
    bl     install_gpio_isr      // See below          
loop:
    bl     set_alarm             // Set a new alarm
    wfi                          // Wait here until any interrupt fires
    b      loop                  // Always branch back to loop

init_btns:
    push   {lr}                   // Store the link register to the stack as we will call nested subroutines

    movs   r0, #GPIO_BTN_DN       // The GPIO pin on the PI PICO board 
    movs   r1, #GPIO_DIR_IN       // Direction specified as input 
    bl     init_gpio              // Initiates gpio port and specifies if input/output
    bl     asm_gpio_set_irq       // Initiates gpio port to fallind_edge

    movs   r0, #GPIO_BTN_EN       // The GPIO pin on the PI PICO board 
    movs   r1, #GPIO_DIR_IN       // Direction specified as input 
    bl     init_gpio              // Initiates gpio port and specifies if input/output
    bl     asm_gpio_set_irq       // Initiates gpio port to fallind_edge 

    movs   r0, #GPIO_BTN_UP       // The GPIO pin on the PI PICO board 
    movs   r1, #GPIO_DIR_IN       // Direction specified as input 
    bl     init_gpio              // Initiates gpio port and specifies if input/output
    bl     asm_gpio_set_irq       // Initiates gpio port to fallind_edge 

    pop    {pc}                   // Pop the link register from the stack to the program counter

@ Subroutine used to initialise the PI Pico built-in LED
init_leds:
    push   {lr}              // Store the link register to the stack as we will call nested subroutines

    movs   r0, #GPIO_LED_PIN // The GPIO pin on the PI PICO board 
    movs   r1, #GPIO_DIR_OUT // Direction specified as output 
    bl     init_gpio         // Initiates gpio port and specifies if input/output

    pop    {pc}              // Pop the link register from the stack to the program counter
    
//
// Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
//
install_alrm_isr:
    push   {lr}                  // Store the link register to the stack as we will call nested subroutines 

    ldr    r0, =alrm_isr         // Set first parameter to the address of gpio_isr
    ldr    r1, =1                // Set the second parameter to the 32 bit number (the bit associated on the vector table)
    ldr    r2, =ALRM_ISR_OFFSET  // The offset for the address in the vector table
    bl     install_isr           // branch and install the isr for gpio_isr

    pop    {pc}                  // Pop the link register from the stack to the program counter

//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
    push   {lr}                            // Store the link register to the stack as we will call nested subroutines

    ldr    r1, =lstate                     // load address of alarm state
    ldr    r1, [r1]                        // read the address of the alarm state
    cmp    r1, #1                          // If alarm occuring
    bne    alarmNotOccuring

    ldr    r0, =msg9                       // load message from memory to register
    push   {r1}                            // Push registers that will be affected by printf to the stack
    bl     printf                          // Print "Alarm Occuring!\n"
    pop    {r1}                            // pop the registers from the stack to the corresponding registers

alarmNotOccuring:
    // Enable timer 0 interrupt
    ldr    r2, =TIMER_BASE                 // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    str    r1, [r2, #TIMER_INTE_OFFSET]    // Store the time for the alarm in the specified address
    // Set alarm                                  
    ldr    r1, [r2, #TIMER_TIMELR_OFFSET]  // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr    r3, =ltimer                     // load address of alarm timer
    ldr    r3, [r3]                        // find alarm time by loading the address from memory
    add    r1, r3                          // Add the time delay you want to wait for to the current timer count
    str    r1, [r2, #TIMER_ALARM0_OFFSET]  // Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)

    pop    {pc}                            // Pop the link register from the stack to the program counter

//
// Service the pending interrupt from the ALARM0 TIMER
//
.thumb_func                             // Required for all interrupt service routines
alrm_isr:
    push   {lr}                         // Store the link register to the stack as we will call nested subroutines

    @ Clear the interrupt
    ldr    r2, =TIMER_BASE              // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    movs   r1, #1                       // Load in the bit of the vector table for timer (1)
    str    r1, [r2, #TIMER_INTR_OFFSET] // Store the bit to disable the pending interrupt
    bl     subtoggle                    // Perform required functionality (e.g. toggle the LED)

    pop    {pc}                         // Pop the link register from the stack to the program counter

@ First function of SVC subroutine - turn on the LED
subtoggle:
    push    {lr}               // Store the link register to the stack as we will call nested subroutines

    movs    r0, #GPIO_LED_PIN  // Set the LED GPIO pin number to r0 for use by asm_gpio_get
    bl      asm_gpio_get       // branch and get the pin if it's on/off
    movs    r1, #1             // Used for EOR mask next line
    eors    r1, r0, r1         // toggle the led off/on using EOR operation, On if off, and Off if on
    movs    r0, #GPIO_LED_PIN  // Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put       // Update the the value of the LED GPIO pin (based on value in r1)

    pop     {pc}               // Pop the link register from the stack to the program counter

//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    push   {lr}                   // Store the link register to the stack as we will call nested subroutines 

    ldr    r0, =gpio_isr          // Set first parameter to the address of gpio_isr
    ldr    r1, =0x2000            // Set the second parameter to the 32 bit number (the bit associated on the vectore table)
    ldr    r2, =GPIO_ISR_OFFSET   // The offset for the address in the vector table
    bl     install_isr            // branch and install the isr for gpio isr

    pop    {pc}                   // Pop the link register from the stack to the program counter

//
// Service the pending interrupt from the GPIO
//
.thumb_func                                                   // Required for all interrupt service routines
gpio_isr:
    push   {lr}                                               // Store the link register to the stack as we will call nested subroutines 

    ldr    r0, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) // Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    ldr    r0, [r0]

    bl     pressed_button                                     // action needed to take for the buttons

    pop    {pc}                                               // Pop the link register from the stack to the program counter

//
// Subroutine that finds and does the actions needed when a button is pressed
//
// Parameters:
// R0: Mask of the button to check
//
pressed_button:
    push   {r0, lr}                                           // Store the link register and parameters to the stack as we will call nested subroutines  

    ldr    r1, =lstate                                        // load address of alarm state
    ldr    r1, [r1]                                           // find alarm time by loading the address from memory

    ldr    r2, =GPIO_BTN_DN_MSK                               // load in mask of dn button 
    cmp    r0, r2                                             // if mask is dn button
    bne    dn_not_pressed

    push   {r0}                                               // push important affected register to stack 
    movs   r0, r1                                             // move alarm time to first parameter of funciton 
    bl     gpio_20_pressed                                    // branch to condition of gpio 20 is pressed
    pop    {r0}                                               // pop important register from stack back to the register

    b      not_pressed
dn_not_pressed:

    ldr    r2, =GPIO_BTN_EN_MSK                               // load in mask of en button 
    cmp    r0, r2                                             // if mask is en button
    bne    en_not_pressed

    push   {r0}                                               // push important affected register to stack 
    movs   r0, r1                                             // move alarm time to first parameter of funciton 
    bl     gpio_21_pressed                                    // branch to condition of gpio 21 is pressed
    pop    {r0}                                               // pop important register from stack back to the register

    b      not_pressed
en_not_pressed: 

    ldr    r2, =GPIO_BTN_UP_MSK                               // load in mask of en button 
    cmp    r0, r2                                             // if mask is up button 
    bne    up_not_pressed

    push   {r0}                                               // push important affected register to stack 
    movs   r0, r1                                             // move alarm time to first parameter of funciton 
    bl     gpio_22_pressed                                    // branch to condition of gpio 22 is pressed
    pop    {r0}                                               // pop important register from stack back to the register

up_not_pressed:

not_pressed:                                                
    ldr    r1, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)       // Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    str    r0, [r1]                                           

    pop    {r0, pc}                                           // Pop the link register and parameters from the stack to the program counter

//
// Subroutine that takes in R0 (direction to shift 1 for right, 0 for left)
// will shift the time ltimer and store it back to memory
//
// Parameters:
// R0: boolean 1/0, 1 for right shift (halve timer), 0 for left shift (double timer)
// 
shift_direction:
    push   {r0, lr}                 // Store the link register and parameters to the stack as we will call nested subroutines 

    ldr    r1, =ltimer              // load in alarm time address
    ldr    r1, [r1]                 // load address from memory to get value

    cmp    r0, #1                   // if shifting right
    bne    shift_left

    lsrs   r1, #1                   // half the alarm period 

    b      endOfShifting            
shift_left:                         // else (double alarm period)

    lsls   r1, #1                   // double the alarm period

endOfShifting:

    ldr    r0, =ltimer              // load in alarm time address
    str    r1, [r0]                 // store the divided alarm into ltimer

    pop    {r0, pc}                 // Pop the parameters and link register from the stack to the program counter

//
// Subroutine that resets the alarm
//
resetAlarm:
    push   {lr}                     // Store the link register the stack as we will call nested subroutines 
    
    ldr    r0, =DFLT_ALARM_TIME     // load default alarm time into a register
    ldr    r1, =ltimer              // load the address of ltimer 
    str    r0, [r1]                 // default 1 sec alarm

    ldr    r0, =msg7                // load message from memory to register
    bl     printf                   // Print "Resetting Alarm Time!\n"

    pop    {pc}                     // Pop the link register from the stack to the program counter
//
// Subroutine that does the tasks needed for gpio_22 button press
// 
// Parameters:
// R0: boolean 1/0, lstate (is alarm on or off)
//
gpio_22_pressed: 
    push   {r0, lr}                 // Store the link register and parameters to the stack as we will call nested subroutines 

    push   {r0}                     // Push affected parameter to stack
    ldr    r0, =msg4                // load message from memory to register
    bl     printf                   // Print "Button GP20 Pressed!\n"
    pop    {r0}                     // Pop affected parameter back to its register

    cmp    r0, #0                   // if in a not flashing state
    bne    gpio_not_22_not_flashing                                        

    bl     resetAlarm               // reset the alarm to default alarm time
    
    b      end_of_gpio_22
gpio_not_22_not_flashing:           // else (in a flashing state)

    ldr    r0, =msg5                // Print "Halving Alarm Time!\n"
    bl     printf

    movs   r0, #0                   // 0 for halving alarm time
    bl     shift_direction          // shift left (binary / 2)

end_of_gpio_22:

    pop    {r0, pc}                 // Pop the parameters and link register from the stack to the program counter
 
//
// Subroutine that does the tasks needed for gpio_21 button press
//
// Parameters:
// R0: boolean 1/0, lstate (is alarm on or off)
//
gpio_21_pressed:
    push   {r0, lr}                // Store the link register and parameters to the stack as we will call nested subroutines   

    push   {r0}                    // Push affected parameter to stack
    ldr    r0, =msg3               // load message from memory to register
    bl     printf                  // Print "Button GP21 Pressed!\n"
    pop    {r0}                    // Pop affected parameter back to its register

    push   {r0}                    // Push affected parameter to stack
    ldr    r0, =msg8               // load message from memory to register
    bl     printf                  // Print "Stops/Restart Alarm!\n"
    pop    {r0}                    // Pop affected parameter back to its register

    movs   r1, #1                  // load 1 to register to be used with eor
    eors   r0, r0, r1              // If alarm stopped, then start the alarm, and vice versa using parameter 
    ldr    r1, =lstate             // load address of alarm state
    str    r0, [r1]                // store the stopped/on alarm into the memory address

    pop    {r0, pc}                 // Pop the parameters and link register from the stack to the program counter

//
// Subroutine that does the tasks needed for gpio_20 button press
// 
// Parameters:
// R0: boolean 1/0, lstate (is alarm on or off)
//
gpio_20_pressed: 
    push   {r0, lr}                 // Store the link register and parametersto the stack as we will call nested subroutines 

    push   {r0}                     // Push affected parameter to stack
    ldr    r0, =msg2                // load message from memory to register
    bl     printf                   // Print "Button GP20 Pressed!\n"
    pop    {r0}                     // Pop affected parameter back to its register

    cmp    r0, #0                   // if in a not flashing state
    bne    gpio_not_20_not_flashing                                        

    bl     resetAlarm               // reset the alarm to default alarm time
    
    b      end_of_gpio_20
gpio_not_20_not_flashing:           // else (in a flashing state)

    ldr    r0, =msg5                // load message from memory to register
    bl     printf                   // Print "Halving Alarm Time!\n"

    movs   r0, #1                   // 1 for doubling alarm time
    bl     shift_direction          // shift right (binary * 2)

end_of_gpio_20:

    pop    {r0, pc}                 // Pop the parameters and link register from the stack to the program counter


//
// Installs an isr in the RAM vector table and enables the correct interrupt
// parameters:
// R0: The address of the isr
// R1: The correct bit value in the vector table
// R2: The offset for the address in the vector table
//
install_isr:
    push   {r0-r2, lr}                                 // Store the parameters and link register to the stack as we will call nested subroutines

    ldr    r3, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr    r3, [r3]                                    // load address from memory
    add    r3, r2                                      // load addres of gpio_isr
    str    r0, [r3]                                    // store this address in memory to be used when interrupt occurs
    ldr    r3, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   // Disable the IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) 1 << 13 vector table
    str    r1, [r3]                                    // Store the correct bit value in the vector table
    ldr    r3, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   // Enable the IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    str    r1, [r3]                                    // Store the correct bit value in the vector table

    pop    {r0-r2, pc}                                 // Pop the parameters and link register from the stack to the program counter


//
// Initiates gpio port and specifies if input/output
//
// Parameters:
// R0: The GPIO pin on the PI PICO board 
// R1: 1/0 (input/output)
//
init_gpio:
    push   {r0-r1, lr}      // Store the link register and parameters to the stack

    push   {r0, r1}         // push parameters as they get affected by asm_gpio_init function
    bl     asm_gpio_init    // Call the subroutine to initialise the GPIO pin specified by r0
    pop    {r0, r1}         // Return the effected registers to how they were before the function
                            // No need to push pop as last function called
    bl     asm_gpio_set_dir // Call the subroutine to set the GPIO pin specified by r0 to state specified by r1

    pop    {r0-r1, pc}      // Pop the parameters to the registers and link register from the stack to the program counter

.align 4
msg1:   .asciz "Button Pressed!\n"
msg2:   .asciz "Button GP20 Pressed!\n"
msg3:   .asciz "Button GP21 Pressed!\n"
msg4:   .asciz "Button GP22 Pressed!\n"
msg5:   .asciz "Halving Alarm Time!\n"
msg6:   .asciz "Doubling Alarm Time!\n"
msg7:   .asciz "Resetting Alarm Time!\n"
msg8:   .asciz "Stops/Restart Alarm!\n"
msg9:   .asciz "Alarm Occuring!\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME