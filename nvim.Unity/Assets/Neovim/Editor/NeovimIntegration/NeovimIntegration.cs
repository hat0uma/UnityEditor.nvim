
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
                messageHandler.Handle(message, server);
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
