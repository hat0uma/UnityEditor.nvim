using System;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace NeovimEditor
{
    [InitializeOnLoad]
    public static class NeovimMessageDispatcher
    {
        static NeovimMessageDispatcher()
        {
            // Register update callback
            EditorApplication.update += Update;
        }

        // Whitelist of commands that can be executed from Neovim.
        private static readonly (string type, string method)[] _commandWhiteList = new (string type, string method)[]
        {
        ( "UnityEditor.AssetDatabase", "Refresh" ),
        ( "UnityEditor.EditorApplication", "EnterPlaymode" ),
        ( "UnityEditor.EditorApplication", "ExitPlaymode" ),
        ( "UnityEditor.SyncVS", "SyncSolution" ),
        };

        public static void Update()
        {
            // Process message queue
            IPCMessage message;
            if (IPCServerInstance.MessageQueue.TryDequeue(out message))
            {
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
            // Check if command is allowed
            if (!_commandWhiteList.Contains((typeName, methodName)))
            {
                Debug.LogWarning($"Command not allowed: {typeName}.{methodName}");
                return;
            }

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

}
