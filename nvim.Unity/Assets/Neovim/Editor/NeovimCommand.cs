using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using Unity.CodeEditor;
using Process = System.Diagnostics.Process;
using ProcessWindowStyle = System.Diagnostics.ProcessWindowStyle;
using ProcessStartInfo = System.Diagnostics.ProcessStartInfo;

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
                return neovimServer;
            }
            else
            {
                // find the Neovim server socket.
                // pattens are:
                //  - ${XDG_RUNTIME_DIR}/nvim.{pid}.<number>
                //  - /tmp/nvim.${USER}/<RANDOM>/nvim.{pid}.<number>
                var xdgRuntimeDir = System.Environment.GetEnvironmentVariable("XDG_RUNTIME_DIR");
                if (!string.IsNullOrEmpty(xdgRuntimeDir))
                {
                    var neovimServer = Directory.EnumerateFiles(xdgRuntimeDir).FirstOrDefault(p => Regex.IsMatch(p, @"nvim\.\d+\.\d+"));
                    return neovimServer;
                }
                else
                {
                    var userName = System.Environment.UserName;
                    var neovimServer = Directory.EnumerateFiles($"/tmp/nvim.{userName}", "*", SearchOption.AllDirectories).FirstOrDefault();
                    return neovimServer;
                }
            }
        }


        /// <summary>
        /// Open the file in the existing Neovim.
        /// </summary>
        public static Process OpenInExistInstance(string filePath, int line, int column, string serverPath)
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = CodeEditor.CurrentEditorInstallation,
                    UseShellExecute = true,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
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
        public static Process OpenNewInstance(string filePath, int line, int column)
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

            var startInfo = new ProcessStartInfo();
            startInfo.FileName = command[0];
            startInfo.UseShellExecute = true;
            startInfo.Arguments = ShellJoin(command.Skip(1));
            if (terminalSpecified)
            {
                // When the terminal is specified, both the command window and the terminal window are displayed, so hide the command window.
                startInfo.CreateNoWindow = true;
                startInfo.WindowStyle = ProcessWindowStyle.Hidden;
            }
            else
            {
                startInfo.CreateNoWindow = false;
                startInfo.WindowStyle = ProcessWindowStyle.Normal;
            }

            var process = new Process { StartInfo = startInfo };
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
