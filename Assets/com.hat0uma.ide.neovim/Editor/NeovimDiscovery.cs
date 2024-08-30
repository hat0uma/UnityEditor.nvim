using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.IO;
using Unity.CodeEditor;

namespace NeovimEditor
{
    public interface IDiscovery
    {
        CodeEditor.Installation[] PathCallback();
    }

    /// <summary>
    /// This class is responsible for discovering Neovim installations.
    /// </summary>
    public class NeovimDiscovery : IDiscovery
    {
        /// <summary>
        /// Found Neovim installations.
        /// </summary>
        List<CodeEditor.Installation> m_Installations;

        /// <summary>
        /// Callback for the IExternalCodeEditor to get all Neovim installations.
        /// </summary>
        /// <returns></returns>
        public CodeEditor.Installation[] PathCallback()
        {
            if (m_Installations == null)
            {
                m_Installations = new List<CodeEditor.Installation>();
                FindInstallationPaths();
            }

            return m_Installations.ToArray();
        }


        /// <summary>
        /// Find Neovim installations.
        /// </summary>
        void FindInstallationPaths()
        {
            // get neovim from PATH environment.
            var path = Environment.GetEnvironmentVariable("PATH");
            var extensions = PathExtensions();
            if (string.IsNullOrEmpty(path))
            {
                return;
            }

            foreach (var dir in path.Split(Path.PathSeparator))
            {
                foreach (var ext in extensions)
                {
                    var fullPath = Path.Combine(dir, "nvim" + ext);
                    if (File.Exists(fullPath))
                    {
                        m_Installations.Add(new CodeEditor.Installation
                        {
                            Name = $"Neovim ({fullPath})",
                            Path = fullPath
                        });
                    }
                }
            }
        }

        public string[] PathExtensions()
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                var extensions = Environment.GetEnvironmentVariable("PATHEXT");
                return string.IsNullOrEmpty(extensions) ? extensions.Split(Path.PathSeparator) : new string[] { ".exe" };
            }
            else
            {
                return new string[] { "" };
            }
        }
    }
}
