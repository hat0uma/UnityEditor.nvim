using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Unity.CodeEditor;
using UnityEditor;
using UnityEngine;

namespace NeovimEditor
{
    /// <summary>
    /// package.json structure
    /// </summary>
    public class Package
    {
        public string name;
        public string version;
        public string displayName;
        public string description;
        public string unity;
        public string author;
        public string repository;
        public string license;
    }

    [InitializeOnLoad]
    public class NeovimIntegration
    {
        /// <summary>
        /// Static constructor for NeovimIntegration.
        /// </summary>
        static NeovimIntegration()
        {
            var package = LoadPackageJson();
            var refreshProvider = new RefreshProvider();
            var playmodeProvider = new PlaymodeProvider();
            var instance = new NeovimIntegration(refreshProvider, playmodeProvider, package);

            // Register update callback
            EditorApplication.update += instance.Update;
            EditorApplication.update += refreshProvider.Update;
            EditorApplication.update += playmodeProvider.Update;

            // Stop server on domain unload
            // This is called when Unity Editor is closed, compiled, or entering play mode.
            AppDomain.CurrentDomain.DomainUnload += (sender, e) =>
            {
                instance.DisposeServer();
            };

            refreshProvider.onRefreshCompleted += () => instance.SendResponse("Refreshed");
            refreshProvider.onGenerateSolutionCompleted += () => instance.SendResponse("Solution generated");
            playmodeProvider.onPlaymodeEnter += () => instance.SendResponse("Playmode entered");
            playmodeProvider.onPlaymodeExit += () => instance.SendResponse("Playmode exited");
        }

        /// <summary>
        /// IPC server task
        /// </summary>
        private Task serverTask;

        /// <summary>
        /// IPC server instance
        /// </summary>
        private IPCServer server;

        /// <summary>
        /// Cancellation token source for IPC server
        /// </summary>
        private CancellationTokenSource cts;

        /// <summary>
        /// Previous code editor.
        /// </summary>
        private IExternalCodeEditor prevCodeEditor;

        /// <summary>
        /// Package information from package.json.
        /// </summary>
        private Package package;
        private RefreshProvider refreshProvider;
        private PlaymodeProvider playmodeProvider;

        private const string LastRequestIdKey = "NeovimEditor.LastRequestId";

        public NeovimIntegration(RefreshProvider refreshProvider, PlaymodeProvider playmodeProvider, Package package)
        {
            this.refreshProvider = refreshProvider;
            this.playmodeProvider = playmodeProvider;
            this.package = package;
        }

        /// <summary>
        /// Update for Editor.
        /// </summary>
        public void Update()
        {
            // Check if code editor has changed
            if (prevCodeEditor != CodeEditor.CurrentEditor)
            {
                OnCodeEditorChanged(CodeEditor.CurrentEditor, prevCodeEditor);
            }

            // Process incoming message if current editor is NeovimScriptEditor
            if (CodeEditor.CurrentEditor is NeovimScriptEditor)
            {
                ProcessIncomingMessage();
            }

            // Update previous code editor
            prevCodeEditor = CodeEditor.CurrentEditor;
        }

        private void OnCodeEditorChanged(IExternalCodeEditor current, IExternalCodeEditor previous)
        {
            if (current is NeovimScriptEditor)
            {
                StartServer();
            }
            else if (previous is NeovimScriptEditor)
            {
                DisposeServer();
            }
        }

        /// <summary>
        /// Start IPC server.
        /// </summary>
        public void StartServer()
        {
            // Start IPC server
            server = new IPCServer();
            cts = new CancellationTokenSource();
            serverTask = server.Start(cts.Token);
        }

        /// <summary>
        /// Process incoming message from Neovim.
        /// </summary>
        public void ProcessIncomingMessage()
        {
            // Process message queue
            if (server.ReceiveQueue.TryDequeue(out var message))
            {
                HandleMessages(message);
            }
        }

        /// <summary>
        /// Dispose IPC server.
        /// </summary>
        public void DisposeServer()
        {
            if (serverTask is null || cts is null || server is null)
            {
                return;
            }

            // Stop IPC server
            cts.Cancel();
            serverTask.Wait();

            // Cleanup
            server = null;
            cts.Dispose();
            cts = null;
            serverTask.Dispose();
            serverTask = null;
        }

        /// <summary>
        /// Get the package information from package.json.
        /// </summary>
        private static Package LoadPackageJson()
        {
            // Get the path of the script file
            var scriptFilePath = new System.Diagnostics.StackTrace(true).GetFrame(0).GetFileName();
            if (string.IsNullOrEmpty(scriptFilePath))
            {
                Debug.LogError("Failed to get the path of the script file.");
                return null;
            }

            string packageRoot = Directory.GetParent(scriptFilePath).Parent.Parent.FullName;

            // Find package.json
            string packageJsonPath = Path.Combine(packageRoot, "package.json");
            if (!File.Exists(packageJsonPath))
            {
                Debug.LogError("Could not find package.json");
                return null;
            }

            // Read package.json
            string json = File.ReadAllText(packageJsonPath);
            var packageInfo = JsonUtility.FromJson<Package>(json);
            return packageInfo;
        }

        /// <summary>
        /// Handle IPC message
        /// </summary>
        /// <param name="message">Received message</param>
        /// <returns></returns>
        public void HandleMessages(IPCRequestMessage message)
        {
            // Debug.Log($"Received message: {message}");
            if (message.version != package.version)
            {
                var result = $"Version mismatch: Expected {package.version}, but received {message.version}";
                Debug.LogWarning("[Neovim] " + result);
                SendResponse(result, IPCResponseMessage.Status.Error);
                return;
            }

            SessionState.SetInt(LastRequestIdKey, message.id);

            switch (message.method)
            {
                case "refresh":
                    refreshProvider.Refresh();
                    break;

                case "playmode_enter":
                    playmodeProvider.EnterPlaymode();
                    break;

                case "playmode_exit":
                    playmodeProvider.ExitPlaymode();
                    break;

                case "playmode_toggle":
                    playmodeProvider.TogglePlaymode();
                    break;

                case "generate_sln":
                    refreshProvider.GenerateSolution();
                    break;

                default:
                    var result = $"Unknown message method: {message.method}";
                    Debug.LogWarning("[Neovim] " + result);
                    SendResponse(result, IPCResponseMessage.Status.Error);
                    break;
            }
        }

        private void SendResponse(string result, IPCResponseMessage.Status status = IPCResponseMessage.Status.OK)
        {
            var message = new IPCResponseMessage
            {
                id = SessionState.GetInt(LastRequestIdKey, -1),
                version = package.version,
                status = (int)status,
                result = result
            };
            server.SendQueue.Enqueue(message);
        }
    }
}
