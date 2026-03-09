using System;
using System.Runtime.InteropServices;

namespace LastWarAutoScreenshot
{
    /// <summary>
    /// Exposes the Win32 PrintWindow API used for window capture.
    /// Bitmap creation, cropping, and PNG saving are handled in the PowerShell
    /// wrapper functions (Invoke-CaptureWindowRegion, Invoke-CompareImages) using
    /// System.Drawing at runtime, avoiding the need to compile against
    /// System.Drawing.Common in this C# source file.
    /// </summary>
    public static class ScreenCaptureAPI
    {
        // PW_RENDERFULLCONTENT instructs DWM to composite all hardware-accelerated
        // surfaces (OpenGL, DirectX) into the provided HDC.  Required for games.
        // The window must not be minimised; exclusive-fullscreen windows are not supported.
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);

        public const uint PW_RENDERFULLCONTENT = 0x00000002;
    }
}
