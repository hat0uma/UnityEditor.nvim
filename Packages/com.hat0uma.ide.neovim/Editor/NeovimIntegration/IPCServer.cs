using System.IO.Pipes;
using UnityEngine;
using System;
using System.Threading;
using System.IO;
using System.Threading.Tasks;
using System.Collections.Concurrent;
using System.Text;

namespace NeovimEditor
{
    /// <summary>
    /// IPC Message type for communication between Neovim and Unity Editor.
    /// Since it uses JSONUtility for deserialization internally, it cannot send complex structured messages.
    /// </summary>
    [Serializable]
    public class IPCMessage
    {
        public string method;
        public string[] parameters;
    }

    /// <summary>
    /// IPC Server for Unity Editor.
    /// It listens to IPC client and enqueues messages to message queue.
    /// </summary>
    public class IPCServer
    {
        /// <summary>
        // Named pipe name
        // This name should be unique per process.
        /// </summary>
        private static readonly string pipeName = $"UnityEditorIPC-{System.Diagnostics.Process.GetCurrentProcess().Id}";

        /// <summary>
        /// Message queue for main thread.
        /// This queue is used to pass messages from worker thread to main thread.
        /// </summary>
        public ConcurrentQueue<IPCMessage> MessageQueue { get; } = new ConcurrentQueue<IPCMessage>();

        /// <summary>
        /// Buffer for reading a line from named pipe server.
        /// </summary>
        private byte[] readLineBuffer = new byte[1024];

        /// <summary>
        /// Start IPC server.
        /// </summary>
        public Task Start(CancellationToken token)
        {
            // Start worker thread
            return Task.Run(() => Loop(token), token);
        }

        /// <summary>
        /// Server loop
        /// This method is blocking. It should be called in a separate thread.
        /// It will receive messages from ipc client and enqueue them to message queue.
        /// </summary>
        private async Task Loop(CancellationToken token)
        {
            try
            {
                while (!token.IsCancellationRequested)
                {
                    // Create server
                    using (var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous))
                    using (var reader = new StreamReader(server))
                    {
                        // Wait for ipc client connection
                        // Debug.Log("Waiting for connection...");
                        await server.WaitForConnectionAsync(token);

                        // Debug.Log("Connected");
                        await HandleConnection(server, reader, token);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // Cancellation requested
            }
            catch (Exception e)
            {
                Debug.LogWarning($"Exception in Neovim IPC server loop: {e}");
            }
        }

        private async Task HandleConnection(NamedPipeServerStream server, StreamReader reader, CancellationToken token)
        {
            while (!token.IsCancellationRequested && server.IsConnected)
            {
                // Read message from client.
                // Debug.Log("Reading message...");
                string message = await PipeReadLine(server, token);

                // Check if client disconnected.
                if (message == null)
                {
                    // Debug.Log("Disconnected");
                    break;

                }

                // Enqueue message to queue for main thread.
                // Debug.Log($"Received message: {message}");
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
        /// Message max length are defined by `readLineBuffer` size.
        /// If message is too long or client disconnected, return null.
        /// </summary>
        /// <param name="server">server</param>
        /// <param name="token">cancellation token</param>
        /// <returns>message</returns>
        private async Task<string> PipeReadLine(NamedPipeServerStream server, CancellationToken token)
        {
            // StreamReader.ReadLineAsync does not accept cancellation token, so implement it by myself.
            // Read message from client.
            var size = 0;
            while (!token.IsCancellationRequested && server.IsConnected)
            {
                // Check if message is too long
                if (size >= readLineBuffer.Length)
                {
                    Debug.LogWarning("Line too long");
                    break;
                }

                // Read one byte
                var bytesRead = await server.ReadAsync(readLineBuffer, size, 1, token);
                if (bytesRead == 0)
                {
                    // Client disconnected
                    break;
                }

                // Check if end of message
                size += bytesRead;
                var c = readLineBuffer[size - 1];
                if (c == '\n')
                {
                    // End of message
                    return Encoding.UTF8.GetString(readLineBuffer, 0, size - 1);
                }
            }
            return null;
        }
    }
}

