using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Diagnostics;
using System.Text.Json;

namespace LastWarAutoScreenshot
{
    public abstract class LogBackend
    {
        public abstract void Log(string message, string level, string functionName, string context, string logStackTrace);
    }
}