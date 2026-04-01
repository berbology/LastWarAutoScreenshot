using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace LastWarAutoScreenshot
{
    public class FileLogBackend : LogBackend
    {
        private readonly string _logFilePath;
        private readonly string _logDir;
        private readonly string _logBaseName;
        private readonly int _maxSizeMB;
        private readonly int _maxAgeDays;
        private readonly int _maxLogFileCount;

        public FileLogBackend(string logFilePath)
        {
            _logFilePath = logFilePath;
            _logDir = Path.GetDirectoryName(logFilePath);
            _logBaseName = Path.GetFileName(logFilePath);

            // Add null checks for _logDir and _logBaseName
            if (string.IsNullOrEmpty(_logDir) || string.IsNullOrEmpty(_logBaseName))
            {
                throw new InvalidOperationException("Log directory or base name cannot be null or empty.");
            }

            // Default settings (loaded via Get-ModuleConfiguration in PowerShell layer)
            _maxSizeMB = 50;
            _maxAgeDays = 30;
            _maxLogFileCount = 500;
        }

        public override void Log(string message, string level, string functionName, string context, string logStackTrace)
        {
            var logEntry = new
            {
                Timestamp = DateTime.UtcNow.ToString("o"),
                FunctionName = functionName,
                ErrorType = level,
                Message = message,
                Context = context,
                LogStackTrace = logStackTrace
            };

            string logMsg = System.Text.Json.JsonSerializer.Serialize(logEntry);

            try
            {
                bool rolledOver = InvokeRolloverIfNeeded();
                File.AppendAllText(_logFilePath, logMsg + Environment.NewLine);
                // Break NTFS file-system tunnelling: when a new file is created with the same
                // name as a recently renamed/deleted file, Windows preserves the original
                // creation timestamp. This would immediately re-trigger the age-based rollover
                // on every subsequent write. Explicitly stamping the creation time after a
                // rollover prevents that infinite-rotation loop.
                if (rolledOver)
                {
                    File.SetCreationTimeUtc(_logFilePath, DateTime.UtcNow);
                }
                CleanupOldLogs();
            }
            catch
            {
                throw;
            }
        }

        private bool InvokeRolloverIfNeeded()
        {
            if (!File.Exists(_logFilePath)) return false;

            FileInfo fileInfo = new FileInfo(_logFilePath);
            double sizeMB = fileInfo.Length / (1024.0 * 1024.0);
            double ageDays = (DateTime.UtcNow - fileInfo.CreationTimeUtc).TotalDays;

            if (sizeMB >= _maxSizeMB || ageDays >= _maxAgeDays)
            {
                string rolloverFileName = Path.Combine(_logDir, _logBaseName + $".{DateTime.UtcNow:yyyyMMddHHmmss}");
                File.Move(_logFilePath, rolloverFileName);
                return true;
            }

            return false;
        }

        private void CleanupOldLogs()
        {
            var logFiles = Directory.GetFiles(_logDir, _logBaseName + "*")
                                     .Select(f => new FileInfo(f))
                                     .OrderBy(f => f.LastWriteTimeUtc)
                                     .ToList();

            if (logFiles.Count <= _maxLogFileCount) return;

            foreach (var file in logFiles.Take(logFiles.Count - _maxLogFileCount))
            {
                try
                {
                    file.Delete();
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Warning: Failed to delete old log file {file.FullName}: {ex.Message}");
                }
            }
        }
    }
}
