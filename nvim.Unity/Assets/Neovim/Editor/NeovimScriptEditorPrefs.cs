using UnityEditor;

namespace NeovimEditor
{
    public class NeovimScriptEditorPrefs
    {
        private class Key
        {
            private const string Format = "com.hat0uma.ide.neovim.{0}";
            public static string Terminal = string.Format(Format, "Terminal");
            public static string ServerName = string.Format(Format, "ServerName");
        }

        /// <summary>
        /// Terminal for new Neovim process.
        /// </summary>
        public static string Terminal
        {
            get => EditorPrefs.GetString(Key.Terminal, "");
            set => EditorPrefs.SetString(Key.Terminal, value);
        }

        /// <summary>
        /// Server name for opening the file in the existing Neovim window.
        /// </summary>
        public static string ServerName
        {
            get => EditorPrefs.GetString(Key.ServerName, "");
            set => EditorPrefs.SetString(Key.ServerName, value);
        }
    }
}

