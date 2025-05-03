#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified         // Specify unified assembly syntax
.cpu    cortex-m0plus   // Specify CPU type is Cortex M0+
.thumb                  // Specify thumb assembly for RP2040

.global main_asm        // Provide program starting address to the linker
.global subtoggle
.global init_leds
.global init_btns 
.global install_gpio_isr 
.global install_alrm_isr
.global alarm_isr
.global gpio_isr
.global loop
.global wfi_interrupt
.global set_alarm

.align  4               // Specify code alignment

.equ    DFLT_STATE_STRT, 1            // Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            // Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      // Specify the default alarm timeout

.equ    GPIO_LED_PIN, 25              // Specify pin for the built-in LED
.equ    LED_VAL_ON,    1              // Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              // Specify value that turns the LED "off"

.equ    GPIO_21,                  21           // Specify pin for the "enter" button
.equ    GPIO_BTN_21_FALLING_EDGE, 0x00400000   // Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_21_RISING_EDGE,  0x00800000   // Bit-23 for rising-edge event of GP21
.equ    GPIO_BTN_21_RISING_EDGE_FALLING_EDGE, 0x00c00000 // Bit 22 and bit 23 for rising and falling-edge event of gp21
.equ    GPIO_DIR_IN,              0            // Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,             1            // Specify output direction for a GPIO pin

.equ    GPIO_ISR_OFFSET,          0x74         // GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET,          0x40         // ALARM0 is int #0 (vector table entry 16)

.equ    LENGTH_OF_BUFFER,         1000

@ Entry point to the ASM portion of the program
main_asm:
                                 // Global bit for IRQ_SETUP_1, Offset: 0x14, bit 28 SEC_ENA => enables second matching 
    bl     init_leds             // Same as previous labs
    bl     init_btns             // Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl     install_gpio_isr
    bl     install_alrm_isr
loop:
    wfi                          // Wait here until any interrupt fires
    b      loop                  // Always branch back to loop

wfi_interrupt:
    push   {lr}
    wfi 
    pop    {pc}

init_btns:
    push   {lr}                   // Store the link register to the stack as we will call nested subroutines

    movs   r0, #GPIO_21           // The GPIO pin on the PI PICO board 
    movs   r1, #GPIO_DIR_IN       // Direction specified as input 
    bl     init_gpio              // Initiates gpio port and specifies if input/output
    ldr    r1, =4                 // setup button for GPIO_ISR_FALLING_EDGE (4)
    bl     asm_gpio_set_irq       // Initiates gpio port to falling_edge 
    movs   r0, #GPIO_21           // The GPIO pin on the PI PICO board
    ldr    r1, =8                 // setup button for GPIO_ISR_RISING_EDGE (8)
    bl     asm_gpio_set_irq       // Initiates gpio port to rising_edge 

    pop    {pc}                   // Pop the link register from the stack to the program counter

@ Subroutine used to initialise the PI Pico built-in LED
init_leds:
    push   {lr}              // Store the link register to the stack as we will call nested subroutines

    movs   r0, #GPIO_LED_PIN // The GPIO pin on the PI PICO board 
    movs   r1, #GPIO_DIR_OUT // Direction specified as output 
    bl     init_gpio         // Initiates gpio port and specifies if input/output

    pop    {pc}              // Pop the link register from the stack to the program counter
    
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
// Service the pending interrupt from the ALARM0 TIMER (A space has occured)
//
.thumb_func                                // Required for all interrupt service routines
alrm_isr:
    push   {lr}                            // Store the link register to the stack as we will call nested subroutines

    ldr    r2, =lstate
    ldr    r2, [r2]

    cmp    r2, #0
    bne    end_now

    b      end_of_whole_sequence
end_now:

    ldr    r0, =2
    ldr    r1, =buffer
    bl     store_next_in_array

    ldr    r2, =spacesOccured
    ldr    r2, [r2] 

    cmp    r2, #1 // if (spaces < 1)
    bhs    more_than_one_space

    movs   r1, #1
    adds   r2, r1
    ldr    r1, =spacesOccured
    str    r2, [r1]

    b      not_end_of_sequence

more_than_one_space: // else (if (space >= 1))

    movs   r1, #1   
    adds   r2, r1
    ldr    r1, =spacesOccured
    str    r2, [r1]

    b      end_of_whole_sequence

not_end_of_sequence:

    bl     subtoggle                       // Perform required functionality (e.g. toggle the LED)

    ldr    r1, =lstate
    ldr    r1, [r1]

    cmp    r1, #1
    bne    do_not_set_alarm

    bl     set_alarm                       // Set a new alarm

do_not_set_alarm:

end_of_whole_sequence:

    @ Clear the interrupt
    ldr    r2, =TIMER_BASE                 // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    movs   r1, #1                          // Load in the bit of the vector table for timer (1)
    str    r1, [r2, #TIMER_INTR_OFFSET]    // Store the bit to disable the pending interrupt
    

    pop    {pc}                            // Pop the link register from the stack to the program counter

// Subroutine that turns the LED on/off
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
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
    push   {lr}                            // Store the link register to the stack as we will call nested subroutines

    ldr    r1, =lstate                     // load address of alarm state
    ldr    r1, [r1]                        // read the address of the alarm state
    cmp    r1, #1                          // If alarm occuring
    bne    alarmNotOccuring

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
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    push   {lr}                      // Store the link register to the stack as we will call nested subroutines 

    ldr    r0, =gpio_isr             // Set first parameter to the address of gpio_isr
    ldr    r1, =0x2000               // Set the second parameter to the 32 bit number (the bit associated on the vector table)
    ldr    r2, =GPIO_ISR_OFFSET      // The offset for the address in the vector table
    bl     install_isr               // branch and install the isr for gpio isr

    pop    {pc}                      // Pop the link register from the stack to the program counter

.thumb_func 
gpio_isr: // In the event of falling edge/ unlikely circumstance for both at the same exact time
    push   {lr}

    ldr    r2, =lstate          // when pressing a button turn off the alarm (it will turn on once we let go of the button)
    movs   r3, #0               // alarms are used to create spaces in the characters/code
    str    r3, [r2]

    ldr    r0, =spacesOccured   // reset the spaces, since new dot/dash given
    ldr    r0, [r0]

    cmp    r0, #1 // if (space <= 1)
    bgt    end_space_check
    ldr    r0, =spacesOccured
    movs   r1, #0
    str    r1, [r0]
end_space_check:

    ldr    r0, =spacesOccured   // reset the spaces, since new dot/dash given
    ldr    r0, [r0]

    cmp    r0, #1  // if (space > 1)
    bls    more_than_one_space_gpio_isr

    ldr    r0, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) // Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    ldr    r0, [r0]
    
    ldr    r1, =GPIO_BTN_21_FALLING_EDGE
    cmp    r0, r1 
    bne    falling_check

    b      end_gpio_isr_check
falling_check:

    ldr    r1, =GPIO_BTN_21_RISING_EDGE
    cmp    r0, r1 
    bne    rising_check

    b      end_gpio_isr_check
rising_check:

    ldr    r1, =GPIO_BTN_21_RISING_EDGE_FALLING_EDGE
    cmp    r0, r1
    bne    rising_falling_check

    b      end_gpio_isr_check
rising_falling_check:


end_gpio_isr_check:
    movs   r4, r0
    ldr    r2, =lstate
    movs   r3, #0
    str    r3, [r2]

    b      disable_interrupt_gpio_isr
more_than_one_space_gpio_isr:   // else if (space)

    ldr    r2, =lstate
    movs   r3, #0
    str    r3, [r2]

    ldr    r0, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) // Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    ldr    r0, [r0]
    movs   r4, r0

    ldr    r1, =GPIO_BTN_21_FALLING_EDGE

    cmp    r0, r1 
    bne    not_falling_edge

    movs   r2, #0
    ldr    r3, =lstate 
    str    r2, [r3]

    bl     get_current_time // time is now in R0

    ldr    r3, =pressedTime
    str    r0, [r3]

    b      disable_interrupt_gpio_isr
not_falling_edge:  

    ldr    r1, =GPIO_BTN_21_RISING_EDGE

    cmp    r0, r1
    bne    did_not_rising_edge  // if rising edge

    bl     get_current_time

    movs   r2, r0
    
    ldr    r3, =pressedTime
    ldr    r3, [r3]

    subs   r0, r3 // time it took 

    movs   r3, r1
    bl     is_dash // 0 for dot, 1 for dash
    movs   r1, r3
    
    push   {r1}
    ldr    r1, =buffer
    bl     store_next_in_array
    pop    {r1}

    ldr    r3, =countOfSequence
    ldr    r3, [r3] 

    movs   r0, #1
    adds   r3, r0
    ldr    r0, =countOfSequence
    str    r2, [r0]

    ldr    r3, =pressedTime
    str    r2, [r3]

    movs   r2, #1
    ldr    r3, =lstate 
    str    r2, [r3]

    push   {r1-r3}
    bl     set_alarm             // Set a new alarm
    pop    {r1-r3}

 
did_not_rising_edge:
    ldr    r2, =GPIO_BTN_21_RISING_EDGE_FALLING_EDGE
    cmp    r0, r2 
    bne    did_not_fall_and_rise_edge

    movs   r4, r2

did_not_fall_and_rise_edge:


disable_interrupt_gpio_isr:
    ldr    r2, =GPIO_BTN_21_FALLING_EDGE
    cmp    r4, r2
    bne    do_not_set_alarm_for_any_circumstances


    movs   r2, #0
    ldr    r3, =lstate 
    str    r2, [r3]

do_not_set_alarm_for_any_circumstances:

    movs   r0, r4
    ands   r0, r1
    ldr    r1, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)       // Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    str    r0, [r1] 

    pop    {pc}

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
// Subroutine that get's the current System time and returns it
// return 
// R0: Current System time
//
get_current_time:
    push   {lr}

    ldr    r0, =TIMER_BASE                 // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    ldr    r0, [r0, #TIMER_TIMELR_OFFSET]  // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register    

    pop    {pc}

//
// Subroutine that finds out if dot or dash (*no space checking*)
// parameters:
// R0: time passed (in microseconds)
// returns: 
// R0: if dot ->  0
//     if dash -> 1
is_dash:
    push   {lr} 
    ldr    r1, =1000000

    cmp    r0, r1 // if (press < 1 second)
    bhs    if_not_dot

    movs   r0, #0

    b      end_of_is_dash
if_not_dot:

    cmp    r0, r1 // else if (press > 1 second)
    bls    if_not_dash 

    movs   r0, #1

    b      end_of_is_dash
if_not_dash:

end_of_is_dash:

    pop    {pc}

//
// Subroutine that takes in array, and stores value it in the next index to the offset_of_buffer
// parameters:
// R0: value to store in the next index of array
// R1: array memory address
//
store_next_in_array:
    push   {r0-r1,lr}

    ldr    r2, =offset_of_buffer
    ldr    r2, [r2]
    movs   r3, #4   // next index of array
    adds   r2, r3 
    movs   r3, r2
    ldr    r2, =offset_of_buffer
    str    r3, [r2]
    adds   r1, r3
    str    r0, [r1] // store r0 in memory

    pop    {r0-r1,pc}


@ //
@ // Subroutine that takes in an array and iterates through it, for testing purposes
@ //
@ //
@ iterate_array:
@     push   {r0,lr}

@     movs   r1, #0 // int i = 0
@     ldr    r2, =LENGTH_OF_BUFFER // int length = array.length;
@     ldr    r3, =offset_of_buffer
@     movs   r4, #2
@     lsls   r2, r4

@ while_iterating_array: // while (i < length)
@     cmp    r1, r2
@     bhs    end_iterating_while

@     adds   r0, r1
@     ldr    r3, [r0]

@     adds   r1, #1  // i++;
@     b      while_iterating_array
@ end_iterating_while:
// int i = 0;
// int length = array.length;
// while (i < length)
// {
//    int a = array[i];
//    printf("%d", a);
//    i++;
// }
    @ pop    {r0,pc}

@ Set data alignment per byte
.align 4

.data
lstate: .word   DFLT_STATE_STOP
ltimer: .word   DFLT_ALARM_TIME
pressedTime: .word 0
spacesOccured: .word 0 // spaces occured at the end of sequence 
countOfSequence: .word 0 // count of sequence input by user using gp21
buffer: .space LENGTH_OF_BUFFER
offset_of_buffer: .word 0