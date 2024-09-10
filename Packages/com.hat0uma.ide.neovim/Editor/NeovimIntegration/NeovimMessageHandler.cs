using System.Reflection;
using Unity.CodeEditor;
using UnityEditor;
using UnityEngine;

namespace NeovimEditor
{
    public class NeovimMessageHandler
    {
        /// <summary>
        /// Handle IPC message
        /// </summary>
        /// <param name="message">Received message</param>
        /// <returns></returns>
        public void Handle(IPCMessage message)
        {
            // Debug.Log($"Received message: {message}");
            switch (message.method)
            {
                case "refresh":
                    Refresh();
                    break;

                case "playmode_enter":
                    EnterPlaymode();
                    break;

                case "playmode_exit":
                    ExitPlaymode();
                    break;

                case "playmode_toggle":
                    TogglePlaymode();
                    break;

                case "generate_sln":
                    GenerateSolution();
                    break;

                default:
                    Debug.LogWarning($"Unknown message method: {message.method}");
                    break;
            }
        }

        private void Refresh()
        {
            AssetDatabase.Refresh();
        }

        private void EnterPlaymode()
        {
            EditorApplication.EnterPlaymode();
        }

        private void ExitPlaymode()
        {
            EditorApplication.ExitPlaymode();
        }

        private void TogglePlaymode()
        {
            if (EditorApplication.isPlaying)
            {
                EditorApplication.ExitPlaymode();
            }
            else
            {
                EditorApplication.EnterPlaymode();
            }
        }

        private void GenerateSolution()
        {
            AssetDatabase.Refresh();
            CodeEditor.Editor.CurrentCodeEditor.SyncAll();
        }

    }

}
