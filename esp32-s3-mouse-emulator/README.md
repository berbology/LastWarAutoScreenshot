# esp32-s3-mouse-emulator

> **Status: not yet implemented.** This folder is a placeholder for planned
> firmware described below.

## Purpose

This folder will contain firmware for a USB HID hardware mouse emulator based
on the ESP32-S3 microcontroller. The device presents to the host operating
system as a genuine physical HID mouse — indistinguishable at the driver level
from a mouse plugged into a USB port.

## Why hardware HID

The current `LastWarAutoScreenshot` module moves the mouse via `SendInput`, a
Win32 software API. Some anti-cheat systems inspect the input source and can
distinguish software-injected events from hardware device events.

A hardware HID device eliminates this distinction: mouse input originates at
the USB HID layer, processed by the OS HID driver exactly as if the user
physically moved a mouse. This substantially reduces anti-cheat detection risk.

## Planned behaviour

- At runtime, the user will be able to select between the existing `SendInput`
  software approach and the hardware HID device from within the
  `Start-LWASConsole` configuration menu.
- Both methods share the same macro format and window-relative coordinate
  system — no macro changes are required when switching between them.
- The device connects via USB and is identified by a configurable VID/PID.

## Hardware

- **Microcontroller:** ESP32-S3 (dual-core, native USB support)
- **USB profile:** HID Mouse (Boot protocol)
- **Firmware framework:** TBD (Arduino / ESP-IDF / TinyUSB)

## Related

- [Root README — Features](../README.md#features) — ESP32-S3 listed as a
  planned feature
- [Configuration.md](../powershell-module/Docs/Configuration.md) — mouse
  control settings that will apply to both input methods
