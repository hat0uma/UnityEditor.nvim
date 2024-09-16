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
        public void Handle(IPCRequestMessage message, IPCServer server)
        {
            // Debug.Log($"Received message: {message}");
            if (message.version != Version.VERSION)
            {
                var result = $"Version mismatch: Expected {Version.VERSION}, but received {message.version}";
                Debug.LogWarning("[Neovim] " + result);
                server.SendQueue.Enqueue(Response(result, IPCResponseMessage.Status.Error));
                return;
            }

            // NOTE: Operations involving Domain Reload require a response to be returned first.
            switch (message.method)
            {
                case "refresh":
                    server.SendQueue.Enqueue(Response("OK"));
                    Refresh();
                    break;

                case "playmode_enter":
                    server.SendQueue.Enqueue(Response("OK"));
                    EnterPlaymode();
                    break;

                case "playmode_exit":
                    server.SendQueue.Enqueue(Response("OK"));
                    ExitPlaymode();
                    break;

                case "playmode_toggle":
                    server.SendQueue.Enqueue(Response("OK"));
                    TogglePlaymode();
                    break;

                case "generate_sln":
                    GenerateSolution();
                    server.SendQueue.Enqueue(Response("OK"));
                    break;

                default:
                    var result = $"Unknown message method: {message.method}";
                    Debug.LogWarning("[Neovim] " + result);
                    server.SendQueue.Enqueue(Response(result, IPCResponseMessage.Status.Error));
                    break;
            }
        }

        private IPCResponseMessage Response(string result, IPCResponseMessage.Status status = IPCResponseMessage.Status.OK)
        {
            return new IPCResponseMessage { version = Version.VERSION, status = (int)status, result = result };
        }

        private void Refresh()
        {
            AssetDatabase.Refresh();
        }

        private void EnterPlaymode()
        {
            AssetDatabase.Refresh();
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
                ExitPlaymode();
            }
            else
            {
                EnterPlaymode();
            }
        }

        private void GenerateSolution()
        {
            AssetDatabase.Refresh();
            CodeEditor.Editor.CurrentCodeEditor.SyncAll();
        }

    }

}
