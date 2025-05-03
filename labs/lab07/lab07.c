#include <stdio.h>
#include <stdlib.h>
#include <math.h> 
#include <time.h>           // Required for timing in programme
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.
#include "pico/multicore.h" // Required for using multiple cores on the RP2040.
#include "hardware/structs/xip_ctrl.h"

#define FLAG_VALUE 123 // flag will be in buffer which will determine what core runs when
#define PI 3.14159265359 // constant PI value given to approximate degree of error
#define ITER_MAX 10000 // the limit of calculating pi

/**
 * @brief floatWallisProduct takes in a limit, and calculates the single-precision representation
 *        of the pi using Wallis Product
 * 
 * @param limit a limit for how much accuracy the wallis product should make
 * @return float  a float representation of the estimate of pi
 */
float floatWallisProduct(int limit) {
    float product = 1; // base case 1, since we will do product *= something, and 1 would mean product = something at first
    for (int i = 1; i <= limit; i++) { // include the limit in the calculation 
        product *= ( ((4.0f*i*i)/((4.0f*i*i)-1)) ); // calculate Wallis Product using with loop (2.0f == float)
    }
    return product * 2; ; // multiply product by two as wallis product calculates pi/2 and not pi
}

/**
 * @brief doubleWallisProduct takes in a limit, and calculates the double-precision representation
 *        of the pi using Wallis Product
 * 
 * @param limit a limit for how much accuracy the wallis product should make
 * @return double  a double representation of the estimate of pi
 */
double doubleWallisProduct(int limit) {
    double product = 1; // base case 1, since we will do product *= something, and 1 would mean product = something at first
    for (int i = 1; i <= limit; i++) { // include the limit in our calculation
        product *= ( ((4.0*i*i)/((4.0*i*i)-1)) ); // calculate Wallis Product using with loop (2.0 == double)
    }
    return product * 2; // multiply product by two as wallis product calculates pi/2 and not pi
}

/**
 * @brief core1_entry entry code for the second core (core #1) 
 *        Starts timer for estimating doubleWallisProduct
 * 
 */
void core1_entry() {
    double starting_cores_time = time_us_64(); // Take snapshot of timer and store
    double ansDouble = doubleWallisProduct(ITER_MAX);  // calculate pi using doubleWallisProduct
    double stopping_cores_time = time_us_64();  // Take snapshot of timer and store
    double core_1_total_time = (stopping_cores_time - starting_cores_time) / 1000.0; // calculate time that has past
    printf("The approximation error for the double-precision representation is %.11f\n", PI - ansDouble);
    printf("Pi calculation (single precision) of limit %d is %.11f\n", ITER_MAX, ansDouble); 
    printf("Approximate time taken for single (double-precision) function %f milliseconds\n\n", core_1_total_time);

    multicore_fifo_push_blocking(FLAG_VALUE); // when finished calculating let us calculate time needed for parallel code in main
}

/**
 * @brief timeSequential, a sequential funciton that times the two Wallis functions and prints output as 
 *        specified from our requirements
 * 
 */
void timeSequential() {

    double total_time_seq_1, total_time_seq_2; // used to time overall time taken
    total_time_seq_1 = time_us_64(); 
    // Code for sequential run goes here…
    printf("\nRunning Sequential code\n");

    double starting_time = time_us_64(); // Take snapshot of timer and store (timing floatWallisProduct itself)
    float firstAns = floatWallisProduct(ITER_MAX); // calculate pi using floatWallisProduct
    double stopping_time = time_us_64();  // Take snapshot of timer and store
    double timeFirst = (stopping_time - starting_time) / 1000.0; // calculate time that has past

    printf("The approximation error for the single-precision representation is %.11f\n", PI - firstAns);
    printf("Pi calculation (single precision) of limit %d is %.11f\n", ITER_MAX, firstAns); 
    printf("Approximate time taken for single (single-precision) function %f milliseconds\n\n", timeFirst);

    starting_time = time_us_64(); // timing doubleWallisProduct itself
    double secondAns = doubleWallisProduct(ITER_MAX);
    stopping_time = time_us_64();  // Take snapshot of timer and store
    double timeSecond = (stopping_time - starting_time) / 1000.0; // calculate time that has past

    printf("The approximation error for the double-precision representation is %.11f\n", PI - secondAns);
    printf("Pi calculation (single double) of limit %d is %.11f\n", ITER_MAX, secondAns); 
    printf("Approximate time taken for single (double-precision) function %f milliseconds\n", timeSecond);

    total_time_seq_2 = time_us_64(); // end of timing of total sequential code

    printf("Approximate time taken for application to run in sequential mode is %f milliseconds\n\n", (total_time_seq_2 - total_time_seq_1)/ 1000); // Display time taken for application to run in sequential mode
}

/**
 * @brief Function to get the enable status of the XIP cache
 * 
 * @return true if enables status is On
 * @return false if enable status is Off
 */
bool get_xip_cache_en() {
    unsigned int *address = (unsigned int *) XIP_CTRL_BASE;
    if ( *address & 0x1) {
        return true;
    }
    return false;
}

/**
 * @brief Function to set the enable status of the XIP cache
 * 
 * @param cache_en
 * @return true if set bits
 * @return false if cleared (unset bits)
 */
bool set_xip_cache_en(bool cache_en) {
    if (cache_en) {
        hw_set_bits(&xip_ctrl_hw->ctrl, 1); // set bit 0
        return true;
    }
    hw_clear_bits(&xip_ctrl_hw->ctrl, 1); // XIP_CTRL_BASE
    return false;
}

/**
 * @brief main function which executes sequential code and parallel code and times it using time_us_64() for highest accuracy
 * 
 * @return int 0 since no error should occur
 */
int main() {
    stdio_init_all();
    bool cache_en = set_xip_cache_en(false);
    cache_en = get_xip_cache_en(); // get cache (should be enabled)
    const int runTwice = 2; // constant variable that sets the limit of the run 2, 1 for running without cache and 1 for running with cache

    printf("Uncached Time");
    for (int i = 0; i < runTwice; i++) {
        if (i == 1) {
            cache_en = get_xip_cache_en(); // after running timeSequential funcion once, run it a second time with cache enabled
            set_xip_cache_en(!cache_en); // enable cache 
            printf("Cached Time");
        }
        timeSequential(); // do the sequential part of the code
    }
    
    printf("Uncached Time");
    cache_en = get_xip_cache_en(); // get cache (should be enabled)
    set_xip_cache_en(!cache_en); // disable xip cache
    for (int i = 0; i < runTwice; i++) {
        if (i == 1) {
            multicore_reset_core1(); // reset core and compute with cache
            cache_en = get_xip_cache_en(); // get the disabled cache
            set_xip_cache_en(!cache_en); // enable cache 
            printf("Cached Time");
        }
        // This example dispatches arbitrary functions to run on the second core
        // To do this we run a dispatcher on the second core that accepts a function
        // pointer and runs it
        multicore_launch_core1(core1_entry); // launch the second core for use of double pi calculation
    
        double total_time_par_1 = time_us_64();

        double starting_cores_time = time_us_64(); // Take snapshot of timer and store (timing floatWallisProduct itself)
        float ansFloat = floatWallisProduct(ITER_MAX); // calculate pi using floatWallisProduct
        double stopping_cores_time = time_us_64(); // Take snapshot of timer and store
        double core_0_total_time = (stopping_cores_time - starting_cores_time) / 1000.0; // calculate time that has past

        printf("\nRunning Parrallel code\n");
        printf("The approximation error for the double-precision representation is %.11f\n", PI - ansFloat);
        printf("Pi calculation (double precision) of limit %d is %.11f\n", ITER_MAX, ansFloat); 
        printf("Approximate time taken for single (single-precision) function %f milliseconds\n\n", core_0_total_time);

        uint32_t g = multicore_fifo_pop_blocking(); // block and wait until the stack has a number (123)
        if (g == FLAG_VALUE) { // if it's time to calculate time taken e.g. g == 123, calculate
            //printf("It's all gone well on core 0!\n\n");   
            double total_time_par_2 = time_us_64();
            printf("Approximate time taken for application to run in parrallel mode is %f milliseconds\n\n", (total_time_par_2 - total_time_par_1) / 1000.0); // Display time taken for application to run in sequential mode
        }
    }
    return 0;
}