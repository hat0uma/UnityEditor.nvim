using System;
using System.Threading;
using System.IO;
using System.IO.Pipes;
using System.Threading.Tasks;
using System.Collections.Concurrent;
using System.Text;
using UnityEngine;

namespace NeovimEditor
{
    /// <summary>
    /// IPC Message type for communication between Neovim and Unity Editor.
    /// Since it uses JSONUtility for deserialization internally, it cannot send complex structured messages.
    /// </summary>
    [Serializable]
    public struct IPCRequestMessage
    {
        public int id;
        public string version;
        public string method;
        public string[] parameters;
        public override string ToString() => $"IPCRequestMessage(id={id}, version={version}, method={method}, parameters=[{string.Join(", ", parameters)}])";
    }

    /// <summary>
    /// IPC Response message type for communication between Neovim and Unity Editor.
    /// </summary>
    [Serializable]
    public struct IPCResponseMessage
    {
        public enum Status
        {
            OK = 0,
            Error = -1,
        }
        public int id;
        public string version;
        public int status;
        public string result;
        public override string ToString() => $"IPCResponseMessage(request_id={id}, version={version}, status={status}, result={result})";
    }

    /// <summary>
    /// IPC Server for Unity Editor.
    /// It listens to IPC client and enqueues messages to message queue.
    /// </summary>
    public class IPCServer
    {
        /// <summary>
        /// Named pipe name
        /// This name should be unique per process.
        /// </summary>
        private static readonly string pipeName = $"UnityEditorIPC-{System.Diagnostics.Process.GetCurrentProcess().Id}";

        /// <summary>
        /// Message queue for receiving messages from IPC client.
        /// This queue is used to pass messages from worker thread to main thread.
        /// </summary>
        public ConcurrentQueue<IPCRequestMessage> ReceiveQueue { get; } = new ConcurrentQueue<IPCRequestMessage>();

        /// <summary>
        /// Message queue for sending messages to IPC client.
        /// This queue is used to pass messages from main thread to worker thread.
        /// </summary>
        public ConcurrentQueue<IPCResponseMessage> SendQueue { get; } = new ConcurrentQueue<IPCResponseMessage>();

        /// <summary>
        /// Buffer for reading a line from named pipe server.
        /// </summary>
        private byte[] readLineBuffer = new byte[1024];

        /// <summary>
        /// client is connected.
        /// NamedPipeServerStream.IsConnected cannot detect client disconnection. So use this flag.
        /// </summary>
        private bool isConnected = false;


        private static Encoding utf8 = new UTF8Encoding(false);

        /// <summary>
        /// Start IPC server.
        /// </summary>
        public Task Start(CancellationToken token)
        {
            // Start worker thread
            return Task.Run(async () =>
            {
                // Create server
                while (!token.IsCancellationRequested)
                {
                    try
                    {
                        await Loop(token);
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
            }, token);
        }

        /// <summary>
        /// Server loop
        /// This method is blocking. It should be called in a separate thread.
        /// It will receive messages from ipc client and enqueue them to message queue.
        /// </summary>
        private async Task Loop(CancellationToken token)
        {
            // Create server
            using (var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous))
            {
                // Wait for ipc client connection
                // Debug.Log("Waiting for client connection");
                isConnected = false;
                await server.WaitForConnectionAsync(token);
                isConnected = true;

                // Handle send and receive
                // Debug.Log("Client connected");
                var receiveTask = HandleReceive(server, token);
                var sendTask = HandleSend(server, token);
                await Task.WhenAll(receiveTask, sendTask);

                // Debug.Log("Client disconnected");
                isConnected = false;
            }
        }

        private async Task HandleSend(NamedPipeServerStream server, CancellationToken token)
        {
            while (!token.IsCancellationRequested && isConnected)
            {
                if (SendQueue.TryDequeue(out var ipcMessage))
                {
                    var message = JsonUtility.ToJson(ipcMessage) + "\n";
                    var bytes = utf8.GetBytes(message);
                    await server.WriteAsync(bytes, token);
                    await server.FlushAsync(token);
                }
                await Task.Delay(10, token);
            }
        }

        private async Task HandleReceive(NamedPipeServerStream server, CancellationToken token)
        {
            while (!token.IsCancellationRequested && isConnected)
            {
                // Read message from client.
                string message = await PipeReadLine(server, token);
                if (message == null)
                {
                    // client disconnected.
                    break;
                }

                // Enqueue message to queue for main thread.
                try
                {
                    var ipcMessage = JsonUtility.FromJson<IPCRequestMessage>(message);
                    ReceiveQueue.Enqueue(ipcMessage);
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
                    isConnected = false;
                    break;
                }

                // Check if end of message
                size += bytesRead;
                var c = readLineBuffer[size - 1];
                if (c == '\n')
                {
                    // End of message
                    var message = Encoding.UTF8.GetString(readLineBuffer, 0, size - 1);
                    Array.Clear(readLineBuffer, 0, size);
                    return message;
                }
            }
            return null;
        }
    }
}

