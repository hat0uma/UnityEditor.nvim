using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;
using UnityEngine;

namespace NeovimEditor
{
    /// <summary>
    /// Log entry
    /// </summary>
    [Serializable]
    public struct LogEntry
    {
        public string file;
        public int line;
        public int column;
        public string message;
        public string severity;
    }

    /// <summary>
    /// Logs response containing list of log entries.
    /// </summary>
    [Serializable]
    public struct LogsResponse
    {
        public LogEntry[] items;
    }


    /// <summary>
    /// Provider for retrieving log history from Unity Editor's Console.
    /// </summary>
    public class LogHistoryProvider
    {
        private static string _projectRoot;
        private static string ProjectRoot => _projectRoot ??= Directory.GetParent(Application.dataPath).FullName;

        // Reusable LogEntry wrapper
        private readonly UnityEditor_LogEntry _logEntry;

        public LogHistoryProvider()
        {
            if (UnityEditor_LogEntry.IsAvailable)
            {
                _logEntry = new UnityEditor_LogEntry();
            }
        }

        public List<LogEntry> GetLogHistories()
        {
            var result = new List<LogEntry>();
            if (_logEntry == null)
            {
                return result;
            }

            // Save current console flags
            var originalFlags = UnityEditor_LogEntry.ConsoleFlags;

            // Enable timestamp display
            UnityEditor_LogEntry.SetConsoleFlag(UnityEditor_LogEntry.SHOWTIMESTAMP_FLAG, true);
            UnityEditor_LogEntry.StartGettingEntries();
            try
            {
                var count = UnityEditor_LogEntry.GetCount();
                for (int i = 0; i < count; i++)
                {
                    if (_logEntry.GetEntryInternal(i))
                    {
                        var file = _logEntry.File;

                        // Only include entries with file paths (for Neovim jumping)
                        if (!string.IsNullOrEmpty(file))
                        {
                            var renderedLine = UnityEditor_LogEntry.GetRenderedLine(i);
                            result.Add(new LogEntry
                            {
                                file = ToAbsolutePath(file),
                                line = _logEntry.Line,
                                column = _logEntry.Column,
                                message = renderedLine,
                                severity = ParseMode(_logEntry.Mode)
                            });
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[Neovim] Error retrieving logs: {e}");
            }
            finally
            {
                UnityEditor_LogEntry.EndGettingEntries();

                // Restore original console flags
                UnityEditor_LogEntry.ConsoleFlags = originalFlags;
            }

            return result;
        }

        private static string ToAbsolutePath(string relativePath)
        {
            if (string.IsNullOrEmpty(relativePath))
            {
                return "";
            }
            if (Path.IsPathRooted(relativePath))
            {
                return relativePath;
            }
            return Path.GetFullPath(Path.Combine(ProjectRoot, relativePath));
        }

        private static string ParseMode(int mode)
        {
            // Unity log mode flags: kError = 1, kAssert = 2, kWarning = 4, kLog = 8, kException = 16
            // if ((mode & ((1 << 0)) != 0| (1 << 4) | (1 << 1))) != 0)
            if ((mode & (1 << 0)) != 0)
            {
                return "error";
            }
            if ((mode & (1 << 1)) != 0)
            {
                return "assert";
            }
            if ((mode & (1 << 2)) != 0)
            {
                return "warning";
            }
            if ((mode & (1 << 4)) != 0)
            {
                return "exception";
            }
            return "log";
        }
    }

    /// <summary>
    /// Reflection wrapper for UnityEditor.LogEntry and UnityEditor.LogEntries internal APIs.
    /// See: https://github.com/Unity-Technologies/UnityCsReference/blob/master/Editor/Mono/LogEntries.bindings.cs
    /// </summary>
    public class UnityEditor_LogEntry
    {
        // Reflection Types
        private static readonly Type LogEntryType = Type.GetType("UnityEditor.LogEntry, UnityEditor.dll");
        private static readonly Type LogEntriesType = Type.GetType("UnityEditor.LogEntries, UnityEditor.dll");

        // Console flag for timestamp display
        public const int SHOWTIMESTAMP_FLAG = 1 << 10;

        // Reflection Methods for LogEntries static class
        private static readonly MethodInfo _startGettingEntries;
        private static readonly MethodInfo _endGettingEntries;
        private static readonly MethodInfo _getCount;
        private static readonly MethodInfo _getEntryInternal;
        private static readonly MethodInfo _getLinesAndModeFromEntryInternal;
        private static readonly PropertyInfo _consoleFlagsProp;
        private static readonly MethodInfo _setConsoleFlag;

        // Reflection Fields for LogEntry instance
        private static readonly FieldInfo _fileField;
        private static readonly FieldInfo _lineField;
        private static readonly FieldInfo _columnField;
        private static readonly FieldInfo _messageField;
        private static readonly FieldInfo _modeField;

        // Reusable instance for GetEntryInternal
        private readonly object _instance;

        public static bool IsAvailable => LogEntryType != null && LogEntriesType != null;

        static UnityEditor_LogEntry()
        {
            if (LogEntryType == null || LogEntriesType == null)
            {
                return;
            }

            // LogEntries static methods
            _startGettingEntries = LogEntriesType.GetMethod("StartGettingEntries", BindingFlags.Static | BindingFlags.Public);
            _endGettingEntries = LogEntriesType.GetMethod("EndGettingEntries", BindingFlags.Static | BindingFlags.Public);
            _getCount = LogEntriesType.GetMethod("GetCount", BindingFlags.Static | BindingFlags.Public);
            _getEntryInternal = LogEntriesType.GetMethod("GetEntryInternal", BindingFlags.Static | BindingFlags.Public);
            _getLinesAndModeFromEntryInternal = LogEntriesType.GetMethod("GetLinesAndModeFromEntryInternal", BindingFlags.Static | BindingFlags.Public);
            _consoleFlagsProp = LogEntriesType.GetProperty("consoleFlags", BindingFlags.Static | BindingFlags.Public);
            _setConsoleFlag = LogEntriesType.GetMethod("SetConsoleFlag", BindingFlags.Static | BindingFlags.Public);

            // LogEntry instance fields
            var flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
            _fileField = LogEntryType.GetField("file", flags);
            _lineField = LogEntryType.GetField("line", flags);
            _columnField = LogEntryType.GetField("column", flags);
            _messageField = LogEntryType.GetField("message", flags);
            _modeField = LogEntryType.GetField("mode", flags);
        }

        public UnityEditor_LogEntry()
        {
            if (LogEntryType != null)
            {
                _instance = Activator.CreateInstance(LogEntryType);
            }
        }

        // Properties to access LogEntry fields
        public string File => (string)_fileField?.GetValue(_instance) ?? "";
        public int Line => (int?)_lineField?.GetValue(_instance) ?? 0;
        public int Column => (int?)_columnField?.GetValue(_instance) ?? 0;
        public string Message => (string)_messageField?.GetValue(_instance) ?? "";
        public int Mode => (int?)_modeField?.GetValue(_instance) ?? 0;

        // Static methods wrapping LogEntries
        public static int ConsoleFlags
        {
            get => (int?)_consoleFlagsProp?.GetValue(null) ?? 0;
            set => _consoleFlagsProp?.SetValue(null, value);
        }

        public static void SetConsoleFlag(int bit, bool value)
        {
            _setConsoleFlag?.Invoke(null, new object[] { bit, value });
        }

        public static void StartGettingEntries()
        {
            _startGettingEntries?.Invoke(null, null);
        }

        public static void EndGettingEntries()
        {
            _endGettingEntries?.Invoke(null, null);
        }

        public static int GetCount()
        {
            return (int?)_getCount?.Invoke(null, null) ?? 0;
        }

        /// <summary>
        /// Get entry at specified index and populate this instance's fields.
        /// </summary>
        public bool GetEntryInternal(int index)
        {
            if (_getEntryInternal == null || _instance == null)
            {
                return false;
            }

            return (bool)_getEntryInternal.Invoke(null, new object[] { index, _instance });
        }

        /// <summary>
        /// Get the rendered line string for an entry.
        /// </summary>
        public static string GetRenderedLine(int index)
        {
            if (_getLinesAndModeFromEntryInternal == null)
            {
                return "";
            }

            var parameters = new object[] { index, 1, 0, "" };
            _getLinesAndModeFromEntryInternal.Invoke(null, parameters);
            return (string)parameters[3];
        }
    }
}
