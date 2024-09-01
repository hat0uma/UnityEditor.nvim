using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace NeovimEditor
{
    public class NeovimMessageDispatcher
    {
        /// <summary>
        /// Dispatch IPC message
        /// </summary>
        /// <param name="message">Received message</param>
        /// <returns></returns>
        public static void Dispatch(IPCMessage message)
        {
            switch (message.type)
            {
                case "refresh":
                    Refresh();
                    break;

                case "enter_playmode":
                    EnterPlaymode();
                    break;

                case "exit_playmode":
                    ExitPlaymode();
                    break;

                case "generate_sln":
                    GenerateSolution();
                    break;

                default:
                    Debug.LogWarning($"Unknown message type: {message.type}");
                    break;
            }
        }

        private static void Refresh()
        {
            AssetDatabase.Refresh();
        }

        private static void EnterPlaymode()
        {
            EditorApplication.EnterPlaymode();
        }

        private static void ExitPlaymode()
        {
            EditorApplication.ExitPlaymode();
        }

        private static void GenerateSolution()
        {
            // UnityEditor.SyncVS.SyncSolution() is internal, so use reflection to call it.
            var assembly = typeof(UnityEditor.Editor).Assembly;
            var SyncVS = assembly.GetType("UnityEditor.SyncVS");
            if (SyncVS == null)
            {
                Debug.LogWarning("Type not found: UnityEditor.SyncVS");
                return;
            }

            var method = SyncVS.GetMethod("SyncSolution", BindingFlags.Public | BindingFlags.Static);
            if (method == null)
            {
                Debug.LogWarning("Method not found: UnityEditor.SyncVS.SyncSolution");
                return;
            }

            method.Invoke(null, null);
        }

    }

}
