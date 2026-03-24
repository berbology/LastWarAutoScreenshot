# AI AGENTS IGNORE THIS FILE

Create powershell-module\docs\hardwareemulationplandoc_2.md.
Add phases and tasks to using the same high level of detail as the phases already completed in  powershell-module\docs\hardwareemulationplandoc_2.md.
Use the same format in the plan as the previous phases, using check boxes for tasks and numbering of the format 1, 2.1, 3.3.1 etc.
I want an idiot-proof full plan of tasks laid out in hardwareemulationplandoc_1.md.
If you need to ask clarifying questions before finalising the plan then do.
If there are multiple approaches to a step then give pros and cons of each, and justifications for the approach you prefer.
I will choose an approach or ask questions of you in return.

Add the following features:
Make it possible to switch between current software mouse movement capability and hardware HID mouse movement via esp32 S3 controller (platform.io device `4d_systems_esp32s3_gen4_r8n16`), plugged into a USB port. The idea behind this method of moving the mouse is to reduce likelihood of tripping anti-cheat measures since it won't need to use SendInput for mouse control.

User needs to be able to toggle between the current software mouse control or the ESP S3 method of operation in console app main menu. Add a configuration setting for this. If Start-LWSConsole runs and no device is inserted but config set to use hardware, show warning no device found and switch config and app to software mode.
If the hardware option is toggled on in main menu, check that the device is detected or prompt the user to insert it to continue.
A main menu item should be added to the console app called "Toggle mouse emulation" (Mode)", where "Mode" is either "Hardware" or "Software".
If "Hardware" mode is toggled on and USB device not detected and ready, prompt user to insert device and retry or cancel to return to software mode.
During a macro execution, the S3 and module need to communicate with each other so the module can tell the device where to move, when to click etc. Give me options with pros and cons and your preference for this approach.

I envisage a scenario where on "Run Macro" when a mouse movement step is reached, the commands to move the mouse (left-click, click-drag etc) are sent to the S3 which performs the movements and returns success/failure with any errors returned for logging or, where relevant, display to the user.
Sensible retry logic should be used in cases where the S3 becomes unavailable during execution with prompts to the user after n retries asking them to try unplugging and plugging in the device again.
We need to include the ability to write the firmware to an S3, setting a friendly name for an S3 that can be used with the module when installing the firmware to it. What are our options for doing this?
I think we should make the device name something like "LWAS_Mouse_Emulator_ABCDEF" where ABCDE" is a random hex value.
If multiple devices with valid names are detected, display a list for the user to choose which one to use with the module.
Since storage on the device is limited, device logging should be done the same way it is currently is in the module, except in cases where the device cannot contact the PC , for some reason. Ensure device logs don't grow too large and fill its storage.
We will use cpp language for the device and platformio and not arduino ide or ESP ide so plan accordingly.
As well as flashing the firmware via the console app, Provide the option of doing so via a local web app which can be spun up via public powershell function.
Use unity testing framework for unit testing of esp code. Add platform.ini environments for both esp32dev and native to test directly on the hardware and on the pc, respectively. Below are examples of this from the internet:

```
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
test_build_src = true
monitor_speed = 115200

[env:native]
platform = native
test_build_src = false
test_framework = unity
```

Unit tests should be placed in `esp32-s3-mouse-emulator\test` folder and, like all code, always employ best practices such as:

* Use #ifdef guards to conditionally compile test-specific code.
* Mock hardware interactions (e.g., I2C, GPIO) using libraries like ArduinoFake for more complex testing.
* Use test_ignore to skip specific test files (e.g., test_ignore = test_desktop).

As with the rest of the codebase, do not add phase of or task numbers to comments. Do not add decorations to comments, keep them simple-looking
Let me know if there are any flaws or holes in the plan that need to be addressed and give me options for them
