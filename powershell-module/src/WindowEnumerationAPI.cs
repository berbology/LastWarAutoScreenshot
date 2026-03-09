using System;
using System.Runtime.InteropServices;
using System.Text;

namespace LastWarAutoScreenshot
{
    /// <summary>
    /// Delegate for EnumWindows callback function
    /// </summary>
    /// <param name="hWnd">Handle to the window</param>
    /// <param name="lParam">Application-defined value</param>
    /// <returns>True to continue enumeration, false to stop</returns>
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    /// <summary>
    /// Provides P/Invoke signatures for Win32 API window enumeration functions.
    /// </summary>
    /// <remarks>
    /// <para>Description:</para>
    /// <para>This class defines the necessary Win32 API functions and delegates for enumerating
    /// windows, retrieving window information, and checking window states. All functions
    /// are defined in the User32.dll library.</para>
    /// <para>Notes:</para>
    /// <list type="bullet">
    /// <item>Memory Management:</item>
    /// <list type="bullet">
    /// <item>Window handles (HWND) are managed by Windows and do not require cleanup.</item>
    /// <item>The EnumWindowsProc delegate must remain in scope during enumeration to prevent
    /// premature garbage collection by the CLR.</item>
    /// <item>StringBuilder objects for GetWindowText are automatically managed by .NET.</item>
    /// </list>
    /// <item>Error Handling:</item>
    /// <list type="bullet">
    /// <item>All functions return error codes or boolean values that should be checked.</item>
    /// <item>Use try-catch blocks when calling these functions.</item>
    /// <item>GetLastError() can be called via <c>[System.Runtime.InteropServices.Marshal]::GetLastWin32Error()</c>.</item>
    /// </list>
    /// </list>
    /// <example>
    /// <code>
    /// // Example: Find and print details for a window by process ID
    /// int targetPid = 12345;
    /// bool found = false;
    /// EnumWindowsProc callback = (hwnd, lParam) =>
    /// {
    ///     uint procId;
    ///     GetWindowThreadProcessId(hwnd, out procId);
    ///     if (procId == targetPid && IsWindowVisible(hwnd))
    ///     {
    ///         int titleLen = GetWindowTextLength(hwnd);
    ///         if (titleLen > 0)
    ///         {
    ///             StringBuilder sb = new StringBuilder(titleLen + 1);
    ///             GetWindowText(hwnd, sb, sb.Capacity);
    ///             Console.WriteLine($"Found HWND: {hwnd} | Title: {sb}");
    ///         }
    ///         found = true;
    ///         return false; // Stop enumeration
    ///     }
    ///     return true; // Continue enumeration
    /// };
    /// EnumWindows(callback, IntPtr.Zero);
    /// if (!found) Console.WriteLine("No visible window found for process");
    /// </code>
    /// </example>
    /// </remarks>
    public class WindowEnumerationAPI
    {
        /// <summary>
        /// Enumerates all top-level windows by passing handle to each window to callback function
        /// </summary>
        /// <param name="lpEnumFunc">Pointer to application-defined callback function</param>
        /// <param name="lParam">Application-defined value passed to callback</param>
        /// <returns>True if successful, false otherwise</returns>
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        /// <summary>
        /// Retrieves the text of the specified window's title bar
        /// </summary>
        /// <param name="hWnd">Handle to the window</param>
        /// <param name="lpString">Buffer to receive the text</param>
        /// <param name="nMaxCount">Maximum number of characters to copy</param>
        /// <returns>Length of copied string, or 0 on failure</returns>
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        /// <summary>
        /// Retrieves the length of the specified window's title bar text
        /// </summary>
        /// <param name="hWnd">Handle to the window</param>
        /// <returns>Length of text in characters, or 0 if no title</returns>
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern int GetWindowTextLength(IntPtr hWnd);

        /// <summary>
        /// Determines visibility state of the specified window
        /// </summary>
        /// <param name="hWnd">Handle to the window</param>
        /// <returns>True if window is visible, false otherwise</returns>
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        /// <summary>
        /// Retrieves the identifier of the thread and process that created the window
        /// </summary>
        /// <param name="hWnd">Handle to the window</param>
        /// <param name="lpdwProcessId">Pointer to variable that receives process identifier</param>
        /// <returns>Identifier of the thread that created the window</returns>
        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        /// <summary>
        /// Determines whether the specified window is minimized (iconic)
        /// </summary>
        /// <param name="hWnd">Handle to the window</param>
        /// <returns>True if window is minimized, false otherwise</returns>
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool IsIconic(IntPtr hWnd);

        /// <summary>
        /// Retrieves a handle to the foreground window (the window with which the user is currently working)
        /// </summary>
        /// <returns>Handle to the foreground window, or IntPtr.Zero if no foreground window exists</returns>
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr GetForegroundWindow();

        /// <summary>
        /// Sets the specified window's show state (minimize or maximize only)
        /// </summary>
        /// <param name="hWnd">Handle to the window</param>
        /// <param name="nCmdShow">Show state (2 = minimize, 3 = maximize)</param>
        /// <returns>True if successful, false otherwise</returns>
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        /// <summary>
        /// Brings the specified window to the foreground (activates it)
        /// </summary>
        /// <param name="hWnd">Handle to the window</param>
        /// <returns>True if successful, false otherwise</returns>
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
    }
}