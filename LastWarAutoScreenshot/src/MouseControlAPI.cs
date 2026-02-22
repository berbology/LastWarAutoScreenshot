using System;
using System.Runtime.InteropServices;

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

        [StructLayout(LayoutKind.Explicit)]
        public struct INPUT
        {
            [FieldOffset(0)]
            public uint type;
            [FieldOffset(8)]
            public MOUSEINPUT mi;
        }

        // Constants
        public const uint INPUT_MOUSE = 0;
        public const uint MOUSEEVENTF_MOVE = 0x0001;
        public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        public const uint MOUSEEVENTF_LEFTUP = 0x0004;

        // P/Invoke declarations
        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetCursorPos(out POINT lpPoint);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

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
}
