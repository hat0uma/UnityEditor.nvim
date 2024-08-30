using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using Unity.CodeEditor;
using UnityEngine;

namespace NeovimEditor
{
    public class NeovimCommand
    {
        /// <summary>
        /// Get the existing Neovim server.
        /// </summary>
        public static string GetExistNeovimServer()
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                var neovimServer = Directory.EnumerateFiles(@"\\.\pipe\").FirstOrDefault(p => Regex.IsMatch(p, @"\\\\.\\pipe\\nvim\.\d+\.\d+"));
                if (neovimServer != null)
                {
                    return neovimServer;
                }
            }
            else
            {
                // TODO: implement for other platforms.
            }
            return null;
        }


        /// <summary>
        /// Open the file in the existing Neovim.
        /// </summary>
        public static System.Diagnostics.Process OpenInExistInstance(string filePath, int line, int column, string serverPath)
        {
            var process = new System.Diagnostics.Process
            {
                StartInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = CodeEditor.CurrentEditorInstallation,
                    UseShellExecute = true,
                    CreateNoWindow = true,
                    WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden,
                    Arguments = ShellJoin(new string[]{
                        "-u",
                        "NONE",
                        "--headless",
                        "--server",
                        serverPath,
                        "--remote-send",
                        $"<ESC>:e {filePath}<CR>:call cursor({line},{column})<CR>"
                    }),
                }
            };
            process.Start();
            return process;
        }

        /// <summary>
        /// Open the file in the new Neovim window.
        /// </summary>
        public static System.Diagnostics.Process OpenNewInstance(string filePath, int line, int column)
        {
            // construct arguments for new neovim window.
            var terminalSpecified = !string.IsNullOrEmpty(NeovimScriptEditorPrefs.Terminal);
            var command = new List<string>();
            if (terminalSpecified)
            {
                command.AddRange(NeovimScriptEditorPrefs.Terminal.Split(' '));
            }
            command.Add(CodeEditor.CurrentEditorPath);
            command.Add("-c");
            command.Add($"e {filePath}");
            command.Add("-c");
            command.Add($"call cursor({line},{column})");

            var startInfo = new System.Diagnostics.ProcessStartInfo();
            startInfo.FileName = command[0];
            startInfo.UseShellExecute = true;
            startInfo.Arguments = ShellJoin(command.Skip(1));
            if (terminalSpecified)
            {
                // When the terminal is specified, both the command window and the terminal window are displayed, so hide the command window.
                startInfo.CreateNoWindow = true;
                startInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
            }
            else
            {
                startInfo.CreateNoWindow = false;
                startInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Normal;
            }

            var process = new System.Diagnostics.Process { StartInfo = startInfo };
            process.Start();
            return process;
        }

        /// <summary>
        /// Join arguments for shell command.
        /// </summary>
        /// <param name="arguments">arguments</param>
        private static string ShellJoin(IEnumerable<string> arguments)
        {
            StringBuilder joined = new StringBuilder();
            foreach (var arg in arguments)
            {
                if (joined.Length > 0)
                    joined.Append(' ');

                joined.Append(ShellQuote(arg));
            }

            return joined.ToString();
        }

        /// <summary>
        /// Characters that need to be quoted.
        /// </summary>
        private static readonly char[] QuoteChars = new[] { ' ', '\t', '\n', '\r', '"' };

        /// <summary>
        /// Quote argument for shell command.
        /// </summary>
        private static string ShellQuote(string argument)
        {
            if (string.IsNullOrEmpty(argument) || argument.IndexOfAny(QuoteChars) == -1)
            {
                return argument;
            }

            var quoted = new StringBuilder();
            quoted.Append('"');
            foreach (var c in argument)
            {
                if (c == '"')
                {
                    quoted.Append("\\\"");
                }
                else
                {
                    quoted.Append(c);
                }
            }
            quoted.Append('"');

            return quoted.ToString();
        }


    }
}
