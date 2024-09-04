
using System;
using System.Threading;
using System.Threading.Tasks;
using Unity.CodeEditor;
using UnityEditor;

namespace NeovimEditor
{
    [InitializeOnLoad]
    public class NeovimIntegration
    {
        /// <summary>
        /// Static constructor for NeovimIntegration.
        /// </summary>
        static NeovimIntegration()
        {
            var instance = new NeovimIntegration();

            // Register update callback
            EditorApplication.update += instance.Update;

            // Stop server on domain unload
            // This is called when Unity Editor is closed, compiled, or entering play mode.
            AppDomain.CurrentDomain.DomainUnload += (sender, e) =>
            {
                instance.DisposeServer();
            };
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
        /// Previous state of Neovim IPC integration.
        /// </summary>
        private bool prevEnabled = false;

        /// <summary>
        /// Previous code editor.
        /// </summary>
        private IExternalCodeEditor prevCodeEditor;

        /// <summary>
        /// Neovim message handler.
        /// </summary>
        private NeovimMessageHandler messageHandler = new NeovimMessageHandler();

        /// <summary>
        /// Update for Editor.
        /// </summary>
        public void Update()
        {
            if (CodeEditor.CurrentEditor is NeovimScriptEditor)
            {
                // Start or stop server based on the enabled state.
                var codeEditorChanged = prevCodeEditor != CodeEditor.CurrentEditor;
                var integrationStateChanged = prevEnabled != NeovimScriptEditorPrefs.IntegrationEnabled;
                if (codeEditorChanged || integrationStateChanged)
                {
                    if (NeovimScriptEditorPrefs.IntegrationEnabled)
                    {
                        StartServer();
                    }
                    else
                    {
                        DisposeServer();
                    }
                }

                // Process incoming messages
                if (NeovimScriptEditorPrefs.IntegrationEnabled)
                {
                    ProcessIncomingMessage();
                }
            }
            // Skip if current editor is not NeovimScriptEditor
            else
            {
                if (prevCodeEditor is NeovimScriptEditor)
                {
                    DisposeServer();
                }
            }

            prevEnabled = NeovimScriptEditorPrefs.IntegrationEnabled;
            prevCodeEditor = CodeEditor.CurrentEditor;
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
            if (server.MessageQueue.TryDequeue(out var message))
            {
                messageHandler.Handle(message);
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
    }
}
