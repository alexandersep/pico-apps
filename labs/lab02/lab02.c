//#define WOKWI             // Uncomment if running on Wokwi RP2040 emulator.

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.

#define PI 3.14159265359 // constant PI value given to approximate degree of error

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
        product *= ( ((2.0f*i)/((2*i)-1)) * ((2.0f*i)/((2*i)+1)) ); // calculate Wallis Product using with loop (2.0f == float)
    }
    float floatPi = product * 2;  // keep in variable as will be calculated more than once
    // approximate to 11 decimal points as in origianl value to compare with
    printf("The approximation error for the single-precision representation is %.11f\n", PI - floatPi);
    return floatPi; // multiply product by two as wallis product calculates pi/2 and not pi
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
        product *= ( ((2.0*i)/((2*i)-1)) * ((2.0*i)/((2*i)+1)) ); // calculate Wallis Product using with loop (2.0 == double)
    }
    double doublePi = product * 2; // keep in variable as will be calculated more than once
    // approximate to 11 decimal points as in origianl value to compare with
    printf("The approximation error for the double-precision representation is %.11f\n", PI - doublePi);
    return doublePi; // multiply product by two as wallis product calculates pi/2 and not pi
}

/**
 * @brief EXAMPLE - HELLO_C
 *        Simple example to initialise the IOs and then 
 *        print a "Hello World!" message to the console.
 * 
 * @return int  Application return code (zero for success).
 */
int main() {

#ifndef WOKWI
    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi
    stdio_init_all();
#endif

    int limit = 100000; // limit for wallis product series
    // Print a console message to inform user what's going on.
    // approximate to 11 decimal points as in origianl value to compare with
    printf("The given PI value to compare is %.11f\n", PI);
    printf("PI calculation from Wallis Product calculation for floats is %.11f\n", floatWallisProduct(limit));
    printf("PI calculation from Wallis Product calculation for doubles is %.11f\n", doubleWallisProduct(limit));

    // Returning zero indicates everything went okay.
    return 0;
}