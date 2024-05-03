using System.IO.Pipes;
using UnityEngine;
using System;
using UnityEditor;
using System.Threading;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;

[Serializable]
public class IPCMessage
{
    public string type;
    public string[] arguments;
}

[InitializeOnLoad]
public class IPCServer
{
    public static Queue<IPCMessage> MessageQueue { get; } = new Queue<IPCMessage>();
    private static readonly string _pipeName = $"UnityEditorIPC-{System.Diagnostics.Process.GetCurrentProcess().Id}";
    private static bool _waitingForConnection = false;

    static IPCServer()
    {
        // Start worker thread
        var synchronizationContext = SynchronizationContext.Current;
        var cts = new CancellationTokenSource();
        var task = Task.Run(() => Loop(cts.Token, synchronizationContext), cts.Token);

        // Register domain unload callback
        AppDomain.CurrentDomain.DomainUnload += (sender, e) =>
        {
            cts.Cancel();
            if (_waitingForConnection)
            {
                // HACK: NamedPipeServerStream.WaitForConnection() is blocking and we can't cancel it.
                // We need to connect with a dummy client to unblock the server.
                using (var dummyClient = new NamedPipeClientStream(_pipeName))
                {
                    dummyClient.Connect();
                }
            }
            // Wait for worker thread to finish
            try { task.Wait(); } catch { }
        };
    }


    /// <summary>
    /// Server loop
    /// This method is blocking. It should be called in a separate thread.
    /// It will receive messages from ipc client and enqueue them to message queue.
    /// </summary>
    /// <returns></returns>
    public static void Loop(CancellationToken token, SynchronizationContext synchronizationContext)
    {
        while (!token.IsCancellationRequested)
        {
            // Create server
            var server = new NamedPipeServerStream(_pipeName, PipeDirection.InOut);

            // Wait for ipc client connection
            // NOTE: WaitForConnectionAsync is not implemented in mono.
            Debug.Log("Waiting for connection...");
            _waitingForConnection = true;
            server.WaitForConnection();
            _waitingForConnection = false;

            // Handle connection
            Debug.Log("Connected");
            while (!token.IsCancellationRequested && server.IsConnected)
            {
                using (var reader = new StreamReader(server))
                {
                    // Read message from client.
                    Debug.Log("Reading message...");
                    var readTask = reader.ReadLineAsync();
                    try
                    {
                        readTask.Wait(token);
                    }
                    catch (Exception e)
                    {
                        if (e is AggregateException || e is OperationCanceledException)
                        {
                            // Task was cancelled.
                            break;
                        }
                        throw;
                    }

                    // Check if client disconnected.
                    var message = readTask.Result;
                    if (message == null)
                    {
                        Debug.Log("Disconnected");
                        break;
                    }

                    // Enqueue message to queue for main thread.
                    Debug.Log($"Received message: {message}");
                    var ipcMessage = JsonUtility.FromJson<IPCMessage>(message);
                    synchronizationContext.Post(_ => MessageQueue.Enqueue(ipcMessage), null);
                }
            }
        }
        Debug.Log("Server loop finished");
    }
}
