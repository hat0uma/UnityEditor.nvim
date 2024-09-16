
using UnityEditor;

namespace NeovimEditor
{
    public class NeovimScriptEditorPrefs
    {
        private class Key
        {
            private const string Format = "com.hat0uma.ide.neovim.{0}";
            public static string Terminal = string.Format(Format, "Terminal");
        }

        /// <summary>
        /// Terminal for new Neovim process.
        /// </summary>
        public static string Terminal
        {
            get => EditorPrefs.GetString(Key.Terminal, "");
            set => EditorPrefs.SetString(Key.Terminal, value);
        }
    }
}

