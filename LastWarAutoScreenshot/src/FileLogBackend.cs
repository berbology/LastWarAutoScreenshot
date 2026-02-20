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
        private readonly int _maxFileCount;
        private readonly int _maxAgeDays;
        private readonly int _retentionFileCount;

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

            // Default settings
            _maxSizeMB = 50;
            _maxFileCount = 50;
            _maxAgeDays = 30;
            _retentionFileCount = 500;

            // Load settings from configuration file if available
            string configPath = Path.Combine(_logDir, "ModuleConfig.json");
            if (File.Exists(configPath))
            {
                try
                {
                    var config = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, object>>(File.ReadAllText(configPath));
                    if (config != null && config.ContainsKey("Logging") && config["Logging"] is Dictionary<string, object> loggingConfig && loggingConfig.ContainsKey("FileBackend"))
                    {
                        var fileBackend = loggingConfig["FileBackend"] as Dictionary<string, object>;
                        if (fileBackend != null)
                        {
                            _maxSizeMB = Convert.ToInt32(fileBackend.GetValueOrDefault("MaxSizeMB", _maxSizeMB));
                            _maxFileCount = Convert.ToInt32(fileBackend.GetValueOrDefault("MaxFileCount", _maxFileCount));
                            _maxAgeDays = Convert.ToInt32(fileBackend.GetValueOrDefault("MaxAgeDays", _maxAgeDays));
                            _retentionFileCount = Convert.ToInt32(fileBackend.GetValueOrDefault("RetentionFileCount", _retentionFileCount));
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Warning: Failed to load file backend config: {ex.Message}");
                }
            }
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
                InvokeRolloverIfNeeded();
                File.AppendAllText(_logFilePath, logMsg + Environment.NewLine);
                CleanupOldLogs();
            }
            catch
            {
                throw;
            }
        }

        private void InvokeRolloverIfNeeded()
        {
            if (!File.Exists(_logFilePath)) return;

            FileInfo fileInfo = new FileInfo(_logFilePath);
            double sizeMB = fileInfo.Length / (1024.0 * 1024.0);
            double ageDays = (DateTime.UtcNow - fileInfo.CreationTimeUtc).TotalDays;

            if (sizeMB >= _maxSizeMB || ageDays >= _maxAgeDays || Directory.GetFiles(_logDir, _logBaseName + "*").Length >= _maxFileCount)
            {
                string rolloverFileName = Path.Combine(_logDir, _logBaseName + $".{DateTime.UtcNow:yyyyMMddHHmmss}");
                File.Move(_logFilePath, rolloverFileName);
            }
        }

        private void CleanupOldLogs()
        {
            var logFiles = Directory.GetFiles(_logDir, _logBaseName + "*")
                                     .Select(f => new FileInfo(f))
                                     .OrderBy(f => f.LastWriteTimeUtc)
                                     .ToList();

            if (logFiles.Count <= _retentionFileCount) return;

            foreach (var file in logFiles.Take(logFiles.Count - _retentionFileCount))
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