using System;
using System.IO;
using System.Threading;
using System.IO.Pipes;
using System.Threading.Tasks;
using System.Collections.Concurrent;
using System.Text;
using UnityEngine;

namespace NeovimEditor
{
    /// <summary>
    /// IPC Request message type for communication between Neovim and Unity Editor.
    /// </summary>
    /// <remarks>
    /// The <c>parameters</c> field is a JSON string (not a parsed object) to allow method-specific
    /// parameter structures while staying within JsonUtility's serialization constraints.
    /// Each method handler is responsible for deserializing parameters into its expected type.
    /// </remarks>
    [Serializable]
    public struct IPCRequestMessage
    {
        public int id;
        public string version;
        public string method;
        public string parameters;
        public override readonly string ToString() => $"IPCRequestMessage(id={id}, version={version}, method={method}, parameters={parameters})";
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
        public override readonly string ToString() => $"IPCResponseMessage(request_id={id}, version={version}, status={status}, result={result})";
    }

    /// <summary>
    /// IPC Server for Unity Editor.
    /// It listens to IPC client and enqueues messages to message queue.
    /// </summary>
    public class IPCServer
    {
        /// <summary>
        /// Protocol magic number: "UNVM"
        /// </summary>
        private static readonly byte[] Magic = { (byte)'U', (byte)'N', (byte)'V', (byte)'M' };

        /// <summary>
        /// Protocol header size in bytes (Magic + Length)
        /// </summary>
        private const int HeaderSize = 8;

        /// <summary>
        /// Maximum message payload size (1MB)
        /// </summary>
        private const int MaxMessageSize = 1024 * 1024;

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
        public BlockingCollection<IPCResponseMessage> SendQueue { get; } = new BlockingCollection<IPCResponseMessage>();

        private static readonly Encoding utf8 = new UTF8Encoding(false);

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
                        await Task.Delay(10, token);
                    }
                }
            }, token);
        }

        /// <summary>
        /// Server loop
        /// It will receive messages from ipc client and enqueue them to message queue.
        /// </summary>
        private async Task Loop(CancellationToken token)
        {
            // Create server
            using (var server = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous))
            {
                // Wait for client connection
                // Debug.Log("Waiting for client connection");
                await server.WaitForConnectionAsync(token);
                // Debug.Log("Client connected");

                // Handle send and receive
                using (var cts = CancellationTokenSource.CreateLinkedTokenSource(token))
                {
                    var receiveTask = HandleReceive(server, cts.Token);
                    var sendTask = HandleSend(server, cts.Token);

                    // Wait until disconnect
                    var completedTask = await Task.WhenAny(receiveTask, sendTask);

                    // Error Logging
                    if (completedTask.IsFaulted && completedTask.Exception != null)
                    {
                        Debug.Log($"Client handler error: ${completedTask.Exception.Message}");
                    }

                    cts.Cancel();
                    if (receiveTask != null && sendTask != null)
                    {
                        await Task.WhenAll(receiveTask, sendTask);
                    }
                }

                // Debug.Log("Client disconnected");
            }
        }

        private async Task HandleSend(NamedPipeServerStream server, CancellationToken token)
        {
            var header = new byte[HeaderSize];
            while (!token.IsCancellationRequested)
            {
                if (SendQueue.TryTake(out var ipcMessage, -1, token))
                {
                    var json = JsonUtility.ToJson(ipcMessage);
                    var payload = utf8.GetBytes(json);

                    // Build header: Magic (4 bytes) + Length (4 bytes, little-endian)
                    Array.Copy(Magic, 0, header, 0, 4);
                    var lengthBytes = BitConverter.GetBytes(payload.Length);
                    Array.Copy(lengthBytes, 0, header, 4, 4);

                    // Send header + payload
                    await server.WriteAsync(header, 0, HeaderSize, token);
                    await server.WriteAsync(payload, 0, payload.Length, token);
                    await server.FlushAsync(token);
                }
            }
        }

        private async Task HandleReceive(NamedPipeServerStream server, CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                // Read message from client.
                string message = await ReadMessage(server, token);
                if (message == null)
                {
                    // client disconnected or protocol error.
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
        /// Read a message with binary header from named pipe server.
        /// </summary>
        /// <param name="server">server</param>
        /// <param name="token">cancellation token</param>
        /// <returns>message payload as string, or null on error/disconnect</returns>
        private async Task<string> ReadMessage(NamedPipeServerStream server, CancellationToken token)
        {
            // Read header
            var header = new byte[HeaderSize];
            if (!await ReadExactly(server, header, HeaderSize, token))
            {
                return null;
            }

            // Validate magic number
            if (header[0] != Magic[0] || header[1] != Magic[1] || header[2] != Magic[2] || header[3] != Magic[3])
            {
                Debug.LogWarning("Invalid magic number in message header");
                return null;
            }

            // Get payload length
            var length = BitConverter.ToInt32(header, 4);
            if (length < 0 || length > MaxMessageSize)
            {
                Debug.LogWarning($"Invalid message length: {length}");
                return null;
            }

            // Read payload
            var payload = new byte[length];
            if (!await ReadExactly(server, payload, length, token))
            {
                return null;
            }

            return utf8.GetString(payload);
        }

        /// <summary>
        /// Read exactly the specified number of bytes from the stream.
        /// </summary>
        /// <param name="stream">stream to read from</param>
        /// <param name="buffer">buffer to read into</param>
        /// <param name="count">number of bytes to read</param>
        /// <param name="token">cancellation token</param>
        /// <returns>true if successful, false if connection closed</returns>
        private async Task<bool> ReadExactly(Stream stream, byte[] buffer, int count, CancellationToken token)
        {
            var totalRead = 0;
            while (totalRead < count)
            {
                var bytesRead = await stream.ReadAsync(buffer, totalRead, count - totalRead, token);
                if (bytesRead == 0)
                {
                    // Connection closed
                    return false;
                }
                totalRead += bytesRead;
            }
            return true;
        }
    }
}

