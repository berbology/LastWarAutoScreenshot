using System;
using System.Runtime.InteropServices;
using System.Timers;

namespace LastWarAutoScreenshot
{
    public static class MouseControlAPI
    {
        // Structs
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Explicit, Size = 40)]
        public struct INPUT
        {
            [FieldOffset(0)]
            public uint type;
            [FieldOffset(4)]
            public uint pad;
            [FieldOffset(8)]
            public MOUSEINPUT mi;
        }

        // Constants
        public const uint INPUT_MOUSE = 0;
        public const uint MOUSEEVENTF_MOVE       = 0x0001;
        public const uint MOUSEEVENTF_LEFTDOWN   = 0x0002;
        public const uint MOUSEEVENTF_LEFTUP     = 0x0004;
        public const uint MOUSEEVENTF_ABSOLUTE   = 0x8000;
        public const uint MOUSEEVENTF_VIRTUALDESK = 0x4000;

        // System metric indices for virtual desktop dimensions/origin
        // Used when normalising absolute coordinates for MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK
        public const int SM_XVIRTUALSCREEN  = 76;
        public const int SM_YVIRTUALSCREEN  = 77;
        public const int SM_CXVIRTUALSCREEN = 78;
        public const int SM_CYVIRTUALSCREEN = 79;

        // P/Invoke declarations
        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetCursorPos(out POINT lpPoint);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetCursorPos(int X, int Y);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll", SetLastError = false)]
        public static extern int GetSystemMetrics(int nIndex);

        // GetAsyncKeyState returns a short whose high-order bit (0x8000) indicates
        // whether the key is currently held down.  The low-order bit records whether
        // the key was pressed since the last call (unreliable; do not use it).
        //
        // Virtual key code notes:
        //   0x11 (17)  = VK_CONTROL  (Ctrl)
        //   0x10 (16)  = VK_SHIFT    (Shift)
        //   0xDC (220) = VK_OEM_5    ('#' on UK QWERTY layouts)
        //                            ('\' on standard US layouts)
        // Configure HotkeyVKeyCodes in the module configuration to match your keyboard layout.
        //
        // SetLastError = false: GetAsyncKeyState does not set the Windows error code.
        [DllImport("user32.dll", SetLastError = false)]
        public static extern short GetAsyncKeyState(int vKey);
    }

    // Polls GetAsyncKeyState on the System.Timers.Timer thread-pool thread without
    // requiring a PowerShell runspace.  A plain PowerShell scriptblock Elapsed handler
    // cannot execute while the macro runspace is busy — it silently throws and is
    // caught, so the flag is never set.  A true C# delegate bypasses that entirely.
    public static class EmergencyStopMonitor
    {
        private static int[]  _hotkeyVKeyCodes;
        private static bool   _mouseGestureEnabled;
        private static int[]  _mouseGestureVKeyCodes;
        private static int    _mouseGestureRequiredPollCount;
        // Accessed only on the single timer-thread; no contention.
        private static int    _mouseGestureCurrentPollCount;
        // Number of consecutive polls where not all gesture buttons were held.
        // Allows up to 1 missed poll (from an injected MOUSEEVENTF_LEFTUP during a
        // macro click) without resetting the accumulated hold count.
        private static int    _mouseGestureBreakCount;

        // Read by the PowerShell macro thread, written by the timer thread.
        // volatile ensures neither compiler nor CPU reorders or caches the read.
        public static volatile bool StopRequested;

        // Called by Start-LWASEmergencyStopMonitor before the timer starts.
        // All writes happen before timer.Start(), which provides the required
        // memory-barrier so the timer thread sees the initialised values.
        public static void Configure(
            int[] hotkeyVKeyCodes,
            bool  mouseGestureEnabled,
            int[] mouseGestureVKeyCodes,
            int   mouseGestureRequiredPollCount)
        {
            _hotkeyVKeyCodes               = hotkeyVKeyCodes;
            _mouseGestureEnabled           = mouseGestureEnabled;
            _mouseGestureVKeyCodes         = mouseGestureVKeyCodes;
            _mouseGestureRequiredPollCount = mouseGestureRequiredPollCount;
            _mouseGestureCurrentPollCount  = 0;
            _mouseGestureBreakCount        = 0;
            StopRequested                  = false;
        }

        // Attached to System.Timers.Timer.Elapsed via System.Delegate.CreateDelegate
        // so the CLR invokes it directly on the thread-pool thread — no PowerShell
        // runspace involved.
        public static void HandleElapsed(object sender, ElapsedEventArgs e)
        {
            if (StopRequested) return;

            // Hotkey check — all configured virtual key codes must be held simultaneously.
            int[] keys = _hotkeyVKeyCodes;
            if (keys != null && keys.Length > 0)
            {
                bool allHeld = true;
                foreach (int vk in keys)
                {
                    if ((MouseControlAPI.GetAsyncKeyState(vk) & 0x8000) == 0)
                    {
                        allHeld = false;
                        break;
                    }
                }
                if (allHeld)
                {
                    StopRequested = true;
                    return;
                }
            }

            // Mouse gesture check — both mouse buttons held for the required number of
            // consecutive polls.
            if (_mouseGestureEnabled)
            {
                int[] gestureCodes = _mouseGestureVKeyCodes;
                if (gestureCodes != null && gestureCodes.Length > 0)
                {
                    bool allHeld = true;
                    foreach (int vk in gestureCodes)
                    {
                        if ((MouseControlAPI.GetAsyncKeyState(vk) & 0x8000) == 0)
                        {
                            allHeld = false;
                            break;
                        }
                    }
                    if (allHeld)
                    {
                        _mouseGestureBreakCount = 0;
                        _mouseGestureCurrentPollCount++;
                        if (_mouseGestureCurrentPollCount >= _mouseGestureRequiredPollCount)
                            StopRequested = true;
                    }
                    else
                    {
                        // Tolerate up to 1 missed poll before resetting the hold counter.
                        // The macro injects MOUSEEVENTF_LEFTUP on every click, which causes
                        // GetAsyncKeyState(VK_LBUTTON) to return 0 for the poll immediately
                        // after the injected button-up event — even when the user is physically
                        // holding the button.  Without tolerance, the accumulated count resets
                        // on nearly every macro click, making the gesture impossible to trigger.
                        _mouseGestureBreakCount++;
                        if (_mouseGestureBreakCount > 1)
                        {
                            _mouseGestureCurrentPollCount = 0;
                            _mouseGestureBreakCount       = 0;
                        }
                    }
                }
            }
        }
    }
}
