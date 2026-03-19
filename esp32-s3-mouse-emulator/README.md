# esp32-s3-mouse-emulator

> **Status: not yet implemented.** This folder is a placeholder for planned firmware.

---

## Purpose

This folder will contain firmware for a USB HID hardware mouse emulator based
on the ESP32-S3 microcontroller.

The device presents to the operating system as a genuine physical HID mouse.
When active, it provides an alternative input method to the existing `SendInput`
software approach used by the module today. Both methods will be selectable at
runtime.

## Why hardware HID?

Input generated via `SendInput` (Win32 API) originates in user-space and can
be fingerprinted by anti-cheat systems that distinguish software-synthesised
events from real hardware input. A device presenting as a genuine USB HID mouse
delivers input at the driver level, indistinguishable from a physical mouse to
any software observing the input stream. This substantially reduces the risk of
detection.

## Planned behaviour

- The ESP32-S3 enumerates as a standard USB HID mouse when connected.
- The module will detect the device and offer a toggle in the configuration UI.
- Both `SendInput` (software) and hardware HID modes will be supported
  simultaneously; the active mode is switchable without restarting the app.
- When hardware HID is active, all mouse movements and clicks are relayed to
  the device over a serial or USB connection, and the device issues the
  corresponding HID reports.
