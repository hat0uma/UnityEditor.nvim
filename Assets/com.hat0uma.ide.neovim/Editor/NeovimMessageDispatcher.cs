using System;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class NeovimMessageDispatcher
{
    static NeovimMessageDispatcher()
    {
        // Register update callback
        EditorApplication.update += Update;
    }

    public static void Update()
    {
        // Process message queue
        if (IPCServer.MessageQueue.Count > 0)
        {
            var message = IPCServer.MessageQueue.Dequeue();
            Debug.Log($"Dispatch message: {message.type}");
            HandleIPCMessage(message);
        }
    }

    /// <summary>
    /// Handle IPC message
    /// </summary>
    /// <param name="message">Received message</param>
    /// <returns></returns>
    public static void HandleIPCMessage(IPCMessage message)
    {
        switch (message.type)
        {
            case "executeMethod":
                if (message.arguments.Length < 2)
                {
                    Debug.LogWarning("Invalid arguments length");
                    return;
                }
                var typeName = message.arguments[0];
                var methodName = message.arguments[1];
                var args = message.arguments.Skip(2).ToArray();
                ExecuteMethod(typeName, methodName, args);
                break;
            default:
                Debug.LogWarning($"Unknown message type: {message.type}");
                break;
        }
    }

    /// <summary>
    /// Execute static method
    /// </summary>
    /// <param name="typeName"></param>
    /// <param name="methodName"></param>
    /// <param name="args"></param>
    /// <returns></returns>
    private static void ExecuteMethod(string typeName, string methodName, string[] args)
    {
        // Find type in loaded assemblies
        var (assembly, type) = AppDomain.CurrentDomain.GetAssemblies()
            .Select(asm => (assembly: asm, type: asm.GetType(typeName)))
            .FirstOrDefault(t => t.type != null);
        if (type == null)
        {
            Debug.LogWarning($"Type not found: {typeName}");
            return;
        }

        // Find method in type by name and parameter types.
        var paramTypes = args.Select(arg => typeof(string)).ToArray();
        var attrs = BindingFlags.Public | BindingFlags.Static;
        var method = type.GetMethod(methodName, attrs, null, paramTypes, null);
        if (method == null)
        {
            Debug.LogWarning($"Method not found: {methodName}");
            return;
        }

        // Execute method
        Debug.Log($"Executing {typeName}.{methodName} in {assembly.FullName}");
        _ = method.Invoke(null, args);
    }
}
