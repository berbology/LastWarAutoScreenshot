# Hardware Mouse Emulation Plan — ESP32-S3

## Overview

This document plans the implementation of hardware USB HID mouse emulation using the ESP32-S3
DevKitC-1 microcontroller (`esp32-s3-devkitc-1` in PlatformIO). The device
is plugged into a free USB port and presents to Windows as a genuine physical USB HID mouse.
Mouse movements and clicks execute on the device instead of via the `SendInput` Win32 API,
substantially reducing anti-cheat detection risk because input originates at the USB driver level,
indistinguishable from a physical mouse.

The existing `SendInput`-based software path is fully retained and remains the default. A
configuration key and main menu toggle allow the user to switch between Software and Hardware
modes at runtime.

---

## Confirmed Design Decisions

All decisions below are finalised. The plan tasks reflect these choices throughout.

| Decision | Choice |
|---|---|
| D1: Module-to-device communication | USB CDC serial (virtual COM port alongside HID mouse — composite device) |
| D2: Mouse command granularity | Host calculates all Bezier waypoints; sends individual `MOVE dx dy` commands |
| D3: Command protocol format | Text/ASCII, newline-delimited |
| D4: HID delta range handling | Firmware splits large deltas internally; PowerShell sends unclamped values |
| D5: End-user flashing tool | Bundled `esptool.exe` (listed as binary in `.gitattributes`) |
| D6: Web app flashing | Browser-side via `esp-web-tools` (as used by WLED, Tasmota, ESPHome) |
| D7: Protocol version mismatch | Major version mismatch = hard failure; minor version mismatch = warning, continue |
| D8: Pointer acceleration | Detect via registry at toggle time; display a clear warning if active |

Additional clarifications:

- **Startup device check (Q3):** On console app start, if config is Hardware mode, perform a
  fast WMI device-name enumeration only. Do not open a serial connection. If no device with a
  valid `LWAS_Mouse_Emulator_*` name is found, display a startup warning. No connection
  latency is acceptable at startup.
- **Multiple device selection (Q4):** Always prompt when more than one LWAS device is detected.
  `PreferredDeviceName` in config is informational (shown in the prompt as the previous choice)
  but never auto-selects silently.
- **Firmware binaries in git (Q5):** Committed to `esp32-s3-mouse-emulator/firmware/` and
  listed as binary in `.gitattributes`.
- **Scroll wheel:** Not required as a macro action. The `SCROLL` command is not included in the
  protocol in this phase; it can be added later.
- **Web app naming flow:** The web app (`esp-web-tools`) flashes firmware only. The device
  auto-generates a random 6-character hex name on first boot via `esp_random()`. If the user
  wants a specific name, they use the console app's `"Flash device firmware"` screen which
  handles the full flash-and-name workflow, or the `"Rename connected device"` option in the
  hardware device screen.

---

## Protocol Reference

Commands sent from module to device (one per line, `\n`-terminated):

| Command | Arguments | Description |
|---|---|---|
| `MOVE` | `dx dy` | Relative mouse delta; signed integers; firmware splits internally if outside ±127 |
| `CLICK` | `L\|R\|M hold_ms` | Click named button; hold for `hold_ms` ms; R and M return `ACK ERR not_implemented` in this phase |
| `BUTTON_DOWN` | `L` | Press and hold left button; `R`/`M` return `ACK ERR not_implemented` in this phase |
| `BUTTON_UP` | `L` | Release a previously held left button; `R`/`M` return `ACK ERR not_implemented` in this phase |
| `ABORT` | — | Immediately release all held buttons and cancel any in-progress click hold; safe to call at any time |
| `PING` | — | Heartbeat |
| `VER` | — | Request firmware protocol version |
| `NAME` | — | Request full device name |
| `SETNAME` | `suffix` | Set 6-character uppercase hex name suffix; stored in NVS |

> **Design note — LOG messages and Invoke-HardwareMouseCommand:** The firmware may emit
> `LOG level message` lines asynchronously at any time, interleaved with command responses.
> `Invoke-HardwareMouseCommand` must loop discarding lines that begin with `"LOG "`, forwarding
> each to `Write-LastWarLog` at the corresponding level, until it receives a non-LOG response
> line. LOG messages are retained and forwarded (not silently discarded) so that firmware
> diagnostic output appears in the module log and is available for troubleshooting.

Responses sent from device to module:

| Response | Description |
|---|---|
| `ACK OK` | Command executed successfully |
| `ACK ERR <reason>` | Command failed; `reason` is a short lowercase token |
| `PONG` | Heartbeat reply |
| `VER <version>` | Firmware protocol version (format `major.minor.patch`) |
| `NAME <full_name>` | Full device name (e.g. `LWAS_Mouse_Emulator_A3F2C9`) |
| `LOG <level> <message>` | Device sends a log entry to the host; forwarded to `Write-LastWarLog` |

Log levels: `VERBOSE`, `INFO`, `WARNING`, `ERROR`

---

## Scope

**Included:**

- ESP32-S3 PlatformIO C++ project (`esp32-s3-mouse-emulator/`)
- USB composite device firmware: HID mouse + CDC serial via TinyUSB
- Text-based serial command protocol (MOVE, CLICK L, BUTTON_DOWN L, BUTTON_UP L, ABORT, PING, VER, NAME, SETNAME)
- Device naming: `LWAS_Mouse_Emulator_XXXXXX` (6 random uppercase hex chars, auto-generated
  in NVS on first boot; configurable via SETNAME)
- Device logging: forward to host via CDC serial; LittleFS local fallback when host unavailable
- PowerShell `MouseEmulation` config section (`Mode`, `PreferredDeviceName`, timeout, retries)
- Fast WMI device-name enumeration at startup (no serial connection); full connection only on
  explicit toggle or macro run
- Multiple device selection prompt (always shown when more than one LWAS device is detected)
- Hardware dispatch path for `Invoke-MouseMovePath`, `Invoke-MouseClick`, `Invoke-MouseDragClick`
- Retry logic with user prompts when the device becomes unavailable during execution
- Pointer acceleration registry check when toggling to Hardware mode
- Console app: `"Toggle mouse emulation (Software|Hardware)"` main menu item
- Console app: `Show-HardwareDeviceScreen` (device selection and rename-connected-device)
- Console app: `"Flash device firmware"` main menu item → `Show-FirmwareFlashScreen`
  (flash via bundled `esptool.exe` + optional SETNAME step)
- `Start-LWASFirmwareWebApp` public function (localhost HTTP server + browser launch via
  `esp-web-tools`; flash only — no naming step in the web app)
- Startup warning when config is Hardware mode but no LWAS device name is detected via WMI
- Unity test environments: `esp32s3` (hardware) and `native` (PC via ArduinoFake)
- `esptool.exe` and firmware `.bin` files listed as binary in `.gitattributes`
- Full Pester test coverage for all new PowerShell code
- Documentation

**Explicitly out of scope:**

- SCROLL command and scroll wheel macro action (deferred)
- Right-click, middle-click, extra mouse buttons (deferred)
- BLE or Wi-Fi transport
- Linux or macOS support
- Absolute HID mouse reports (relative delta only)
- Simultaneous multi-device operation
- Firmware OTA update (host-initiated flash only)

---

## Phase 1: ESP32-S3 Firmware Foundation

### Architecture decisions (recorded for reference)

- **Framework:** Arduino framework via PlatformIO. Better TinyUSB composite device support and
  ArduinoFake availability for native tests than ESP-IDF for this use case.
- **USB mode:** TinyUSB composite device (HID mouse + CDC ACM serial). Build flags
  `-D ARDUINO_USB_MODE=0` (use TinyUSB, not the USB-Serial bridge) and
  `-D ARDUINO_USB_CDC_ON_BOOT=0` (prevent bootloader CDC conflicting with the composite device).
- **Protocol versioning:** `PROTOCOL_MAJOR`, `PROTOCOL_MINOR`, `PROTOCOL_PATCH` defined
  separately. Connection check: major version mismatch = hard failure; minor version mismatch =
  warning, continue; patch ignored. The full version string sent in the `VER` response is
  `"major.minor.patch"`.
- **NVS:** Device name suffix stored in NVS namespace `"lwas_config"`. Survives firmware
  updates when the partition table is unchanged.
- **LittleFS:** Local log storage when host is unavailable. Rotated when file size exceeds
  `LOG_FILE_MAX_SIZE_BYTES`.

---

1. [ ] Create the PlatformIO project structure

   - [ ] 1.1: Create the directory structure under `esp32-s3-mouse-emulator/`:

     ```
     esp32-s3-mouse-emulator/
     ├── platformio.ini
     ├── src/
     │   ├── main.cpp
     │   ├── usb_composite.h
     │   ├── usb_composite.cpp
     │   ├── mouse_controller.h
     │   ├── mouse_controller.cpp
     │   ├── command_handler.h
     │   ├── command_handler.cpp
     │   ├── device_config.h
     │   ├── device_config.cpp
     │   ├── logger.h
     │   └── logger.cpp
     ├── include/
     │   └── protocol.h
     ├── test/
     │   ├── test_command_handler/
     │   │   └── test_command_handler.cpp
     │   ├── test_mouse_controller/
     │   │   └── test_mouse_controller.cpp
     │   ├── test_device_config/
     │   │   └── test_device_config.cpp
     │   ├── test_logger/
     │   │   └── test_logger.cpp
     │   └── test_hardware_only/
     │       └── README.md
     ├── firmware/
     │   └── (populated by Phase 5 task 1)
     └── lib/
     ```

   - [ ] 1.2: Replace the existing stub `esp32-s3-mouse-emulator/platformio.ini` with the
     following (overwriting the generated stub — the env name and board settings below are
     authoritative):

     ```ini
     [platformio]
     default_envs = esp32-s3-devkitc-1

     [env:esp32-s3-devkitc-1]
     platform = espressif32
     board = esp32-s3-devkitc-1
     framework = arduino
     build_flags =
         -D ARDUINO_USB_MODE=0
         -D ARDUINO_USB_CDC_ON_BOOT=0
     board_build.arduino.memory_type = qio_opi
     board_build.flash_mode = qio
     board_build.psram_type = opi
     board_upload.flash_size = 16MB
     board_upload.maximum_size = 16777216
     board_build.partitions = default_16MB.csv
     board_build.extra_flags = -DBOARD_HAS_PSRAM
     monitor_speed = 921600
     upload_speed = 921600
     test_build_src = true
     lib_deps =
         adafruit/Adafruit TinyUSB Library @ ^3.1.0

     [env:native]
     platform = native
     test_build_src = false
     test_framework = unity
     build_flags =
         -D NATIVE_TEST
         -std=c++14
     lib_deps =
         fabiobatsilva/ArduinoFake @ ^0.4.0
     test_ignore = test_hardware_only
     ```

   - [ ] 1.2a: ~~Create `esp32-s3-mouse-emulator/partitions.csv`~~ — **No custom partition
     table required.** `board_build.partitions = default_16MB.csv` references the built-in
     16 MB partition table shipped with the ESP32 Arduino core. No file needs to be committed
     to the repository for this. The built-in table is included automatically when
     `esptool.exe` or `esp-web-tools` flashes the device.

   - [ ] 1.3: Create `esp32-s3-mouse-emulator/include/protocol.h`:
      - Protocol version constants (separate major, minor, patch for the version-check logic):

        ```cpp
        #define PROTOCOL_MAJOR 1
        #define PROTOCOL_MINOR 0
        #define PROTOCOL_PATCH 0
        #define PROTOCOL_VERSION "1.0.0"
        ```

      - Command string constants: `CMD_MOVE`, `CMD_CLICK`, `CMD_BUTTON_DOWN`,
        `CMD_BUTTON_UP`, `CMD_ABORT`, `CMD_PING`, `CMD_VER`, `CMD_NAME`, `CMD_SETNAME`
      - Response string constants: `RESP_ACK_OK`, `RESP_ACK_ERR`, `RESP_PONG`, `RESP_VER`,
        `RESP_NAME`, `RESP_LOG`
      - Log level constants: `LOG_VERBOSE`, `LOG_INFO`, `LOG_WARNING`, `LOG_ERROR`
      - Size and path constants:

        ```cpp
        #define MAX_COMMAND_LENGTH    128
        #define MAX_LOG_MSG_LENGTH    256
        #define BAUD_RATE             921600
        #define NVS_NAMESPACE         "lwas_config"
        #define NVS_KEY_DEVICE_SUFFIX "dev_suffix"
        #define DEVICE_NAME_PREFIX    "LWAS_Mouse_Emulator_"
        #define LOG_FILE_MAX_BYTES    65536
        #define LOG_FILE_PATH         "/lwas_log.txt"
        ```

      - No hardware-specific includes; this header must compile cleanly on the native target

2. [ ] Implement USB composite device (HID mouse + CDC serial)

   - [ ] 2.1: Create `src/usb_composite.h`:
      - Declare `void usb_composite_init()` — initialises TinyUSB with HID mouse and CDC ACM
        descriptors; sets the USB product name from `device_config_get_full_name()`
      - Declare `bool usb_cdc_available()` — `true` when the CDC input buffer has bytes
      - Declare `bool usb_cdc_connected()` — `true` when the CDC serial port is open on the
        host; wraps `Adafruit_USBD_CDC::connected()` which calls `tud_cdc_connected()`
        internally; use this (not `TinyUSBDevice.mounted()`) to detect host attach/detach
      - Declare `String usb_cdc_read_line()` — reads one `\n`-terminated line from CDC input;
        returns empty string when no complete line is buffered
      - Declare `void usb_cdc_println(const char* msg)` — writes `msg` followed by a single
        `'\n'` character to CDC **using `Serial.print(msg); Serial.print('\n');`** (never
        `Serial.println()` which sends `\r\n`); this guarantees the host `SerialPort`
        with `NewLine = "\n"` receives a clean response with no trailing `\r`
      - Declare `void usb_hid_send_mouse(int8_t dx, int8_t dy, uint8_t buttons)` — sends one
        HID mouse relative-movement report; `buttons` bitmask: `0x01` = left, `0x02` = right,
        `0x04` = middle
      - `#ifdef NATIVE_TEST` guard wrapping all TinyUSB-specific includes; stub declarations
        provided for the native target so the file compiles without TinyUSB headers

   - [ ] 2.2: Create `src/usb_composite.cpp`:
      - `usb_composite_init`: configure `Adafruit_USBD_HID` (mouse, `TUD_HID_REPORT_DESC_MOUSE()`)
        and `Adafruit_USBD_CDC`; set USB product name via `TinyUSBDevice.setProductDescriptor()`
        using `device_config_get_full_name()`; call `TinyUSBDevice.begin(0)`
      - `usb_hid_send_mouse`: call `usb_hid.mouseReport(0, buttons, dx, dy, 0, 0)` then
        `TinyUSBDevice.task()` to flush
      - `usb_cdc_read_line`: accumulate bytes from CDC buffer until `'\n'` or
        `MAX_COMMAND_LENGTH`; return the line without the trailing `'\n'`
      - Wrap all TinyUSB calls in `#ifndef NATIVE_TEST`; provide no-op stubs for native target

3. [ ] Implement the mouse controller

   - [ ] 3.1: Create `src/mouse_controller.h`:
      - Declare `bool mc_move(int dx, int dy)` — sends relative delta; internally splits into
        multiple 8-bit HID reports when `|dx|` or `|dy|` exceeds 127; returns `true`; a
        zero-delta call (`mc_move(0, 0)`) is a no-op and returns `true` without sending any
        HID report
      - Declare `bool mc_left_click(uint32_t hold_ms)` — non-blocking click state machine;
        presses left button, schedules release via `millis()` tracking; called from `loop()`
        on each iteration until the hold duration expires; returns `true` when the click
        sequence completes; see task 3.2 for the non-blocking design
      - Declare `bool mc_abort()` — immediately releases all held buttons (sends `buttons=0x00`
        HID report); resets any in-progress click state machine; returns `true`; safe to call
        at any time
      - Declare `void mc_set_hid_send_fn(void (*fn)(int8_t, int8_t, uint8_t))` — replaces the
        internal HID send function pointer; used exclusively in tests
      - Declare `bool mc_button_down(uint8_t button_mask)` — sends a button-pressed HID
        report with no movement; `button_mask` uses the same bitmask as `usb_hid_send_mouse`
        (`0x01` = left); returns `true`
      - Declare `bool mc_button_up()` — sends an all-buttons-released HID report with no
        movement; returns `true`
      - Declare `void mc_tick()` — called from `loop()` on every iteration to advance the
        click state machine; must be called frequently to ensure the click release fires on time

   - [ ] 3.2: Create `src/mouse_controller.cpp`:
      - Define `static void (*g_hid_send_fn)(int8_t, int8_t, uint8_t) = usb_hid_send_mouse;`
      - **Non-blocking click state machine** — to avoid calling `delay()` in `loop()`, implement
        a two-state machine for click hold:
        - `MC_CLICK_IDLE`: no click in progress
        - `MC_CLICK_HOLDING`: button is down; `g_click_release_ms` holds the target `millis()`
          value at which the button should be released
        - `mc_left_click(hold_ms)`: if state is `MC_CLICK_IDLE`, sends button-down report,
          sets `g_click_release_ms = millis() + hold_ms`, transitions to `MC_CLICK_HOLDING`,
          returns `false` (not yet complete); if state is already `MC_CLICK_HOLDING`, returns
          `false` (still waiting); `mc_tick()` checks `millis() >= g_click_release_ms`,
          sends button-up report, transitions to `MC_CLICK_IDLE`
        - `ch_process_line` sends `ACK OK` only after `mc_left_click` returns `true`.
          Because `mc_left_click` is non-blocking, `ch_process_line` must hold the pending
          response and wait for the state machine to complete before replying. Implement this
          by tracking a `CH_PENDING_CLICK_ACK` state in `command_handler.cpp`; `ch_process_line`
          rejects new commands while a click is pending (responds `ACK ERR busy`)
      - Define a `static` helper `mc_move_steps(int dx, int dy, uint8_t buttons)`: splits
        the delta into ±127-capped partial HID reports, sending each with the supplied
        `buttons` bitmask; does **not** send a trailing zero-button report, so a held button
        is never prematurely released when `BUTTON_DOWN` + `MOVE` sequences are used
      - `mc_move`: if `dx == 0 && dy == 0`, return `true` immediately (no-op); otherwise
        calls `mc_move_steps(dx, dy, 0x00)` then sends one final `g_hid_send_fn(0, 0, 0x00)`
        to zero both axes; return `true`
      - `mc_abort()`: send `g_hid_send_fn(0, 0, 0x00)`; reset state machine to
        `MC_CLICK_IDLE`; return `true`
      - `mc_button_down(uint8_t button_mask)`: `g_hid_send_fn(0, 0, button_mask)`; return
        `true`
      - `mc_button_up()`: `g_hid_send_fn(0, 0, 0x00)`; return `true`
      - `mc_tick()`: if state is `MC_CLICK_HOLDING` and `millis() >= g_click_release_ms`,
        send button-up report, set state to `MC_CLICK_IDLE`

4. [ ] Implement the command handler

   - [ ] 4.1: Create `src/command_handler.h`:
      - Declare `void ch_init()` — initialises internal state
      - Declare `void ch_process_line(const char* line)` — parses one line from CDC input and
        dispatches; sends a response via the registered output function; rejects new commands
        with `ACK ERR busy` while a click hold is pending
      - Declare `void ch_tick()` — called from `loop()` to advance the click state machine via
        `mc_tick()`; sends the deferred `ACK OK` for a completed `CLICK` command
      - Declare `void ch_set_output_fn(void (*fn)(const char*))` — replaces the CDC output
        function; used in tests

   - [ ] 4.2: Create `src/command_handler.cpp`:
      - Define `static void (*g_output_fn)(const char*) = usb_cdc_println;`
      - `ch_process_line`: parse first token to identify the command; dispatch:

        | Received | Action | Response |
        |---|---|---|
        | `MOVE dx dy` | `mc_move(dx, dy)` | `ACK OK` or `ACK ERR move_failed` |
        | `CLICK L hold_ms` | start click state machine via `mc_left_click(hold_ms)` | deferred `ACK OK` when click completes (via `ch_tick()`); `ACK ERR busy` if already in progress |
        | `CLICK R\|M *` | — | `ACK ERR not_implemented` |
        | `BUTTON_DOWN L` | `mc_button_down(0x01)` | `ACK OK` |
        | `BUTTON_DOWN R\|M *` | — | `ACK ERR not_implemented` |
        | `BUTTON_UP L` | `mc_button_up()` | `ACK OK` |
        | `BUTTON_UP R\|M *` | — | `ACK ERR not_implemented` |
        | `ABORT` | `mc_abort()` | `ACK OK` |
        | `PING` | — | `PONG` |
        | `VER` | — | `VER <PROTOCOL_VERSION>` |
        | `NAME` | — | `NAME <device_config_get_full_name()>` |
        | `SETNAME suffix` | `device_config_set_suffix(suffix)` | `ACK OK` or `ACK ERR bad_params` |
        | anything else | — | `ACK ERR unknown_command` |

      - `ch_tick()`: calls `mc_tick()`; if the state machine has just completed a click
        (transitioned from `MC_CLICK_HOLDING` to `MC_CLICK_IDLE`), sends the deferred
        `ACK OK` for the completed `CLICK` command
      - `dx` and `dy` in `MOVE` are parsed as plain `int` (not clamped); the
        protocol carries whatever integer value the host sends; `mc_move` handles splitting
      - Validate numeric parameters with `sscanf`; respond `ACK ERR bad_params` on parse failure
      - Validate `SETNAME` suffix is exactly 6 characters, all `[0-9A-F]`, before calling
        `device_config_set_suffix`

5. [ ] Implement device configuration and naming

   - [ ] 5.1: Create `src/device_config.h`:
      - Declare `void device_config_init()` — reads suffix from NVS; if absent or malformed,
        generates a new random 6-character uppercase hex suffix via `esp_random()` and saves it
      - Declare `const char* device_config_get_suffix()` — returns the stored suffix
      - Declare `const char* device_config_get_full_name()` — returns
        `DEVICE_NAME_PREFIX + suffix`
      - Declare `bool device_config_set_suffix(const char* suffix)` — validates exactly 6
        uppercase hex chars; saves to NVS; updates the in-memory cached name; returns `true`
      - `#ifdef NATIVE_TEST` guards around NVS-specific headers

   - [ ] 5.2: Create `src/device_config.cpp`:
      - `device_config_init`: open NVS namespace `NVS_NAMESPACE`; read
        `NVS_KEY_DEVICE_SUFFIX`; if absent or invalid length, generate:
        `snprintf(buf, 7, "%06X", (unsigned)esp_random())`; save to NVS; close namespace
      - `device_config_set_suffix`: validate all 6 chars are `[0-9A-F]`; write to NVS;
        update the cached full-name buffer; return `true` on success
      - In `NATIVE_TEST` builds: use a static char buffer instead of NVS;
        `device_config_init()` sets a fixed deterministic suffix `"AABBCC"` for tests

6. [ ] Implement device logging

   - [ ] 6.1: Create `src/logger.h`:
      - Declare `void logger_init()` — mounts LittleFS; rotates log file if oversized
      - Declare `void logger_set_host_connected(bool connected)`
      - Declare `void logger_log(const char* level, const char* message)` — if host connected,
        sends `"LOG level message\n"` over CDC; otherwise appends to the LittleFS log file
        with a `millis()`-based timestamp prefix
      - Declare `void logger_rotate_if_needed()` — trims the log file when size exceeds
        `LOG_FILE_MAX_BYTES` by discarding the oldest 25% of lines
      - Convenience macros:

        ```cpp
        #define LOG_INFO(msg)    logger_log("INFO",    msg)
        #define LOG_WARN(msg)    logger_log("WARNING", msg)
        #define LOG_ERR(msg)     logger_log("ERROR",   msg)
        #define LOG_VERBOSE(msg) logger_log("VERBOSE", msg)
        ```

      - `#ifdef NATIVE_TEST` guard around LittleFS includes

   - [ ] 6.2: Create `src/logger.cpp`:
      - `logger_init`: call `LittleFS.begin(true)` (format partition on first-mount failure);
        call `logger_rotate_if_needed()`
      - `logger_log`: if `g_host_connected`, call `usb_cdc_println` with
        `"LOG level message"`; otherwise open `LOG_FILE_PATH` in append mode, write
        `"<millis_value> [level] message\n"`, close
      - `logger_rotate_if_needed`: if file size exceeds `LOG_FILE_MAX_BYTES`, read all lines,
        discard the first 25%, rewrite the file; log `"Log rotated"` at INFO level after
        rewrite
      - In `NATIVE_TEST` builds: skip LittleFS; write all log output to `stdout` for capture

7. [ ] Implement the main firmware loop

   - [ ] 7.1: Create `src/main.cpp`:
      - `setup()`: call `device_config_init()`, `logger_init()`, `usb_composite_init()`;
        call `ch_init()`; call `LOG_INFO("Device ready")`
      - `loop()`:
        - Call `TinyUSBDevice.task()` to process USB events
        - Call `ch_tick()` on every iteration to advance the click state machine and send
          any deferred `CLICK` ACK response
        - Detect CDC connect/disconnect via `usb_cdc_connected()` (declared in task 2.1,
          wraps `tud_cdc_connected()`); call `logger_set_host_connected()` on state change;
          do **not** use `TinyUSBDevice.mounted()` — that reflects USB enumeration, not
          whether the host has opened the serial port
        - If `usb_cdc_available()`, call `usb_cdc_read_line()`; if non-empty, call
          `ch_process_line(line.c_str())`
        - Every 60 seconds (tracked with `millis()`), call `logger_rotate_if_needed()`
      - No `delay()` calls in `loop()` — all operations must be non-blocking so HID reports
        are sent promptly; click hold duration is managed by `ch_tick()`/`mc_tick()`
      - `#ifndef NATIVE_TEST` guard wrapping `setup()` and `loop()` so the native test
        target compiles without Arduino entry points

8. [ ] Update `.gitattributes` for firmware binaries

   - [ ] 8.1: Add the following lines to the repository root `.gitattributes`:

      ```
      powershell-module/esp32-s3-mouse-emulator/firmware/*.bin binary
      powershell-module/esp32-s3-mouse-emulator/firmware/*.elf binary
      ```

      This prevents git from attempting to diff binary firmware files. The built-in
      `default_16MB.csv` partition table is not committed to this repository (it is part of
      the ESP32 Arduino core). The firmware directory lives inside the module tree
      so it is included automatically in the release zip and install copy without additional
      steps (see Phase 5, task 4).

---

## Phase 2: Unity Testing Environment

1. [ ] Implement native-environment unit tests for the command handler

   - [ ] 1.1: Create `test/test_command_handler/test_command_handler.cpp`:
      - `#include <unity.h>`, `#include "command_handler.h"`, `#include "protocol.h"`
      - `#ifdef NATIVE_TEST` guard wrapping the entire file
      - In `setUp()`: reset the captured output buffer; inject mock output function via
        `ch_set_output_fn()`; inject mock HID function via `mc_set_hid_send_fn()`
      - Tests:
         - `test_move_valid`: `ch_process_line("MOVE 10 -5")` → mock HID called with
           `dx=10, dy=-5`; output buffer contains `"ACK OK"`
         - `test_move_large_delta_splits`: `ch_process_line("MOVE 200 0")` → mock HID called
           at least twice; sum of all `dx` values equals 200; output contains `"ACK OK"`
         - `test_move_bad_args`: `ch_process_line("MOVE abc 5")` → output contains
           `"ACK ERR bad_params"`
         - `test_click_left`: `ch_process_line("CLICK L 50")`; output buffer empty
           immediately (ACK deferred); call `ch_tick()` repeatedly until output appears;
           mock HID called with `buttons=0x01` then `buttons=0x00`; output contains `"ACK OK"`
         - `test_click_busy`: `ch_process_line("CLICK L 500")`; immediately call
           `ch_process_line("MOVE 1 0")` → second command returns `"ACK ERR busy"`
         - `test_click_right_not_implemented`: `ch_process_line("CLICK R 0")` → output
           contains `"ACK ERR not_implemented"`
         - `test_abort`: `ch_process_line("BUTTON_DOWN L")`; `ch_process_line("ABORT")` →
           mock HID called with `buttons=0x00`; output contains `"ACK OK"`
         - `test_ping`: `ch_process_line("PING")` → output contains `"PONG"`
         - `test_ver`: `ch_process_line("VER")` → output contains `"VER 1."`
           (begins with major version)
         - `test_name`: `ch_process_line("NAME")` → output contains
           `"NAME LWAS_Mouse_Emulator_"`
         - `test_setname_valid`: `ch_process_line("SETNAME A1B2C3")` → output contains
           `"ACK OK"`; `device_config_get_suffix()` returns `"A1B2C3"`
         - `test_setname_lowercase_rejected`: `ch_process_line("SETNAME abcdef")` → output
           contains `"ACK ERR"`
         - `test_setname_wrong_length`: `ch_process_line("SETNAME AB")` → output contains
           `"ACK ERR bad_params"`
         - `test_setname_non_hex`: `ch_process_line("SETNAME GHIJKL")` → output contains
           `"ACK ERR"`
         - `test_unknown_command`: `ch_process_line("BLAH")` → output contains
           `"ACK ERR unknown_command"`
         - `test_button_down_left`: `ch_process_line("BUTTON_DOWN L")` → mock HID called
           with `buttons=0x01`, `dx=0`, `dy=0`; output contains `"ACK OK"`
         - `test_button_up`: `ch_process_line("BUTTON_UP L")` → mock HID called with
           `buttons=0x00`, `dx=0`, `dy=0`; output contains `"ACK OK"`
         - `test_button_down_right_not_implemented`: `ch_process_line("BUTTON_DOWN R")` →
           output contains `"ACK ERR not_implemented"`
      - `main()`: `UNITY_BEGIN()`; run all tests via `RUN_TEST()`; `UNITY_END()`

2. [ ] Implement native-environment unit tests for the mouse controller

   - [ ] 2.1: Create `test/test_mouse_controller/test_mouse_controller.cpp`:
      - `#ifdef NATIVE_TEST` guard wrapping the entire file
      - In `setUp()`: inject mock HID function via `mc_set_hid_send_fn()`; reset call log
      - Tests:
         - `test_move_normal`: `mc_move(50, -30)` → mock called with `dx=50, dy=-30`
         - `test_move_large_x_splits`: `mc_move(300, 0)` → mock called at least 3 times;
           sum of all `dx` values equals 300
         - `test_move_zero`: `mc_move(0, 0)` → mock NOT called (no-op); returns `true`
         - `test_click_button_sequence`: `mc_left_click(0)`; call `mc_tick()` until it
           returns; first HID call has `buttons=0x01`; final call after `mc_tick()` has
           `buttons=0x00`
         - `test_abort_releases_button`: `mc_button_down(0x01)`; `mc_abort()` → mock HID
           called with `buttons=0x00`; state machine reset to idle; returns `true`
         - `test_button_down`: `mc_button_down(0x01)` → mock HID called with `buttons=0x01`,
           `dx=0`, `dy=0`; returns `true`
         - `test_button_up`: `mc_button_up()` → mock HID called with `buttons=0x00`,
           `dx=0`, `dy=0`; returns `true`

3. [ ] Implement native-environment unit tests for device configuration

   - [ ] 3.1: Create `test/test_device_config/test_device_config.cpp`:
      - `#ifdef NATIVE_TEST` guard wrapping the entire file
      - Tests:
         - `test_init_produces_six_char_suffix`: `device_config_init()` →
           `strlen(device_config_get_suffix())` equals 6
         - `test_full_name_has_prefix`: `device_config_get_full_name()` starts with
           `"LWAS_Mouse_Emulator_"`
         - `test_set_suffix_valid`: `device_config_set_suffix("F1E2D3")` returns `true`;
           `device_config_get_suffix()` returns `"F1E2D3"`
         - `test_set_suffix_lowercase_rejected`: `device_config_set_suffix("abcdef")` returns
           `false`
         - `test_set_suffix_wrong_length`: `device_config_set_suffix("ABC")` returns `false`
         - `test_set_suffix_non_hex`: `device_config_set_suffix("GHIJKL")` returns `false`

4. [ ] Implement native-environment unit tests for the logger

   - [ ] 4.1: Create `test/test_logger/test_logger.cpp`:
      - `#ifdef NATIVE_TEST` guard wrapping the entire file
      - Tests:
         - `test_log_host_connected_uses_cdc`: `logger_set_host_connected(true)`;
           `logger_log("INFO", "hello")` → captured CDC output contains `"LOG INFO hello"`
         - `test_log_host_disconnected_uses_local`: `logger_set_host_connected(false)`;
           `logger_log("INFO", "hello")` → CDC output NOT called; output visible on `stdout`

5. [ ] Create the hardware-only test placeholder

   - [ ] 5.1: Create `test/test_hardware_only/README.md` — notes that this directory is for
     tests requiring a physical device; excluded from the `native` environment via
     `test_ignore = test_hardware_only`; run with
     `pio test -e esp32s3 --filter test_hardware_only`; currently contains only the manual
     smoke tests described in Phase 6

6. [ ] Verify `pio test -e native` passes cleanly

   - [ ] 6.1: Run `pio test -e native` from `esp32-s3-mouse-emulator/`; all tests in
     `test_command_handler`, `test_mouse_controller`, `test_device_config`, `test_logger` pass;
     zero failures; record total test count

---

## Phase 3: PowerShell Module Integration

### Architecture decisions (recorded for reference)

- **`MouseEmulation` config section** is added at the top level of `ModuleConfig.json`
  alongside `MouseControl`, `EmergencyStop`, etc.
- **Session state:** `$script:HardwareDevicePort` (`[System.IO.Ports.SerialPort]`) and
  `$script:HardwareDeviceDeviceName` (`[string]`) hold the active connection. Both are set
  by `Connect-LWASHardwareDevice` and cleared by `Disconnect-LWASHardwareDevice`.
- **Routing layer:** `Invoke-MouseMovePath`, `Invoke-MouseClick`, and `Invoke-MouseDragClick`
  each read `MouseEmulation.Mode` at call time and dispatch to the hardware or software path.
  No changes to callers.
- **Version check on connect:** the `VER` response is parsed to extract major and minor
  version numbers. Major mismatch = close port, log error, return `$false`. Minor mismatch =
  log warning, continue. Patch version is ignored. The expected major version is read from
  the firmware version file committed alongside the binaries.
- **COM port identification:** `Get-CimInstance -ClassName Win32_PnPEntity` filtered by name
  pattern, cross-referenced with `[System.IO.Ports.SerialPort]::GetPortNames()`.
- **Per-step ACK round-trip (informed design decision):** `Invoke-MouseMovePath` sends each
  Bezier step as a `MOVE` command and waits for `ACK OK` before sending the next (via
  `Invoke-HardwareMouseCommand`). This introduces one serial round-trip delay (~5-15 ms at
  921600 baud) per step but provides positive confirmation that each step was executed. The
  trade-off is intentional: Bezier path correctness (faithfully following the computed curve,
  with the same start and end point) matters more than tight inter-step timing. A slight
  timing variation between steps does not change the visible path shape. Retry with
  `Invoke-WithHardwareRetry` also depends on per-step ACK to know where to resume.

---

1. [ ] Create `Private/HardwareMouse/` directory structure

   - [ ] 1.1: Create the directory `powershell-module/Private/HardwareMouse/` and add a
     `.gitkeep` placeholder file to ensure git tracks the empty directory before any
     `.ps1` files are added in subsequent tasks

2. [ ] Add `MouseEmulation` configuration section

   - [ ] 2.1: Extend `Private/ModuleConfig.json`:

     ```json
     "MouseEmulation": {
         "Mode": "Software",
         "PreferredDeviceName": "",
         "SerialTimeoutMs": 2000,
         "MaxRetryAttempts": 3,
         "RetryDelayMs": 1000
     }
     ```

   - [ ] 2.2: Add `MouseEmulation` entries to `$script:ConfigValidationSchema` in
     `Private/Get-DefaultModuleSettings.ps1`:
      - `'MouseEmulation.Mode'` — `stringEnum`; `AllowedValues = @('Software', 'Hardware')`
      - `'MouseEmulation.SerialTimeoutMs'` — `int`; `Min = 100`; `Max = 30000`
      - `'MouseEmulation.MaxRetryAttempts'` — `int`; `Min = 1`; `Max = 10`
      - `'MouseEmulation.RetryDelayMs'` — `int`; `Min = 100`; `Max = 10000`

   - [ ] 2.3: Add `MouseEmulation` defaults to the `Get-DefaultModuleSettings` function:

     ```powershell
     MouseEmulation = @{
         Mode                = 'Software'
         PreferredDeviceName = ''
         SerialTimeoutMs     = 2000
         MaxRetryAttempts    = 3
         RetryDelayMs        = 1000
     }
     ```

   - [ ] 2.4: Update `Private/Get-ModuleConfiguration.ps1` — inject the entire `MouseEmulation`
     sub-object if the key is absent; inject each individual sub-key if the object exists but a
     key is missing. Follow the same pattern used for `SimilarityCheck` in Phase 5.

   - [ ] 2.5: Update `Private/Save-ModuleConfiguration.ps1` — persist all `MouseEmulation.*`
     keys without breaking existing keys.

   - [ ] 2.6: Add round-trip save/load tests for all `MouseEmulation.*` keys to
     `Tests/ModuleConfiguration.Tests.ps1`; add a default-injection test simulating a config
     file that predates this phase (missing the entire `MouseEmulation` section).

3. [ ] Implement device enumeration

   - [ ] 3.1: Create `Private/HardwareMouse/Find-LWASHardwareDevice.ps1`:
      - `Find-LWASHardwareDevice`; `[CmdletBinding()]`; optional `[switch]$IncludeAll`
      - Queries `Get-CimInstance -ClassName Win32_PnPEntity` for entries whose `Name` or
        `Caption` matches `"*LWAS_Mouse_Emulator*"`
      - Cross-references results against `[System.IO.Ports.SerialPort]::GetPortNames()` to
        determine each device's COM port
      - Returns `[PSCustomObject[]]` — each object has `DeviceName [string]`,
        `ComPort [string]`, `IsConnected [bool]`; never returns `$null`
      - Without `-IncludeAll`: filters to names matching `^LWAS_Mouse_Emulator_[0-9A-F]{6}$`;
        with `-IncludeAll`: returns all CDC-capable COM port devices (useful when enumerating
        a device in flash mode that has no valid name yet)
      - Full comment-based help; `.NOTES` documents the brief WMI propagation delay after
        device plug-in

   - [ ] 3.2: Create `Tests/HardwareDeviceDetection.Tests.ps1`:
      - Mock `Get-CimInstance` and `[System.IO.Ports.SerialPort]::GetPortNames`
      - No LWAS devices → empty array returned; no error or warning written
      - One LWAS device found → one-element array; `DeviceName` starts with
        `"LWAS_Mouse_Emulator_"`; `ComPort` non-empty
      - Two LWAS devices found → two-element array
      - Non-LWAS COM device present → not included in results
      - `-IncludeAll` includes devices that would otherwise be filtered by name pattern

4. [ ] Implement serial connection management

   - [ ] 4.1: Create `Private/HardwareMouse/Connect-LWASHardwareDevice.ps1`:
      - `Connect-LWASHardwareDevice -ComPort [string] -DeviceName [string] [-SkipNameValidation]`
      - Constructs `[System.IO.Ports.SerialPort]` at 921600 baud, 8N1; sets `ReadTimeout`
        and `WriteTimeout` from `(Get-ModuleConfiguration).MouseEmulation.SerialTimeoutMs`;
        sets `$port.NewLine = "\n"` so `ReadLine()` terminates on `\n` only, preventing
        a trailing `\r` from some CDC drivers corrupting response comparisons
      - Sends `VER`; parses response `"VER major.minor.patch"`:
        - If response does not start with `"VER "`: close port, log error, return `$false`
        - Extract `major` from the version string; compare with the expected major version
          read from `Join-Path $PSScriptRoot '..\..\esp32-s3-mouse-emulator\firmware\firmware_version.txt'`
          (resolves to `powershell-module/esp32-s3-mouse-emulator/firmware/firmware_version.txt`
          both in development and after installation); if mismatch: close port, log error
          `"Firmware major version mismatch. Expected $expected, got $actual. Reflash required."`,
          return `$false`
        - If minor version differs from expected minor: log warning
          `"Firmware minor version differs ($actual vs $expected). Compatibility assumed but reflash is recommended."`
          and continue
      - If `-SkipNameValidation` is **not** set: sends `NAME`; validates the response name
        matches `$DeviceName`; if mismatch: close port, log error, return `$false`
      - If `-SkipNameValidation` **is** set: skip the `NAME` command and name-match check
        entirely; used by `Show-FirmwareFlashScreen` to connect post-flash before `SETNAME`
        has been sent
      - On success: stores port in `$script:HardwareDevicePort` and name in
        `$script:HardwareDeviceDeviceName` (`""` when `-SkipNameValidation` is used);
        returns `$true`
      - Full comment-based help; document the `-SkipNameValidation` parameter

   - [ ] 4.2: Create `Private/HardwareMouse/Disconnect-LWASHardwareDevice.ps1`:
      - `Disconnect-LWASHardwareDevice`
      - Closes and disposes `$script:HardwareDevicePort` if non-null and open; sets it to
        `$null`; clears `$script:HardwareDeviceDeviceName`
      - Calling when already disconnected does not throw
      - Full comment-based help

   - [ ] 4.3: Register a module removal hook in `LastWarAutoScreenshot.psm1`:
      - In `$MyInvocation.MyCommand.Module.OnRemove`, call `Disconnect-LWASHardwareDevice`
        so the COM port is closed cleanly on `Remove-Module` or `Import-Module -Force`

   - [ ] 4.4: Create `Private/HardwareMouse/Test-LWASHardwareDeviceConnected.ps1`:
      - `Test-LWASHardwareDeviceConnected`
      - Returns `$true` when `$script:HardwareDevicePort` is non-null and `.IsOpen -eq $true`;
        `$false` otherwise; no errors or warnings written (follows `Test-*` convention)
      - Full comment-based help

   - [ ] 4.5: Create `Private/HardwareMouse/Invoke-HardwareMouseCommand.ps1`:
      - `Invoke-HardwareMouseCommand -Command [string]`
      - Calls `$script:HardwareDevicePort.WriteLine($Command)`; then enters a read loop:
        calls `$script:HardwareDevicePort.ReadLine()` repeatedly; any line beginning with
        `"LOG "` is parsed (log level is the second token, remainder is the message) and
        forwarded to `Write-LastWarLog` at the corresponding level, then the loop continues
        reading the next line; the first non-LOG line is returned as the response
      - Returns the response string on success; `$null` on timeout or if the port is closed;
        `Write-LastWarLog` is called at Error level on timeout or closed-port failure
      - Full comment-based help; kept as a thin wrapper for Pester mockability

   - [ ] 4.6: Create `Tests/HardwareMouseConnection.Tests.ps1`:
      - Mock `[System.IO.Ports.SerialPort]` construction and methods via `InModuleScope`
      - `Connect-LWASHardwareDevice`: VER returns matching major version, NAME matches →
        `$script:HardwareDevicePort` set; returns `$true`
      - `Connect-LWASHardwareDevice`: VER returns wrong major version → port closed; error
        logged containing `"major version mismatch"`; returns `$false`
      - `Connect-LWASHardwareDevice`: VER returns wrong minor version only → warning logged
        containing `"minor version"` ; returns `$true` (connect succeeds)
      - `Connect-LWASHardwareDevice`: NAME mismatch → port closed; error logged; `$false`
      - `Connect-LWASHardwareDevice -SkipNameValidation`: VER check passes; `NAME` command
        NOT sent; `$script:HardwareDeviceDeviceName` set to `""`; returns `$true`
      - `Disconnect-LWASHardwareDevice`: port closed and nulled; second call does not throw
      - `Test-LWASHardwareDeviceConnected`: `$true` when port open; `$false` when null or
        closed
      - `Invoke-HardwareMouseCommand`: sends command via `WriteLine`; returns response from
        `ReadLine`
      - `Invoke-HardwareMouseCommand`: `ReadLine` returns a `"LOG INFO hello"` line followed
        by `"ACK OK"` → `Write-LastWarLog` called with the message; `"ACK OK"` returned
      - `Invoke-HardwareMouseCommand`: `ReadLine` throws `TimeoutException` → `$null` returned;
        `Write-LastWarLog` called

5. [ ] Implement hardware mouse action functions

   - [ ] 5.1: Create `Private/HardwareMouse/Invoke-HardwareMouseMove.ps1`:
      - `Invoke-HardwareMouseMove -DeltaX [int] -DeltaY [int]`
      - Sends `"MOVE $DeltaX $DeltaY"` via `Invoke-HardwareMouseCommand` — no clamping or
        splitting on the PowerShell side; the firmware handles all delta splitting internally
      - Returns `$true` when response starts with `"ACK OK"`; `$false` otherwise; logs error
        via `Write-LastWarLog` on failure or `$null` response
      - Full comment-based help

   - [ ] 5.2: Create `Private/HardwareMouse/Invoke-HardwareMouseClick.ps1`:
      - `Invoke-HardwareMouseClick -DownDurationMs [int]`
      - Sends `"CLICK L $DownDurationMs"` via `Invoke-HardwareMouseCommand`
      - Returns `$true` on `"ACK OK"`; `$false` otherwise; logs error on failure
      - Full comment-based help

   - [ ] 5.3: Create `Private/HardwareMouse/Invoke-HardwareMouseDrag.ps1`:
      - `Invoke-HardwareMouseDrag -Waypoints [PSCustomObject[]]`; each waypoint has `X [int]`
        and `Y [int]` absolute screen-coordinate properties representing the full Bezier
        drag path (identical waypoint array used by the software path)
      - Sends `"BUTTON_DOWN L"` via `Invoke-HardwareMouseCommand`; returns `$false`
        immediately on failure without attempting any `MOVE` commands
      - Iterates waypoints in order; for each consecutive pair computes
        `$deltaX = $current.X - $previous.X` and `$deltaY = $current.Y - $previous.Y`;
        sends `"MOVE $deltaX $deltaY"` via `Invoke-HardwareMouseCommand`; sleeps the
        inter-step delay from `(Get-ModuleConfiguration).MouseControl` (same value used by
        the software path) so timing is indistinguishable from a physical drag
      - After all waypoints: sends `"BUTTON_UP L"` via `Invoke-HardwareMouseCommand`
      - On any `MOVE` failure: sends `"BUTTON_UP L"` as a cleanup step before returning
        `$false`; logs all errors via `Write-LastWarLog`
      - Returns `$true` on full success; `$false` on any failure
      - Full comment-based help

   - [ ] 5.4: Create `Tests/HardwareMouseActions.Tests.ps1`:
      - Mock `Invoke-HardwareMouseCommand`
      - `Invoke-HardwareMouseMove`: correct `"MOVE dx dy"` string sent; `"ACK OK"` → `$true`;
        large values (e.g. `DeltaX = 300`) are sent as-is — no PowerShell-side validation
      - `Invoke-HardwareMouseMove`: `"ACK ERR move_failed"` response → `$false`; error logged
      - `Invoke-HardwareMouseMove`: `$null` response (timeout) → `$false`; error logged
      - `Invoke-HardwareMouseClick`: correct `"CLICK L <ms>"` string sent; `"ACK OK"` → `$true`
      - `Invoke-HardwareMouseDrag`: `"BUTTON_DOWN L"` sent first; correct `"MOVE dx dy"`
        strings sent for each consecutive waypoint pair; `"BUTTON_UP L"` sent last;
        `"ACK OK"` for all commands → `$true`
      - `Invoke-HardwareMouseDrag`: `BUTTON_DOWN` fails → `$false` returned immediately;
        no `MOVE` or `BUTTON_UP` commands sent
      - `Invoke-HardwareMouseDrag`: a mid-path `MOVE` fails → `"BUTTON_UP L"` still sent
        as cleanup; `$false` returned; error logged via `Write-LastWarLog`

6. [ ] Implement retry logic for device unavailability

   - [ ] 6.1: Create `Private/HardwareMouse/Invoke-WithHardwareRetry.ps1`:
      - `Invoke-WithHardwareRetry -ScriptBlock [ScriptBlock] -OperationName [string]
        [-Console [Spectre.Console.IAnsiConsole]]`
      - Reads `MaxRetryAttempts` and `RetryDelayMs` from `Get-ModuleConfiguration`
      - Executes `$ScriptBlock`; on `$false` return or caught exception, increments failure
        counter and sleeps `RetryDelayMs`
      - After each failure, checks `Test-LWASHardwareDeviceConnected`; if disconnected:
        - Call `Find-LWASHardwareDevice` (WMI enumeration only — no serial connection)
        - If a device is found whose `DeviceName` starts with `"LWAS_Mouse_Emulator_"`:
          call `Connect-LWASHardwareDevice -ComPort $d.ComPort -DeviceName $d.DeviceName`
          (WMI gives the full device name from the USB product descriptor; no need for
          `-SkipNameValidation` during normal retry)
        - If `$script:HardwareDeviceDeviceName` is `""` (i.e., the connection was
          established post-flash via `-SkipNameValidation`): call
          `Connect-LWASHardwareDevice -ComPort $d.ComPort -DeviceName "" -SkipNameValidation`
        - If no device is found via WMI: log via `Write-LastWarLog` and skip reconnect
      - If `-Console` is provided: write a Spectre.Console markup line to `$Console` on
        each retry attempt:
        `"[yellow]Hardware device unavailable ($OperationName attempt $n/$max). Reconnecting...[/]"`
        If `-Console` is not provided: use `Write-LastWarLog` only (for headless/non-console
        callers)
      - After `MaxRetryAttempts` consecutive failures: logs the failure at Error level via
        `Write-LastWarLog`:
        `"Hardware device unavailable after $n attempts. Check the USB connection and try again."`
        If `-Console` is provided: also write an error panel to `$Console`
      - Returns `$true` when the scriptblock succeeds; `$false` after exhausting retries
      - Full comment-based help

   - [ ] 6.2: Add tests to `Tests/HardwareMouseConnection.Tests.ps1`:
      - Scriptblock returns `$true` first attempt → called once; returns `$true`
      - Scriptblock fails twice then succeeds → called 3 times total; returns `$true`
      - All retries exhausted → `Write-LastWarLog` called at Error level; `$false` returned
      - Device disconnected during retry: `Test-LWASHardwareDeviceConnected` returns `$false`;
        `Find-LWASHardwareDevice` returns one device → `Connect-LWASHardwareDevice` called
        with that device's name (not `-SkipNameValidation`)
      - Device disconnected during retry; stored name is `""`:
        → `Connect-LWASHardwareDevice` called with `-SkipNameValidation`
      - `-Console` provided: retry attempt writes yellow markup line to test console output

7. [ ] Add hardware/software routing to existing mouse action functions

   - [ ] 7.1: Update `Private/Invoke-MouseMovePath.ps1`:
      - Read `$config = Get-ModuleConfiguration` at the start of the path execution loop
      - If `$config.MouseEmulation.Mode -eq 'Hardware'` and
        `Test-LWASHardwareDeviceConnected` is `$true`: for each Bezier point, compute
        `$deltaX` and `$deltaY` from the previous point; call
        `Invoke-WithHardwareRetry -ScriptBlock { Invoke-HardwareMouseMove -DeltaX $deltaX -DeltaY $deltaY } -OperationName 'MouseMove'`;
        sleep the calculated step delay
      - If `Mode = 'Hardware'` but `Test-LWASHardwareDeviceConnected` returns `$false`: log
        `Write-LastWarLog -Level Warning` `"Hardware mode active but device not connected — falling back to software path"`;
        execute the existing `Invoke-SendMouseInput` path unchanged
      - If `Mode = 'Software'`: existing `Invoke-SendMouseInput` path unchanged

   - [ ] 7.2: Update `Private/Invoke-MouseClick.ps1`:
      - Same routing pattern; hardware path calls
        `Invoke-WithHardwareRetry { Invoke-HardwareMouseClick -DownDurationMs $DownDurationMs }`;
        software fallback unchanged

   - [ ] 7.3: Update `Private/Invoke-MouseDragClick.ps1`:
      - Compute the Bezier waypoint array using the same logic as the existing software path
        (identical interpolation and timing parameters)
      - If `Mode = 'Hardware'` and `Test-LWASHardwareDeviceConnected` is `$true`: call
        `Invoke-WithHardwareRetry -ScriptBlock { Invoke-HardwareMouseDrag -Waypoints $waypoints } -OperationName 'MouseDrag'`;
        the full waypoint path is used so hardware movement is indistinguishable from
        the software path for anti-cheat purposes
      - If `Mode = 'Hardware'` but `Test-LWASHardwareDeviceConnected` returns `$false`: log
        warning via `Write-LastWarLog` and fall back to the software path (same pattern as
        `Invoke-MouseMovePath`)
      - Software fallback unchanged

   - [ ] 7.4: Add routing tests to `Tests/MouseMovement.Tests.ps1`:
      - Mock `Mode = 'Hardware'`; `Test-LWASHardwareDeviceConnected` returns `$true`; mock
        `Invoke-HardwareMouseMove` → `Invoke-HardwareMouseMove` called;
        `Invoke-SendMouseInput` NOT called
      - Mock `Mode = 'Software'` → `Invoke-SendMouseInput` called;
        `Invoke-HardwareMouseMove` NOT called
      - Mock `Mode = 'Hardware'`; `Test-LWASHardwareDeviceConnected` returns `$false` →
        software path used; `Write-LastWarLog` called at Warning level

8. [ ] Update module loading for the new private folder

   - [ ] 8.1: Add dot-sourcing of `Private/HardwareMouse/*.ps1` in `LastWarAutoScreenshot.psm1`,
     after the existing `Private/ConsoleApp/*.ps1` block; confirm no load errors

---

## Phase 4: Console App Integration

1. [ ] Add "Toggle mouse emulation" to the main menu

   - [ ] 1.1: Update `Private/ConsoleApp/Show-MainMenu.ps1`:
      - Read `$mode = (Get-ModuleConfiguration).MouseEmulation.Mode` each time the menu is
        rendered; display `"Toggle mouse emulation ($mode)"` — the parenthesised label updates
        on every menu render to reflect the current mode
      - Position: after `"Select target window"`, before `"Record macro"`
      - Return identifier `'ToggleMouseEmulation'`
      - Update comment-based help

   - [ ] 1.2: Update `Public/Start-LWASConsole.ps1`:
      - Add `'ToggleMouseEmulation'` case dispatching to
        `Invoke-MouseEmulationToggle -Console $Console` wrapped in `RunInAlternateScreen`

   - [ ] 1.3: Add tests to `Tests/ConsoleApp/Show-MainMenu.Tests.ps1`:
      - Mock `Get-ModuleConfiguration` with `Mode = 'Software'` → output contains
        `"Toggle mouse emulation (Software)"`
      - Mock `Get-ModuleConfiguration` with `Mode = 'Hardware'` → output contains
        `"Toggle mouse emulation (Hardware)"`
      - Selecting the option returns identifier `'ToggleMouseEmulation'`

   - [ ] 1.4: Add tests to `Tests/ConsoleApp/Start-LWASConsole.Tests.ps1`:
      - Mock `Show-MainMenu` returning `'ToggleMouseEmulation'` once then `'Exit'`; mock
        `Invoke-MouseEmulationToggle`; verify it is called exactly once

2. [ ] Add "Flash device firmware" to the main menu

   - [ ] 2.1: Update `Private/ConsoleApp/Show-MainMenu.ps1`:
      - Add `"Flash device firmware"` as a selectable option; position immediately after
        `"Toggle mouse emulation"`, before `"Record macro"`
      - Return identifier `'FlashFirmware'`

   - [ ] 2.2: Update `Public/Start-LWASConsole.ps1`:
      - Add `'FlashFirmware'` case dispatching to
        `Show-FirmwareFlashScreen -Console $Console`

3. [ ] Implement the toggle dispatch function

   - [ ] 3.1: Create `Private/ConsoleApp/Invoke-MouseEmulationToggle.ps1`:
      - `Invoke-MouseEmulationToggle -Console [Spectre.Console.IAnsiConsole]`

      **Pointer acceleration check (runs first when toggling to Hardware):**
      - Read `HKCU:\Control Panel\Mouse` registry key; read the `MouseSpeed` property
      - If `MouseSpeed` is not `"0"`: display a warning panel:
        `"Windows pointer acceleration ('Enhance pointer precision') is active. This will cause
        mouse movements in Hardware mode to be inaccurate. To disable it: Windows Settings →
        Bluetooth & devices → Mouse → Additional mouse settings → Pointer Options →
        uncheck 'Enhance pointer precision'."`
      - The warning is informational only — the user may continue regardless

      **Toggling Software → Hardware:**
      1. Run pointer acceleration check above
      2. Call `Find-LWASHardwareDevice`
      3. If empty: display warning panel
         `"No LWAS hardware device was detected. Plug in the device and select 'Retry',
         or select 'Cancel' to remain in Software mode."` with `SelectionPrompt`
         `'Retry'` / `'Cancel'`; loop on Retry; return without changing config on Cancel
      4. If exactly one device found: call `Connect-LWASHardwareDevice -ComPort $d.ComPort
         -DeviceName $d.DeviceName`; if connection fails, display error panel and return
         without changing config. **Design note:** auto-connecting when exactly one device is
         present is intentional and is **not** preference-based selection. `PreferredDeviceName`
         is purely informational; it only influences the display in `Show-HardwareDeviceScreen`
         when multiple devices are present (annotates the previously used device in the prompt)
      5. If more than one device found: call
         `Show-HardwareDeviceScreen -Console $Console -Devices $devices`; if `$null`
         returned (user cancelled), return without changing config
      6. On successful connection: save `MouseEmulation.Mode = 'Hardware'` and
         `MouseEmulation.PreferredDeviceName = $deviceName` via `Save-ModuleConfiguration`;
         display success panel `"[green]Hardware mouse emulation enabled.[/]"`

      **Toggling Hardware → Software:**
      1. Call `Disconnect-LWASHardwareDevice`
      2. Save `MouseEmulation.Mode = 'Software'` via `Save-ModuleConfiguration`
      3. Display info panel `"Software mouse emulation enabled."`

      - Full comment-based help; all error paths log via `Write-LastWarLog`

   - [ ] 3.2: Create `Tests/ConsoleApp/Invoke-MouseEmulationToggle.Tests.ps1`:
      - Mock `Get-ModuleConfiguration`, `Find-LWASHardwareDevice`,
        `Connect-LWASHardwareDevice`, `Disconnect-LWASHardwareDevice`,
        `Save-ModuleConfiguration`, `Show-HardwareDeviceScreen`, `Write-LastWarLog`,
        `Get-ItemProperty` (for registry read)
      - **Pointer acceleration active (MouseSpeed not "0"):** mock registry returning
        `MouseSpeed = "2"` → warning panel text containing `"Enhance pointer precision"`
        appears in output; flow continues (not aborted)
      - **No pointer acceleration (MouseSpeed = "0"):** warning panel NOT shown
      - **Toggle Software → Hardware, no device, user cancels:** `Find-LWASHardwareDevice`
        returns `@()`; queue `'Cancel'` → `Save-ModuleConfiguration` NOT called
      - **Toggle Software → Hardware, no device, retry then found:** first call `@()`;
        second call returns one device; `Connect-LWASHardwareDevice` returns `$true`;
        `Save-ModuleConfiguration` called with `Mode = 'Hardware'`; success panel in output
      - **Toggle Software → Hardware, one device, connection fails:**
        `Connect-LWASHardwareDevice` returns `$false`; error panel displayed;
        `Save-ModuleConfiguration` NOT called
      - **Toggle Software → Hardware, multiple devices:** `Find-LWASHardwareDevice` returns
        two devices; `Show-HardwareDeviceScreen` called; mock it returning a device;
        `Save-ModuleConfiguration` called with `Mode = 'Hardware'`
      - **Toggle Hardware → Software:** `Disconnect-LWASHardwareDevice` called;
        `Save-ModuleConfiguration` called with `Mode = 'Software'`; info panel in output

4. [ ] Implement the hardware device selection and management screen

   - [ ] 4.1: Create `Private/ConsoleApp/Show-HardwareDeviceScreen.ps1`:
      - `Show-HardwareDeviceScreen -Console [Spectre.Console.IAnsiConsole]
        -Devices [PSCustomObject[]]`
      - Displays a `SelectionPrompt` listing `"$($d.DeviceName) on $($d.ComPort)"` for each
        device — if `$d.DeviceName` matches `PreferredDeviceName` from config, append
        `" (previously used)"` to that entry — plus `"[[Cancel]]"`
      - If `'Cancel'` selected: return `$null`
      - On device selection: call `Connect-LWASHardwareDevice -ComPort $selected.ComPort
        -DeviceName $selected.DeviceName`; if connection fails, display error panel and
        re-show prompt
      - On successful connection: return the selected device object
      - Full comment-based help

   - [ ] 4.2: Create `Tests/ConsoleApp/Show-HardwareDeviceScreen.Tests.ps1`:
      - Mock `Connect-LWASHardwareDevice`, `Get-ModuleConfiguration`
      - User selects a device; connection succeeds → device returned;
        `Connect-LWASHardwareDevice` called once
      - User selects Cancel → `$null` returned; no connection attempted
      - Connection fails first attempt; user selects second device; succeeds → correct device
        returned; `Connect-LWASHardwareDevice` called twice
      - Previous device name shown with `"(previously used)"` suffix in output

5. [ ] Add fast startup warning when config is Hardware mode

   - [ ] 5.1: Update `Private/ConsoleApp/Invoke-StartupConfigValidation.ps1`:
      - If `MouseEmulation.Mode = 'Hardware'`: call `Find-LWASHardwareDevice` (WMI enumeration
        only — no serial connection, no `Connect-LWASHardwareDevice` call)
      - If `Find-LWASHardwareDevice` returns an empty array: add a warning message:
        `"MouseEmulation.Mode is set to Hardware but no LWAS device was found. Software mode
        will be used for mouse control until a device is connected. Use 'Toggle mouse emulation'
        from the main menu to reconnect."`
      - Do not modify config here — display only
      - Log the warning via `Write-LastWarLog -Level Warning`

   - [ ] 5.2: Add tests to `Tests/ConsoleApp/Invoke-StartupConfigValidation.Tests.ps1`:
      - `Mode = 'Hardware'`; `Find-LWASHardwareDevice` returns `@()` → warning panel text
        appears in output; `Connect-LWASHardwareDevice` NOT called; `HasErrors = $false`
      - `Mode = 'Hardware'`; `Find-LWASHardwareDevice` returns one device → no warning shown
      - `Mode = 'Software'` → `Find-LWASHardwareDevice` NOT called; no hardware warning

6. [ ] Update Emergency Stop for Hardware mode

   - [ ] 6.1: Update `Private/EmergencyStop.ps1`:
      - At the start of the emergency stop handler, if `Test-LWASHardwareDeviceConnected`
        returns `$true`:
        1. Send `"ABORT"` via `Invoke-HardwareMouseCommand` — this immediately releases
           all held buttons on the firmware side (button-up HID report sent, click state
           machine reset); the `ABORT` command is designed to be safe to send at any time
        2. Call `Disconnect-LWASHardwareDevice` to close the serial port so no further
           commands can reach the device
      - Both operations are synchronous and fast; neither introduces perceptible latency
        during an emergency stop

   - [ ] 6.2: Add tests to `Tests/EmergencyStop.Tests.ps1`:
      - `Test-LWASHardwareDeviceConnected` returns `$true` → `Invoke-HardwareMouseCommand`
        called with `"ABORT"`; `Disconnect-LWASHardwareDevice` called exactly once
      - `Test-LWASHardwareDeviceConnected` returns `$false` → `Invoke-HardwareMouseCommand`
        NOT called; `Disconnect-LWASHardwareDevice` NOT called

---

## Phase 5: Firmware Flashing

### Architecture decisions (recorded for reference)

- **Firmware binary location:** `powershell-module/esp32-s3-mouse-emulator/firmware/`;
  committed to git inside the module directory tree; listed as binary in `.gitattributes`.
  Included automatically in the release zip and install copy because both operations use
  a wildcard copy of `powershell-module/` (see Phase 5, task 4).
- **Two-folder layout:** The PlatformIO project lives at the repository root
  (`esp32-s3-mouse-emulator/`) and is the build source. The compiled binaries are
  **staged** into `powershell-module/esp32-s3-mouse-emulator/firmware/` (a separate path
  inside the PowerShell module tree). Only the staged binaries are committed to git and
  included in releases. This separation keeps PlatformIO build artefacts (`.pio/`, object
  files) out of the module tree while still allowing the module to ship firmware alongside
  the PowerShell code. A `README.md` and `.gitignore` inside the `firmware/` folder make
  the staging intent explicit and prevent accidental commits of transient build outputs.
- **Console app naming flow:** `Show-FirmwareFlashScreen` flashes via `esptool.exe` and then,
  after the device reboots, sends `SETNAME` over CDC serial to assign a specific name.
- **Web app naming flow:** `Start-LWASFirmwareWebApp` serves `esp-web-tools`; the browser
  flashes firmware only. The device auto-generates a random name on first boot. If the user
  wants a specific name, they use the console app's flash screen or the rename option in
  `Show-HardwareDeviceScreen`.
- **esptool.exe location:** `powershell-module/tools/esptool.exe`; listed as binary in
  `.gitattributes`; version recorded in `lib/VERSIONS.txt`.
- **Web app reference:** Implementation follows the approach described in the esp-web-tools
  tutorial at `https://github.com/witnessmenow/ESP-Web-Tools-Tutorial`, as used by WLED,
  Tasmota, and ESPHome.
- **HTTP server port:** Defaults to 7744; configurable via `-Port` on
  `Start-LWASFirmwareWebApp`.

---

1. [ ] Build and commit firmware binaries

   - [ ] 1.1: Run `pio run -e esp32s3` in `esp32-s3-mouse-emulator/`; locate output at
     `.pio/build/esp32s3/`; confirm build is clean

   - [ ] 1.2: Copy build artefacts into
     `powershell-module/esp32-s3-mouse-emulator/firmware/` (inside the module directory
     tree, **not** the PlatformIO project root):
      - `firmware.bin`
      - `bootloader.bin`
      - `partitions.bin`
      - `firmware_version.txt` — contains the `PROTOCOL_VERSION` string (e.g. `"1.0.0"`)
        on a single line; used by `Connect-LWASHardwareDevice` via a `$PSScriptRoot`-relative
        path and by the web app manifest

     Placing firmware inside `powershell-module/` means it is automatically included in
     `New-LWASRelease.ps1` (which copies `$moduleRoot\*` to staging) and in `Install-LWAS`
     (which copies `$moduleRoot\*` to PSModulePath) without any extra steps.

   - [ ] 1.3: Create `powershell-module/esp32-s3-mouse-emulator/firmware/flash_args.txt`
     with the esptool `write_flash` arguments for this board:

     ```
     --chip esp32s3 --baud 921600 write_flash -z
     0x0000  bootloader.bin
     0x8000  partitions.bin
     0x10000 firmware.bin
     ```

   - [ ] 1.4: Verify that the `.gitattributes` entries added in Phase 1 task 8.1 cover
     `powershell-module/esp32-s3-mouse-emulator/firmware/*.bin` and `*.elf`; commit all
     files in `powershell-module/esp32-s3-mouse-emulator/firmware/`

   - [ ] 1.5: Create `powershell-module/esp32-s3-mouse-emulator/firmware/README.md` with
     the following content (committed to git; survives clean builds):

     ```markdown
     # firmware/

     This directory is a **build output staging area**.

     Binaries here are copied from `../../esp32-s3-mouse-emulator/.pio/build/esp32s3/`
     after a successful PlatformIO build (see Phase 5 task 1 of the hardware emulation
     plan). They are committed to git so the PowerShell module can ship firmware alongside
     the PowerShell code without requiring the developer to have PlatformIO installed.

     ## Files
     | File | Description |
     |------|-------------|
     | `bootloader.bin`       | ESP-IDF second-stage bootloader |
     | `partitions.bin`       | Custom partition table binary |
     | `firmware.bin`         | Main application binary |
     | `firmware_version.txt` | Protocol version string (e.g. `1.0.0`) |
     | `flash_args.txt`       | esptool `write_flash` arguments |

     ## Updating firmware
     1. Edit firmware source in `../../esp32-s3-mouse-emulator/src/`
     2. Run `pio run -e esp32s3` in `../../esp32-s3-mouse-emulator/`
     3. Copy the five files listed above from `.pio/build/esp32s3/` into this directory
     4. Commit the updated binaries
     ```

   - [ ] 1.6: Create `powershell-module/esp32-s3-mouse-emulator/firmware/.gitignore` to
     prevent transient build artefacts from being committed accidentally:

     ```gitignore
     # Ignore everything except the deliberately staged files
     *
     !README.md
     !.gitignore
     !bootloader.bin
     !partitions.bin
     !firmware.bin
     !firmware_version.txt
     !flash_args.txt
     ```

2. [ ] Bundle esptool and implement the console app flash screen

   - [ ] 2.1: Obtain `esptool.exe` from the Espressif esptool GitHub Releases page (Windows
     self-contained build); place at `powershell-module/tools/esptool.exe`; record the version
     in `powershell-module/lib/VERSIONS.txt`:

     ```
     esptool=<version>
     ```

     Add the following line to the repository root `.gitattributes`:

     ```
     powershell-module/tools/esptool.exe binary
     ```

   - [ ] 2.2: Create `Private/HardwareMouse/Invoke-FlashFirmware.ps1`:
      - `Invoke-FlashFirmware -ComPort [string] -FirmwareDir [string]
        -Console [Spectre.Console.IAnsiConsole]`
      - Resolves `esptool.exe` at `Join-Path $PSScriptRoot '..\..\tools\esptool.exe'`;
        writes error and returns `$false` if absent
      - Reads `flash_args.txt` from `$FirmwareDir`; prepends `--port $ComPort` to the
        argument list
      - Runs `Start-Process` with `-Wait -PassThru -NoNewWindow` and redirected stdout/stderr
      - Streams output lines to the console via `$Console.Write()` as they arrive
      - Returns `$true` on exit code 0; `$false` otherwise; logs failure via `Write-LastWarLog`
      - Full comment-based help

   - [ ] 2.2a: Create `Tests/HardwareMouse/HardwareFirmwareFlash.Tests.ps1`:
      - Mock `Test-Path`, `Get-Content`, `Start-Process`
      - `esptool.exe` absent (`Test-Path` returns `$false`) → `Write-Error` called; `$false`
        returned; `Start-Process` NOT called
      - `Start-Process` exit code 0 → `$true` returned
      - `Start-Process` exit code non-zero → `$false` returned; `Write-LastWarLog` called
        with `Level = 'Error'`
      - Correct arguments: `Start-Process` called with `-FilePath` equal to the resolved
        esptool path; `-ArgumentList` includes `--port COM3` prepended before the contents
        of `flash_args.txt`
      - Run full Pester suite; confirm count increases

   - [ ] 2.3: Create `Private/ConsoleApp/Show-FirmwareFlashScreen.ps1`:
      - `Show-FirmwareFlashScreen -Console [Spectre.Console.IAnsiConsole]`

      **Step 1 — Locate firmware:**
      - Resolve firmware directory at
        `Join-Path $PSScriptRoot '..\..\esp32-s3-mouse-emulator\firmware'`
        (resolves to `powershell-module/esp32-s3-mouse-emulator/firmware/` both during
        development and after installation to PSModulePath)
      - If `firmware.bin` absent: display error panel
        `"Firmware files not found. Ensure the module release includes the firmware binaries."`
        and return `$null`
      - Read and display `firmware_version.txt`

      **Step 2 — Device selection:**
      - Display instruction panel:
        `"To enter flash mode: hold the BOOT button, press and release RESET, then release
        BOOT. Click 'Retry' once the device is ready."`
      - Call `Find-LWASHardwareDevice -IncludeAll`; if empty, offer `'Retry'` / `'Cancel'`
        prompt; loop on Retry; return `$null` on Cancel
      - If **multiple devices found**: display error panel
        `"[red]Multiple devices detected. Disconnect all but one device and click 'Retry'.[/]"`
        and offer `'Retry'` / `'Cancel'`; loop on Retry; return `$null` on Cancel — flashing
        only proceeds when **exactly one** device is connected (prevents flashing the wrong device)

      **Step 3 — Device naming:**
      - `TextPrompt` `"Enter a 6-character uppercase hex suffix for the device name
        (e.g. A3F2C9), or press [[Enter]] to generate one randomly:"`
      - If empty: generate via `'{0:X6}' -f (Get-Random -Maximum 0xFFFFFF)` and convert
        to uppercase
      - Validate against `^[0-9A-F]{6}$`; re-prompt on failure
      - Show confirmation: `"Device will be named: LWAS_Mouse_Emulator_<suffix>"`
      - `SelectionPrompt` `'Confirm'` / `'Change suffix'` / `'Cancel'`; loop on Change;
        return `$null` on Cancel

      **Step 4 — Flash:**
      - Display panel: `"Flashing firmware — do not disconnect the device."`
      - Call `Invoke-FlashFirmware -ComPort $port -FirmwareDir $firmwareDir -Console $Console`
      - On success: `Start-Sleep -Seconds 3` (allow device to reboot into normal mode);
        call `Find-LWASHardwareDevice -IncludeAll` to re-enumerate (the COM port assignment
        may change after a firmware update); if exactly one device is found, call
        `Connect-LWASHardwareDevice -ComPort $device.ComPort -DeviceName "" -SkipNameValidation`
        (name validation is skipped because `SETNAME` has not yet been sent);
        if connection succeeds, send `"SETNAME $suffix"` via `Invoke-HardwareMouseCommand`;
        verify response starts with `"ACK OK"`; display success panel
        `"[green]Firmware flashed. Device name: LWAS_Mouse_Emulator_$suffix[/]"`;
        call `Disconnect-LWASHardwareDevice`
      - On flash failure: display error panel; offer `'Retry'` / `'Cancel'`; loop on Retry
      - Return `$null`; full comment-based help

   - [ ] 2.4: Create `Tests/ConsoleApp/Show-FirmwareFlashScreen.Tests.ps1`:
      - Mock `Find-LWASHardwareDevice`, `Invoke-FlashFirmware`, `Connect-LWASHardwareDevice`,
        `Disconnect-LWASHardwareDevice`, `Invoke-HardwareMouseCommand`, `Test-Path`,
        `Start-Sleep`, `Get-Random`
      - Firmware files not found: `Test-Path` returns `$false` → error panel shown; `$null`
        returned; `Invoke-FlashFirmware` NOT called
      - No device found, user cancels: `Find-LWASHardwareDevice` returns `@()`; queue
        `'Cancel'` → `$null` returned
      - Valid suffix entered: queue `"A3F2C9"` → confirm; `Invoke-FlashFirmware` called;
        `Find-LWASHardwareDevice -IncludeAll` called after sleep; `Connect-LWASHardwareDevice`
        called with `-SkipNameValidation`; `"SETNAME A3F2C9"` sent; success panel in output
      - Empty input generates random suffix: mock `Get-Random` returning `0xA3F2C9`; queue
        empty → suffix `"A3F2C9"` appears in confirmation panel
      - Invalid suffix re-prompts: queue `"abc"` → error shown; queue `"A3F2C9"` → accepted
      - Flash fails, user retries: `Invoke-FlashFirmware` returns `$false` first, `$true`
        second; queue `'Retry'`; `Invoke-FlashFirmware` called twice
      - Run full Pester suite; confirm count increases

3. [ ] Implement the firmware web app

   - [ ] 3.1: Create `powershell-module/tools/firmware-web-app/index.html`:
      - Self-contained single-page app following the `esp-web-tools` approach documented at
        `https://github.com/witnessmenow/ESP-Web-Tools-Tutorial`
      - Import `esp-web-tools` via CDN, pinned to a specific version:

        ```html
        <script type="module"
          src="https://unpkg.com/esp-web-tools@<VERSION>/dist/web/install-button.js?module">
        </script>
        ```

        At implementation time, check <https://www.npmjs.com/package/esp-web-tools> for the
        current latest version and substitute it for `<VERSION>`; record the pinned version
        in `powershell-module/lib/VERSIONS.txt` (e.g. `esp-web-tools=10.0.1`)
      - Include `<esp-web-install-button manifest="/firmware/manifest.json">` as the primary
        install element
      - Display a clear note that Chrome or Edge is required (Web Serial API)
      - After the install button, display a help section explaining:
        - The device will auto-generate a random name (`LWAS_Mouse_Emulator_XXXXXX`) on first
          boot
        - To assign a specific name, use `"Flash device firmware"` in the LWAS console app
          instead, or use `"Toggle mouse emulation"` to connect and rename after flashing

   - [ ] 3.2: Create `powershell-module/tools/firmware-web-app/manifest.json`:
      - `esp-web-tools` manifest format; version read from `firmware_version.txt`:

        ```json
        {
          "name": "LWAS Mouse Emulator",
          "version": "1.0.0",
          "builds": [
            {
              "chipFamily": "ESP32-S3",
              "parts": [
                { "path": "/firmware/bootloader.bin",  "offset": "0x0000" },
                { "path": "/firmware/partitions.bin",  "offset": "0x8000" },
                { "path": "/firmware/firmware.bin",    "offset": "0x10000" }
              ]
            }
          ]
        }
        ```

      - The `version` field must match the content of `firmware_version.txt`; update both
        together whenever the firmware is rebuilt

   - [ ] 3.3: Create `Public/Start-LWASFirmwareWebApp.ps1`:
      - `Start-LWASFirmwareWebApp -Port [int] = 7744`; `[CmdletBinding()]`
      - Resolves `tools/firmware-web-app/` and `esp32-s3-mouse-emulator/firmware/` relative
        to `$PSScriptRoot` (both live inside the module directory and resolve correctly
        both in development and after installation); calls `Write-Error` and returns if
        either directory is missing
      - Starts `[System.Net.HttpListener]` on `http://localhost:$Port/`
      - Request handling:
        - `GET /firmware/manifest.json` → serve `manifest.json` from the firmware directory;
          `Content-Type: application/json`
        - `GET /firmware/*.bin` → serve the named file from the firmware directory;
          `Content-Type: application/octet-stream`
        - All other `GET` requests → serve from `tools/firmware-web-app/`; determine MIME
          type from extension; 404 for missing files
      - After starting the listener: call `Start-Process "http://localhost:$Port"` (opens the
        default browser); write
        `"Firmware web app running at http://localhost:$Port/ — press Ctrl+C to stop."`
      - Register `[Console]::CancelKeyPress` handler to stop the listener on Ctrl+C
      - Add `'Start-LWASFirmwareWebApp'` to `FunctionsToExport` in
        `LastWarAutoScreenshot.psd1`
      - Full comment-based help with an `.EXAMPLE` showing the function call

   - [ ] 3.4: Create `Tests/Start-LWASFirmwareWebApp.Tests.ps1`:
      - Mock `[System.Net.HttpListener]` and `Start-Process`
      - Web app directory not found → `Write-Error` called; `HttpListener.Start` NOT called
      - Firmware directory not found → `Write-Error` called; listener not started
      - Valid setup → `HttpListener.Start()` called; `Start-Process` called with URL
        containing `localhost:7744`
      - Custom `-Port 8080` → URL contains `localhost:8080`

4. [ ] Verify hardware tools are included in release and install

   - [ ] 4.1: Verify `New-LWASRelease.ps1` staging includes all hardware tool artefacts:
      - Confirm the existing `Copy-Item -Path "$moduleRoot\*" -Recurse` wildcard picks up
        `powershell-module/tools/esptool.exe`, `powershell-module/tools/firmware-web-app/`,
        and `powershell-module/esp32-s3-mouse-emulator/firmware/`; all are inside
        `$moduleRoot` and require no additional copy steps
      - Confirm `Docs/` remains the only excluded directory; no `tools/` or
        `esp32-s3-mouse-emulator/` exclusions are present

   - [ ] 4.2: Verify `Install-LWAS` (the public function) includes the hardware tools:
      - The existing `Copy-Item -Path "$moduleRoot\*" -Destination $installPath -Recurse`
        already copies all subdirectories; no extra steps are required
      - After an installation run, manually confirm these paths exist under the installed
        module directory: `tools\esptool.exe`, `tools\firmware-web-app\index.html`,
        `esp32-s3-mouse-emulator\firmware\firmware.bin`,
        `esp32-s3-mouse-emulator\firmware\firmware_version.txt`

   - [ ] 4.3: Add to the Phase 6 pre-release checklist: before creating the release zip,
      confirm `tools\esptool.exe`, `tools\firmware-web-app\`, and
      `esp32-s3-mouse-emulator\firmware\firmware.bin` are present in the staging directory

---

## Phase 6: Testing and Validation

1. [ ] Run the full Pester suite

   - [ ] 1.1: Run `Invoke-Pester -Path .\powershell-module\Tests -Output Detailed`
      - Total count must meet or exceed the Phase 9b baseline plus all new tests added across
        Phases 3–5
      - Zero failures; zero errors
      - If any previously-passing test now fails, halt and investigate before proceeding

2. [ ] Run the PlatformIO native tests

   - [ ] 2.1: Run `pio test -e native` from `esp32-s3-mouse-emulator/`
      - All tests in `test_command_handler`, `test_mouse_controller`, `test_device_config`,
        `test_logger` pass; zero failures

3. [ ] Manually smoke-test firmware build and flash

   - [ ] 3.1: Run `pio run -e esp32s3` → confirm clean build with no errors or warnings
   - [ ] 3.2: Flash via `Show-FirmwareFlashScreen` in the console app → confirm device appears
     in Windows Device Manager as `LWAS_Mouse_Emulator_XXXXXX`; confirm CDC serial port listed
   - [ ] 3.3: Flash via `Start-LWASFirmwareWebApp` in Edge → confirm device reboots with a
     valid auto-generated name; confirm the device is subsequently detected by
     `Find-LWASHardwareDevice`

4. [ ] Manually smoke-test Hardware mode

   - [ ] 4.1: Launch `Start-LWASConsole` with pointer acceleration active → warning panel
     shown when toggling to Hardware mode
   - [ ] 4.2: Toggle to Hardware mode with no device plugged in → warning panel; mode not
     changed; label remains `"(Software)"`
   - [ ] 4.3: Plug in device; toggle to Hardware mode → detected; connected; label updates to
     `"(Hardware)"`
   - [ ] 4.4: Run a macro with MoveToPoint, LeftClick, DragClick, and Delay actions in
     Hardware mode → movements execute without SendInput
   - [ ] 4.5: Unplug device during macro execution → retry logic activates; prompt shown;
     re-plug → macro continues
   - [ ] 4.6: Trigger emergency stop (Ctrl+Alt+Q) during Hardware mode → macro halts cleanly
   - [ ] 4.7: Toggle back to Software mode → label reverts; subsequent macros use SendInput

---

## Phase 7: Documentation and Validation

1. [ ] Update `CLAUDE.md`

   - [ ] 1.1: Update "Current status" to reflect the hardware emulation phase
   - [ ] 1.2: Add `Start-LWASFirmwareWebApp` to the commands section with a usage example

2. [ ] Create `powershell-module/Docs/HardwareMouseEmulation.md`

   - [ ] 2.1: Document the following sections:
      - **Overview:** purpose; why hardware HID reduces detection risk vs SendInput
      - **Prerequisites:** Windows 10 or 11; Chrome or Edge for the web app only; no extra
        drivers needed
      - **Supported hardware:** 4D Systems ESP32-S3 Gen4 R8N16
      - **Getting started:** flash firmware → toggle Hardware mode → run a macro
      - **Command protocol reference** (commands and responses table)
      - **Device naming:** auto-generated on first boot; how to assign a specific name via
        the console app; how to rename a connected device
      - **Troubleshooting:**

        | Symptom | Resolution |
        |---|---|
        | Device not detected | Check USB cable is data-capable (not charge-only); try a different USB port; wait a few seconds after plug-in |
        | COM port in Device Manager but module cannot connect | Press RESET to exit flash mode |
        | Movements are inaccurate | Disable "Enhance pointer precision" — Windows Settings → Bluetooth & devices → Mouse → Additional mouse settings → Pointer Options |
        | `ACK ERR` responses | Major version mismatch — reflash latest firmware |
        | Web app does not open serial port | Use Chrome or Edge; accept the serial port permission prompt |

      - **Developer section:** build from source; run Unity tests; update protocol version
        (requires updating `PROTOCOL_MAJOR`/`PROTOCOL_MINOR` in `protocol.h`, rebuilding,
        updating `firmware_version.txt`, updating `manifest.json`, and recommitting binaries)

   - [ ] 2.2: Add a link to `HardwareMouseEmulation.md` in `Docs/UserGuide.md` under a new
     "Hardware Mouse Emulation" section

3. [ ] Update `esp32-s3-mouse-emulator/README.md`

   - [ ] 3.1: Replace the Phase 8 stub with full content:
      - Project structure overview
      - Build: `pio run -e esp32s3`
      - Flash: via console app or web app (end users); `pio run -e esp32s3 --target upload`
        (development)
      - Test: `pio test -e native`; hardware tests require a physical device
        (`pio test -e esp32s3 --filter test_hardware_only`)
      - Protocol reference table
      - Adding a new command: update `protocol.h`; implement in `command_handler.cpp`; add a
        test in `test_command_handler/test_command_handler.cpp`

4. [ ] Update `powershell-module/Docs/Configuration.md`

   - [ ] 4.1: Document the `MouseEmulation` config section with all keys, types, defaults,
     valid values, and descriptions

5. [ ] Check `New-LWASRelease.ps1` for firmware version consistency

   - [ ] 5.1: Add a check to `scripts/New-LWASRelease.ps1` that reads
     `powershell-module/esp32-s3-mouse-emulator/firmware/firmware_version.txt` and compares
     it with `PROTOCOL_VERSION` in `esp32-s3-mouse-emulator/include/protocol.h` (via regex);
     if they differ, fail the release with a clear error:
     `"Firmware version mismatch: firmware_version.txt says '$fileVersion' but protocol.h says '$headerVersion'. Rebuild and recommit firmware binaries before releasing."`

6. [ ] Final test run

   - [ ] 6.1: Run `Invoke-Pester -Path .\powershell-module\Tests -Output Detailed`; zero
     failures; record final test count
   - [ ] 6.2: Run `pio test -e native`; zero failures

---

## Known Issues

The following are potential problems that should be reviewed before the relevant phase begins.

**1. ESP32-S3 USB port routing on the 4D Systems Gen4 R8N16 board**

Verify which USB connector on this specific board routes to the ESP32-S3's native USB OTG
peripheral (required for the HID+CDC composite device) versus the UART bridge (used in some
development workflows). These may be physically different connectors on the board. Check the
board's hardware schematic or datasheet before Phase 1 task 2.2.

**2. Serial port not closed on module force-reimport**

`Import-Module LastWarAutoScreenshot -Force` resets script-scope variables, orphaning the open
COM port. Phase 3 task 3.3 registers a `Module.OnRemove` hook to close it. Verify this hook
fires correctly with `-Force` reimport on PowerShell 7, as behaviour is version-dependent.
Test explicitly during Phase 6 smoke testing.

**3. WMI device propagation delay at startup**

`Find-LWASHardwareDevice` (used for the fast startup warning) queries WMI. If the device was
just plugged in, WMI may not yet reflect it. The startup check is informational only so a
false "not found" result is acceptable — the user will see the warning and can use the toggle
to connect. Document this in `.NOTES` on `Find-LWASHardwareDevice`.

**4. USB composite device on enterprise-managed Windows machines**

Domain-joined machines with USB device restrictions may block new CDC or HID interfaces.
Test on a domain-joined machine if the target user base includes enterprise environments.

**5. `esp-web-tools` CDN dependency**

The web app loads `esp-web-tools` from `unpkg.com`. Offline environments will not be able to
flash via the web app. Add a note to `Start-LWASFirmwareWebApp` help and the web app HTML
that an internet connection is required, and that the console app flash screen works offline.
