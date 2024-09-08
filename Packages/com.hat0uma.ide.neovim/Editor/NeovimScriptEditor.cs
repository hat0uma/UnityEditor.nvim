using System.IO;
using System.Linq;
using Unity.CodeEditor;
using UnityEditor;
using UnityEngine;

namespace NeovimEditor
{
    [InitializeOnLoad]
    public class NeovimScriptEditor : IExternalCodeEditor
    {
        /// <summary>
        /// Register NeovimScriptEditor to the CodeEditor.
        /// </summary>
        static NeovimScriptEditor()
        {
            var editor = new NeovimScriptEditor(new NeovimDiscovery(), new ProjectGeneration(Directory.GetParent(Application.dataPath).FullName));
            CodeEditor.Register(editor);

            if (IsNeovimInstallation(CodeEditor.CurrentEditorInstallation))
            {
                editor.CreateIfDoesntExist();
            }
        }

        /// <summary>
        /// Check if the given path is a Neovim installation.
        /// </summary>
        public static bool IsNeovimInstallation(string path)
        {
            if (string.IsNullOrEmpty(path))
            {
                return false;
            }
            var fileInfo = new FileInfo(path);
            var filename = fileInfo.Name.ToLower();
            return filename.StartsWith("nvim");
        }

        /// <summary>
        /// Discoverability for Neovim.
        /// </summary>
        IDiscovery m_Discoverability;

        /// <summary>
        /// Project generation for Neovim.
        /// </summary>
        IGenerator m_ProjectGeneration;

        /// <summary>
        /// Get all Neovim installations.
        /// </summary>
        public CodeEditor.Installation[] Installations => m_Discoverability.PathCallback();

        /// <summary>
        /// Constructor.
        /// </summary>
        public NeovimScriptEditor(IDiscovery discovery, IGenerator projectGeneration)
        {
            m_Discoverability = discovery;
            m_ProjectGeneration = projectGeneration;
        }

        /// <summary>
        /// Callback to the IExternalCodeEditor when it has been chosen from the PreferenceWindow.
        /// </summary>
        /// <param name="editorInstallationPath"></param>
        public void Initialize(string editorInstallationPath)
        {
            // Do nothing
        }


        /// <summary>
        /// Create "Preferences/External Tools" GUI
        /// </summary>
        public void OnGUI()
        {
            // Terminal for new Neovim instance
            var prevTerminal = NeovimScriptEditorPrefs.Terminal;
            var terminal = EditorGUILayout.TextField(new GUIContent("Terminal command"), prevTerminal);
            if (terminal != prevTerminal)
            {
                NeovimScriptEditorPrefs.Terminal = terminal;
            }

            // Solution generation settings
            EditorGUILayout.LabelField("Generate .csproj files for:");
            EditorGUI.indentLevel++;
            SettingsButton(ProjectGenerationFlag.Embedded, "Embedded packages", "");
            SettingsButton(ProjectGenerationFlag.Local, "Local packages", "");
            SettingsButton(ProjectGenerationFlag.Registry, "Registry packages", "");
            SettingsButton(ProjectGenerationFlag.Git, "Git packages", "");
            SettingsButton(ProjectGenerationFlag.BuiltIn, "Built-in packages", "");
#if UNITY_2019_3_OR_NEWER
            SettingsButton(ProjectGenerationFlag.LocalTarBall, "Local tarball", "");
#endif
            SettingsButton(ProjectGenerationFlag.Unknown, "Packages from unknown sources", "");
            RegenerateProjectFiles();
            EditorGUI.indentLevel--;
        }

        void SettingsButton(ProjectGenerationFlag preference, string guiMessage, string toolTip)
        {
            var prevValue = m_ProjectGeneration.AssemblyNameProvider.ProjectGenerationFlag.HasFlag(preference);
            var newValue = EditorGUILayout.Toggle(new GUIContent(guiMessage, toolTip), prevValue);
            if (newValue != prevValue)
            {
                m_ProjectGeneration.AssemblyNameProvider.ToggleProjectGeneration(preference);
            }
        }

        void RegenerateProjectFiles()
        {
            var rect = EditorGUI.IndentedRect(EditorGUILayout.GetControlRect(new GUILayoutOption[] { }));

            rect.width = 252;
            if (GUI.Button(rect, "Regenerate project files"))
            {
                m_ProjectGeneration.Sync();
            }
        }

        /// <summary>
        /// Get the supported extensions for Neovim.
        /// </summary>
        public string[] SupportedExtensions
        {
            get
            {
                var builtin = EditorSettings.projectGenerationBuiltinExtensions;
                var user = EditorSettings.projectGenerationUserExtensions;
                var additional = new[] { "json", "toml", "yaml", "yml" };
                return builtin.Concat(user).Concat(additional).Distinct().Select(e => e.TrimStart('.')).ToArray();
            }
        }

        /// <summary>
        /// Open the project at the given file path.
        /// </summary>
        public bool OpenProject(string filePath, int line, int column)
        {
            // Debug.Log($"OpenProject: {filePath}");
            if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath))
            {
                return false;
            }

            // Check if the file extension is supported.
            var extension = Path.GetExtension(filePath).TrimStart('.');
            if (!SupportedExtensions.Contains(extension))
            {
                return false;
            }

            if (line == -1)
            {
                line = 1;
            }
            if (column == -1)
            {
                column = 1;
            }

            // open file in existing neovim server or open new neovim window.
            var neovimServer = NeovimCommand.GetExistNeovimServer();
            if (neovimServer == null)
            {
                NeovimCommand.OpenNewInstance(filePath, line, column);
            }
            else
            {
                NeovimCommand.OpenInExistInstance(filePath, line, column, neovimServer);
            }
            return true;
        }

        public void CreateIfDoesntExist()
        {
            if (!m_ProjectGeneration.SolutionExists())
            {
                m_ProjectGeneration.Sync();
            }
        }

        public void SyncAll()
        {
            (m_ProjectGeneration.AssemblyNameProvider as IPackageInfoCache)?.ResetPackageInfoCache();
            AssetDatabase.Refresh();
            m_ProjectGeneration.Sync();
        }

        public void SyncIfNeeded(string[] addedFiles, string[] deletedFiles, string[] movedFiles, string[] movedFromFiles, string[] importedFiles)
        {
            (m_ProjectGeneration.AssemblyNameProvider as IPackageInfoCache)?.ResetPackageInfoCache();
            m_ProjectGeneration.SyncIfNeeded(addedFiles.Union(deletedFiles).Union(movedFiles).Union(movedFromFiles).ToList(), importedFiles);
        }

        public bool TryGetInstallationForPath(string editorPath, out CodeEditor.Installation installation)
        {
            // This method is used to get editor information from the file selected by the user from Preferences/External -> Browse.
            // If the selected editor is neovim, return the installation information.
            if (IsNeovimInstallation(editorPath))
            {
                installation = new CodeEditor.Installation
                {
                    Name = "Neovim",
                    Path = editorPath
                };
                return true;
            }

            installation = default;
            return false;

        }
    }
}
