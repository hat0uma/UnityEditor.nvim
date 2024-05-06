using System.IO.Pipes;
using UnityEngine;
using System;
using UnityEditor;
using System.Threading;
using System.IO;
using System.Threading.Tasks;
using System.Collections.Concurrent;

namespace NeovimEditor
{
    [InitializeOnLoad]
    public class IPCServerInstance
    {
        static IPCServerInstance()
        {
            // Start IPC server
            var cts = new CancellationTokenSource();
            _obj.Start(cts.Token);

            // Stop server on domain unload
            // This is called when Unity Editor is closed, compiled, or entering play mode.
            AppDomain.CurrentDomain.DomainUnload += (sender, e) => cts.Cancel();
        }

        public static ConcurrentQueue<IPCMessage> MessageQueue => _obj.MessageQueue;
        private static readonly IPCServer _obj = new IPCServer();
    }

    /// <summary>
    /// IPC Message type for communication between Neovim and Unity Editor.
    /// Since it uses JSONUtility for deserialization internally, it cannot send complex structured messages.
    /// </summary>
    [Serializable]
    public class IPCMessage
    {
        public string type;
        public string[] arguments;
    }

    /// <summary>
    /// IPC Server for Unity Editor.
    /// It listens to IPC client and enqueues messages to message queue.
    /// </summary>
    public class IPCServer
    {
        /// <summary>
        /// Message queue for main thread.
        /// This queue is used to pass messages from worker thread to main thread.
        /// </summary>
        public ConcurrentQueue<IPCMessage> MessageQueue { get; } = new ConcurrentQueue<IPCMessage>();

        /// <summary>
        // Named pipe name
        // This name should be unique per process.
        /// </summary>
        private static readonly string _pipeName = $"UnityEditorIPC-{System.Diagnostics.Process.GetCurrentProcess().Id}";

        /// <summary>
        /// Flag to check if server is waiting for connection.
        /// </summary>
        private bool _waitingForConnection = false;

        /// <summary>
        /// Start IPC server.
        /// </summary>
        public Task Start(CancellationToken token)
        {
            // Start worker thread
            var task = Task.Run(() => Loop(token), token);
            token.Register(() => Cleanup(task));
            return task;
        }


        /// <summary>
        /// Cancel worker thread.
        /// </summary>
        private void Cleanup(Task task)
        {
            if (task == null) return;
            if (_waitingForConnection)
            {
                // HACK: NamedPipeServerStream.WaitForConnection() is blocking and we can't cancel it.
                // We need to connect with a dummy client to unblock the server.
                using (var dummyClient = new NamedPipeClientStream(_pipeName))
                {
                    dummyClient.Connect(100);
                }
            }
            // Wait for worker thread to finish
            try
            {
                task.Wait();
            }
            catch (Exception e)
            {
                Debug.LogWarning($"Exception in IPC server: {e}");
            }
        }

        /// <summary>
        /// Server loop
        /// This method is blocking. It should be called in a separate thread.
        /// It will receive messages from ipc client and enqueue them to message queue.
        /// </summary>
        private void Loop(CancellationToken token)
        {
            try
            {
                while (!token.IsCancellationRequested)
                {
                    // Create server
                    using (var server = new NamedPipeServerStream(_pipeName, PipeDirection.InOut))
                    {
                        // Wait for ipc client connection
                        // NOTE: WaitForConnectionAsync is not implemented in Unity 2019.4.12f1.
                        Debug.Log("Waiting for connection...");
                        _waitingForConnection = true;
                        server.WaitForConnection();
                        _waitingForConnection = false;

                        Debug.Log("Connected");
                        HandleConnection(server, token);
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning($"Exception in IPC server loop: {e}");
            }
        }


        private void HandleConnection(NamedPipeServerStream server, CancellationToken token)
        {
            while (!token.IsCancellationRequested && server.IsConnected)
            {
                // Read message from client.
                Debug.Log("Reading message...");
                string message = null;
                try
                {
                    message = PipeReadLine(server, token);
                }
                catch (OperationCanceledException)
                {
                    Debug.Log("Cancelled");
                    break;
                }

                // Check if client disconnected.
                if (message == null)
                {
                    Debug.Log("Disconnected");
                    break;
                }

                // Enqueue message to queue for main thread.
                Debug.Log($"Received message: {message}");
                try
                {
                    var ipcMessage = JsonUtility.FromJson<IPCMessage>(message);
                    MessageQueue.Enqueue(ipcMessage);
                }
                catch (ArgumentException e)
                {
                    Debug.LogWarning($"Failed to deserialize message: {message}.\nError:{e}");
                }
            }
        }

        /// <summary>
        /// Read a line from named pipe server.
        /// This method is blocking.
        /// </summary>
        /// <param name="server">server</param>
        /// <param name="token">cancellation token</param>
        /// <returns>message</returns>
        public string PipeReadLine(NamedPipeServerStream server, CancellationToken token)
        {
            // Read message from client.
            // NOTE: NamedPipeServerStream.ReadAsync with cancellation token has no effect in Unity 2019.4.12f1.
            string message = null;
            var reader = new StreamReader(server);
            var thread = new Thread(() => message = reader.ReadLine());
            thread.IsBackground = true;
            thread.Start();

            // Wait for message or cancellation.
            // NamedPipeServerStream.Close() does not cancel ReadLine. We need to abort the thread.
            while (thread.IsAlive)
            {
                if (token.IsCancellationRequested)
                {
                    thread.Abort();
                    throw new OperationCanceledException();
                }
                Thread.Sleep(100);
            }
            return message;
        }
    }
}

