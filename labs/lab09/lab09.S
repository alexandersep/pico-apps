#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb

.global main_asm
.global asm_adc_init
.global asm_adc_select_input
.global asm_adc_read
.global asm_unreset_block_wait
.global asm_reset_block
.global asm_adc_set_temp_sensor_enabled
.global asm_hw_set_bits

.align  4

.equ    DFLT_STATE_STRT, 1            // Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            // Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      // Specify the default alarm timeout

.equ    GPIO_LED_PIN, 25              // Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              // Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              // Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              // Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              // Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         // GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         // ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
    bl     asm_adc_init; // initialise adc 

    movs   r0, #4
    bl     asm_adc_select_input // select on board temperature board 
    
    movs   r0, #1
    bl     asm_adc_set_temp_sensor_enabled // temperature reading 
    
    bl     init_leds             // Same as previous labs
    bl     install_alrm_isr      // See below      
loop:
    bl     set_alarm             // Set a new alarm

    wfi
    
    ldr    r0, =raw_temp    // read in from shared memory
    ldr    r0, [r0]
    bl     asm_convert_raw_temp_to_celsius // convert to celsius and print out answer

    b      loop                  // Always branch back to loop

@ Subroutine used to initialise the PI Pico built-in LED (optional led to see when the conversion to celsius happens using leds)
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
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
    push   {lr}                            // Store the link register to the stack as we will call nested subroutines

    ldr    r1, =lstate                     // load address of alarm state
    ldr    r1, [r1]                        // read the address of the alarm state
    cmp    r1, #1                          // If alarm occuring
    bne    alarmNotOccuring

    ldr    r0, =msg1                       // load message from memory to register
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

    ldr    r1, =raw_temp 
    bl     asm_adc_read
    str    r0, [r1]

    pop    {pc}                         // Pop the link register from the stack to the program counter

// First function of SVC subroutine - turn on the LED
subtoggle:
    push   {lr}               // Store the link register to the stack as we will call nested subroutines

    movs   r0, #GPIO_LED_PIN  // Set the LED GPIO pin number to r0 for use by asm_gpio_get
    bl     asm_gpio_get       // branch and get the pin if it's on/off
    movs   r1, #1             // Used for EOR mask next line
    eors   r1, r0, r1         // toggle the led off/on using EOR operation, On if off, and Off if on
    movs   r0, #GPIO_LED_PIN  // Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl     asm_gpio_put       // Update the the value of the LED GPIO pin (based on value in r1)

    pop    {pc}               // Pop the link register from the stack to the program counter

//
// Installs an isr in the RAM vector table and enables the correct interrupt
// parameters:
// R0: The address of the isr
// R1: The correct bit value in the vector table
// R2: The offset for the address in the vector table
//
install_isr:
    push   {r0-r3, lr}                                 // Store the parameters and link register to the stack as we will call nested subroutines

    ldr    r3, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr    r3, [r3]                                    // load address from memory
    add    r3, r2                                      // load addres of gpio_isr
    str    r0, [r3]                                    // store this address in memory to be used when interrupt occurs
    ldr    r3, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   // Disable the IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) 1 << 13 vector table
    str    r1, [r3]                                    // Store the correct bit value in the vector table
    ldr    r3, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   // Enable the IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    str    r1, [r3]                                    // Store the correct bit value in the vector table

    pop    {r0-r3, pc}                                 // Pop the parameters and link register from the stack to the program counter

/* Brief: Enable ADC (setting bit 0 to 1)
 */
asm_adc_init:
    push   {r0-r2, lr}

    // ADC is in an unknown state. We should start by resetting it
    ldr    r0, =1 // bit 0
    bl     asm_reset_block
    ldr    r0, =1 // bit 0
    bl     asm_unreset_block_wait

    // Now turn it back on. Staging of clock etc is handled internally
    ldr    r0, =ADC_BASE // base for ADC
    ldr    r1, =1 // bit 0
    str    r1, [r0, #0x0] // offset 0

    ldr    r1, =0x00000100 // check READY bit 8

while_waiting_for_few_cycles:
    ldr    r2, [r0] // read from address
    ands   r2, r1  // if address has not set the bits llop
    cmp    r2, #1 
    bne    end_of_poll_waiting
    
    bl     asm_tight_loop_contents // loop and wait for set

    b      while_waiting_for_few_cycles
end_of_poll_waiting: // leave if set

    pop    {r0-r2, pc}

/* brief: Enable/Disable onboard temperature sensor
 *
 * @param R0: enable Set true to power on the onboard temperature sensor, false to power off.
 */
asm_adc_set_temp_sensor_enabled: 
    push   {r0-r1, lr}

    cmp    r0, #1 // if (enable) set bits
    bne    not_enabled

    // set bits
    ldr    r0, =ADC_BASE // // load address of ADC base (0x0 offset)
    ldr    r1, =2 // enable TS bit 0
    bl     asm_hw_set_bits

    b      enabled
not_enabled: // else disable bits

    // clear bits
    ldr    r0, =ADC_BASE 
    ldr    r1, =2
    bl     asm_hw_clear_bits

enabled:

    pop    {r0-r1, pc}

/* brief:  ADC input select
 *
 * Select an ADC input. 0...3 are GPIOs 26...29 respectively.
 * Input 4 is the onboard temperature sensor. Multiple concurrency possible
 *
 * @param R0: input Input to select.
 */
asm_adc_select_input:
    push   {r0-r3, lr}

    movs   r1, r0 // move to proper position for subroutine
    ldr    r0, =ADC_BASE // base for ADC
    lsls   r1, #12 // move to bit position 14:12
    ldr    r2, =0x00007000 // ALL AINSIL bits set 
    bl     asm_hw_write_masked

    pop    {r0-r3, pc}

/* brief: Perform a single conversion 
 *        Performs an ADC conversion, waits for the result, 
 *        and then returns it.
 *
 * return R0: Result of the conversion.
 */
asm_adc_read:
    push   {r1-r2, lr}

    // set bits
    ldr    r0, =ADC_BASE // load address of ADC base (0x0 offset)
    ldr    r1, =4 // START_ONCE for ADC
    bl     asm_hw_set_bits

    ldr    r1, =0x00000100 // READY bit 8
while_waiting_for_ninety_six_cycle:
    ldr    r2, [r0] // read from address
    ands   r2, r1  // if address has not set the bits llop
    cmp    r2, #0
    bne    end_of_poll_waiting_ninety_six_cycles

    bl     asm_tight_loop_contents // loop and wait for set

    b      while_waiting_for_ninety_six_cycle // leave if set

end_of_poll_waiting_ninety_six_cycles:
    ldr    r1, =0x04 // 0x04 offset results
    ldr    r0, [r0, r1]
    pop    {r1-r2, pc}

/* brief: Set the specified bits to 1 in a HW register
 *
 * @param R0: addr Address of writable register
 * @param R1: mask Bit-mask specifying bits to set
 */
asm_hw_set_bits:
    push   {r0-r2, lr}

    // set bits 
    ldr    r2, [r0] // read address from memory
    orrs   r2, r1 // mask with address 
    str    r2, [r0] // store and set the bit
    
    pop    {r0-r2, pc}

/* brief: Clear the specified bits to 1 in a HW register
 *
 * @param R0: addr Address of writable register
 * @param R1: mask Bit-mask specifying bits to set
 */
asm_hw_clear_bits:
    push   {r0-r2, lr}

    // clear bits
    ldr    r2, [r0]
    bics   r2, r1 // clear bit 
    str    r2, [r0]
    
    pop    {r0-r2, pc}

/* brief: Set new values for a sub-set of the bits in a HW register
 *
 * Sets destination bits to values specified in \p values, if and only if corresponding bit in \p write_mask is set
 *
 * Note: this method allows safe concurrent modification of *different* bits of
 * a register, but multiple concurrent access to the same bits is still unsafe.
 *
 * @param R0: addr Address of writable register
 * @param R1: values Bits values
 * @param R2: write_mask Mask of bits to change
 */
asm_hw_write_masked:
    push   {r0-r3, lr}

    ldr    r3, [r0]
    eors   r1, r3 // mask with desired bits
    ands   r1, r2 // find common bits
    bl     asm_hw_xor_bits

    pop    {r0-r3, pc}

/*  brief: Flip the specified bits in a HW register
 *
 * @param R0: addr Address of writable register
 * @param R1: mask Bit-mask specifying bits to invert
 */
asm_hw_xor_bits:
    push   {r0-r2, lr}

    ldr    r2, [r0]
    eors   r1, r2
    str    r1, [r0] // set AINSIL 

    pop    {r0-r2, pc}

/* brief: Reset the specified HW blocks
 *
 * @param R0: bits Bit pattern indicating blocks to reset
 */
asm_reset_block:
    push   {r0-r3, lr}

    movs   r1, r0
    ldr    r0, =RESETS_BASE // load address of reset base (0x0 offset)
    bl     asm_hw_set_bits

    pop    {r0-r3, pc}

/* brief: bring specified HW blocks out of reset
 *
 * @param R0: bits Bit pattern indicating blocks to unreset
 */
asm_unreset_block_wait:
    push   {r0-r2, lr}

    // clear bits
    movs   r1, r0 // move parameter to properly place for subroutine
    ldr    r0, =RESETS_BASE // load address of reset base (0x0 offset)
    bl     asm_hw_clear_bits 

    adds   r0, #0x8 // 0x08 RESET_DONE

while_waiting_for_clear:  // while (not cleared bits) 
    ldr    r2, [r0] // load from memory 
    mvns   r2, r2 // find ~ (complement) of RESTS_BASE + 0x8 (reset done)
    ands   r0, r1 // check if bit is set
    cmp    r0, #1 // is set?
    bne    end_of_waiting_for_clear 

    bl     asm_tight_loop_contents // loop and wait for unset

    b      while_waiting_for_clear
end_of_waiting_for_clear: // bit not set end

    pop    {r0-r2, pc}

/** brief: tight loop to wait for asm_unreset_block_wait to finish clearing bit
 */
asm_tight_loop_contents:
    push   {lr}

    pop    {pc}

@ Set data alignment
.data
    .align 4

.align 4
msg1:   .asciz "Alarm Occuring!\n"
msg2:  .asciz "The Temperature is %f degrees Celsius\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME
raw_temp: .word 0
