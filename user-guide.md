# Emulator User Guide

<!--- Group info -->
<p align="center">
UNSW DESN200 23T2 (COMP)
</p>
<p align="center">
Group: "Group H"
</p>
<p align="center">
Members:
</p>
<center>Siyu Qiu (z5348946)</center>
<center>Muzhi Wang (z5340914)</center>
<center>Hanyang Xu (z5254111)</center>
<center>Shaoqiu Lyu (z5325799)</center>
<!--- Group info -->

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Selecting Input/Output Components](#selecting-inputoutput-components)
5. [Testing Functionality](#testing-functionality)
6. [Usage](#usage)
7. [Troubleshooting](#troubleshooting)
8. [Assumptions](#assumptions)

## Introduction

This is the DESN2000 Lift Emulator system. Developed using AVR Assembly Atmega2560 Instruction Set and an Arduino Board.

By default, the Lift Emulator starts on "Floor 1" with the doors 'closed'.

**For LCD Screen:**
The Lift Emulator displays the current floor, direction and next floor using the LCD screen with a simple information.

**For Keypad:**
The Keypad is used to 'call' floors that the Lift will travel up or down to. The "called" floor will arrive during the elevator operation according to the procedure. There are 10 floors numbered 0-9.

The '*' key is the Emergency Button.

The '#' key is the long time holding Button.

**For RESET button:**
The reset button is a red button on the left buttom corner. When the reset button is pressed the entire elevator system will be reseted including the emergency state.

**For green button:**
The left push button (PB1) is the 'Open' button, and the right push button (PB0) is the 'Close' button.

**For Strobe LED:**
The strobe LED will be turned on when the emergency state is activated.

**For LED Bar:**
The LED Bar will light up the corresponding grid on the corresponding floor. And it will be blinking when the door is open.

>For more information, please check Selecting Input/Output Components Part or Usage Part.


## Installation
#### Board Setup
![Board setup](./images/board_setup.jpeg)
**Important**
User do not need to connect by themselves. However, if a problem such as a loose cable causes the connection to fail, check out this section to try to fix it yourself.
Please check [board test procedure connection](./board_procedure_connection.pdf) for wire connections.

Here are some general ports connections for Board Setting up.
| Devices | Pins |
| :---:| :---:|
| LCD | PF0 - PF7 => D0 - D7 <br> PE5 => BL <br> PA4 => BE <br> PA5 => RW <br> PA6 => E <br> PA7 => RS|
| Motor | PE2 => Mot <br> TDX2 => OpO <br> PA3 => LED <br> +5V => OpE |
| Key Pad | PL0 - PL3 => C3 - C0 <br> PL4 - PL7 => R3 - R0 |
| LED Bar| PC0 - PC7 => LED2 - LED9 <br> PG2 - PG3 => LED0 - LED1 |
| Push Button | RDX3 - PB1 <br> RDX4 - PB0 |

After connecting the circuit, the user needs to connect the board and the computer together to detect which port the board belongs to, and adjust and initialize according to different ports.

## Configuration
if you want to check the configuration or some more infromations for the Board, please check [ATmega2560 datasheet](./ATmega2560datasheet.pdf), [AVR-Instruction-Set](./AVR-Instruction-Set.pdf) and [AVR-Assembler-Guide](./AVR-Assembler-Guide.pdf).

## Selecting Input/Output Components

**For keypad:**
![KEYPAD](./images/KEYPAD.jpeg)
According to this picture, if user want the lift stop at which floor, press the corresponding button, first floor press 1, second floor for 2 and the highest floor (10th floor) press 0 and so on.

For the emergency state, press '*'. Pressing it stops all other operations and the Lift will down to Floor 1 immediatly and open the door to allow users to leave the elevator. Pressing it again, leaves Emergency Mode.

The '#' key is the long time holding Button, pressing during the door is holding to keep long time holding. Pressing the close door button(PB0) will cancel the long-time holding state only except the activating the emergency state.

'A', 'B', 'C' and 'D' is not useful for the whole project.

> press 1 -> First floor.

> press 2 -> Second floor.

> press 3-> Third floor.

> press 4 -> Fourth floor.

> press 5 -> Fifth floor.

> press 6 -> sixth floor.

> press 7 -> seventh floor.

> press 8 -> eighth floor.

> press 9 -> ninth floor.

> press 0 -> tenth floor.

> press * -> Emergency state.

> press # -> long-time holding state.

**For LCD:**
![LCD](./images/LCD.jpeg)
* In the default mode, the LCD display will indicate the current floor and next stop with the message:

    | Current floor X |
    | :---:|
    | Next stop Y Z |

    where:  
    'X' is the current floor number  
    'Y' is the next floor the lift will stop, if no floors need to stop, remaining empty  
    'Z' is shown the lift is going UP or DOWN currently, where 'U' is meaning going **UP** and 'D' is meaning going **DOWN**.  
* In the Emergency mode, the LCD will display the following message the entire time:

    | Emergency|
    | :---:|
    | Call 000 |

    until the '*' button is pressed again to leave Emergency mode.

**For LED Bar:**
![LED Bar](./images/LED_Bar.jpeg)
* The LED Bar display serves three things:
    1. Indicates the floor that you are currently on.
    2. Indicates the status of holding
    From the first graph below, we can know the lift is currently on the third floor. And the second gragh is shown the lift is on the fourth floor. If the door is open on the fourth floor, the LED Bar will be blinking together from the first floor to current floor.
    Red indicates that the LED is lit, which that it is on.
    3. Indicates the current direction. If the lift is going up, the most upper LED Bar (10th floor) will be blinked(like the Graph 3 and 4 below) and if the list is going down, the most lower LED Bar (1st floor) will be blinked(like the Graph 5 and 6 below).
    ![example for LED Bar](./images/example_LED_Bar.jpeg)
    ![example for LED Bar](./images/going_down.jpeg)


**For Motor:**
![Motor](./images/motor.jpeg)
* the MOTOR will run at 30% speed for 1 second to indicate the lift is opening when the door is automatically opening or press the open door button(PB1).
* the MOTOR will run at 80% speed for 1 second to indicate the lift is closing when the door is automatically closing or press the close door button(PB0).

**For Button:**
![Button](./images/button.jpeg)
The PB0 button is close door button which is a green button at the upper right corner of the keypad. This button uses to activate the close door motor to close the elevator door.  
The PB1 button is open door button which is a green button at the upper left corner of the keypad. This button uses to activate the open door motor to open the elevator door.

**For Strobe LED:**  
![Strobe LED](./images/Strobe_LED.jpeg)  
The strobe LED will flash when the emergency state is activated. It has three flashing modes.
1. When the elevator is moving down under the emergency state the strobe LED will flash with same frequency (2 seconds per time) as LED bars turn off, which is the flashing mode 1.
2. When the elevator reaches the first floor the strobe LED will flash as 1 second per time during open - hold - close state, which is the flashing mode 2.
3. After close the door on the first floor, the strobe LED will flash rapidly until the emergency state end, which is the flashing mode 3.

## Testing Functionality
After connected and initialised everything, testing functionality is below.
1. At the normal state, the maximum number is 10. Users can press the number on the keypad from 0-9 to enter the number they like. In this situation, other keys like A,B,C,D and '#' will not work if you press them. And if press '*' will start emergency state.
2. When the door open, we need to test the following cases:  
&emsp;a. Check if the lift will stops(holding) for three seconds.  
&emsp;b. Check repressing the opening button(PB1) will reset the busy waiting for another more 3 seconds.  
&emsp;c. Check if keep holding the door open. The door will keep holding.  
&emsp;d. Check if press the close button while the lift is holding, the door will close immediately (the motor will turn at the speed of closing).  
&emsp;e. Check if press the close button(PB0) when the lift opens, and the elevator will close after opening the door(after 1 second).  
3. When press ' * ', it will be the emergency state. And check the following situations:  
&emsp;a. When state are in opening, the door will immediately close and go to the first floor directly.  
&emsp;b. If the '*' is not pressed again to deactivate the emergency state, the other buttons will be blocked.  
&emsp;c. After the emergency state, the elevator will start moving again. But the previous contents will be cleared, and the elevator will not stop on any floor unless the button on the other floor is re-pressed.  
&emsp;d. When state are in moving, the lift will first move to the next nearest floor, and door maintaining close, and then down to the first floor to open the door.  
&emsp;e. When state are in holding, the door will close immediately.  
&emsp;f. When state are in moving and direction is going up, the elevator will move to the nearest floor and then go down.  
4. When the lift is moving, we need to check:  
if we press a button for the other floor, it will stop at that floor.  
&emsp;a. IF the lift is going up, the most upper LED Bar should be blinking.  
&emsp;b. IF the lift is going down, the most lower LED Bar should be blinking.  
&emsp;c. For example: if the current floor is 4, the lift is going up and LCD shows the next stop is 7, if we press 6, the LCD will change to 6 and lift will stop at 6 floor first and then stop at the 7.


## Usage
* To move up or down floors, press the button that corresponds to the floor.
* This will then indicate that the lift should stop on that floor on it's way up or down to higher or lower floors.
* When the lift stop at some floors:
    * the door will open for 1 second
    * holding the door open for 3 seconds
    * the door will close for 1 second
    * the LED Bar will blinking when the lift stops
* Pressing the key that corresponds to the current floor will perform no actions.
* To enter the Emergency mode, press the '*' button.
* To leave the emergency mode, press the '*' button again when the lift is stopping at 1st floor or halting.
* To enter Long time holding mode, press the '#' button when the lift is stopping at certain floor.
* To leave the Long time holding mode, press the close door button to return normal movement. Or the '*' button for Emergency mode.

For example starting from Floor 1:
* press 9 to go to the 9th floor.
* while the lift is travelling upward, press 6 while on Floor 2
* once the lift reaches Floor 6 it will stop and open the Lift doors to allow people to leave/enter the lift.
* It will then continue upward on it's journey to Floor 9
* If the lift is going up at the Floor 4, the user press '3', the lift will stop after going up to Floor 10.
* If no body ask for the elevator, it will keep moving from 1 to 10 and then 10 to 1.


## Troubleshooting

1. If it shows that you can not find COMX, check whether the circuit is connected correctly or whether the cable is loose according to the Installation part.
2. If build failed is displayed, check whether the emulator is connected to power.
3. If shows time out, please disconnect and reconnect.
4. If some lines disconnect, please check [board test procedure connection](./board_procedure_connection.pdf) to make sure nothing error for lines.
5. In extreme cases, if the equipment has problems with line aging or poor contact, users need to use their own voltmeter to test.



## Assumptions

1. If press open when in the holding state, will hold another 3 seconds again.
2. When door is closing and press open, start a new 5 seconds from open state.
3. When door is opening and press close, skips the holding 3 seconds part and executes the close state.
4. When the elevator is in the holding state(i.e in the 3 seoncds) and press the close door button, the elevator will skip rest holding time and close the door directly.
5. When the elevator is in the holding state(i.e in the 3 seoncds) and press the open door button, the elevator will hold another 3 seconds again.
6. When the elevator is in the holding state(i.e in the 3 seoncds) and holding the open door button, after the button released, the elevator will hold another 3 seconds. 
7. The floor movement direction is displayed on the second line of LCD (i.e. the U represents the direction Up and the D represents the direction Down).
8. The floor movement direction is displayed on the LED as well. When moving upwards, blink the most upper LED bar. When mobing downwards, blink the most lower LED bar.
9. When in holding state, the LED Bar will blanking together from the first floor to current floor.
10. When in open state and press emergency, the door will close immediately after open.(which means no holding)
11. The Strobe LED will blink with same frequency as elevator moving down before reaching the first floor during the emergency state. as the elevator arrives the first floor, when the door opening/closing and the lift holding, the strobe LED blink once per second. After closing the Strobe LED will flash rapidly.
12. As the emergency state activated, when the elevator is moving up, the elevator will go up to the nearest floor first then do not open the door and down to the first floor. If direction is down, elevator will move to the first floor directly. For example, if the emergency state is activated when the elevator is moving from fifth floor to sixth floor, the elevator will arrive the sixth floor first then go to the first floor directly.
13. ABCD on keypad is not used for the whole project. Therefore, pressing A, B, C, and D will cause nothing change in the elevator system.
14. The elevator will maintain moving state up and down between floors 1 to 10, even if no body requires for the elevator, it will keep moving from 1 to 10 and then 10 to 1.
15. Long time holding button can only be effected in the holding state.
16. If the close door button or emergency button are pressed, the long-time holding state will be exited.
17. We use some delay functions to perform the debounce. Therefore, LED bars, Strobe LED and motor may behave slow response for a short time when activate related functions.
18. When we give the board to user, we assume the line connection have already been setup first.
19. When the motor stop moving, the lift immediately moving.
20. Because of the unstable signal from the buttons, the action of the motor will not be 100% exactly as what we expected. (may not detect the signals)
21. When you holding the open button when the lift is holding, and you press the close button, the door will close immediately.
