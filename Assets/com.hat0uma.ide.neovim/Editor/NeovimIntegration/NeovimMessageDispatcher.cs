using System;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace NeovimEditor
{
    public class NeovimMessageDispatcher
    {
        // Whitelist of commands that can be executed from Neovim.
        private static readonly (string type, string method)[] commandWhiteList = new (string type, string method)[]
        {
        ( "UnityEditor.AssetDatabase", "Refresh" ),
        ( "UnityEditor.EditorApplication", "EnterPlaymode" ),
        ( "UnityEditor.EditorApplication", "ExitPlaymode" ),
        ( "UnityEditor.SyncVS", "SyncSolution" ),
        };

        /// <summary>
        /// Dispatch IPC message
        /// </summary>
        /// <param name="message">Received message</param>
        /// <returns></returns>
        public static void Dispatch(IPCMessage message)
        {
            switch (message.type)
            {
                case "refrsh":
                    Refresh();
                    break;

                case "enter_playmode":
                    EnterPlaymode();
                    break;

                case "exit_playmode":
                    ExitPlaymode();
                    break;

                case "generate_sln":
                    GenerateSolution();
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
            if (!commandWhiteList.Contains((typeName, methodName)))
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

        private static void Refresh()
        {
            AssetDatabase.Refresh();
        }

        private static void EnterPlaymode()
        {
            EditorApplication.EnterPlaymode();
        }

        private static void ExitPlaymode()
        {
            EditorApplication.ExitPlaymode();
        }

        private static void GenerateSolution()
        {
            // UnityEditor.SyncVS.SyncSolution() is internal, so use reflection to call it.
            var assembly = typeof(UnityEditor.Editor).Assembly;
            var SyncVS = assembly.GetType("UnityEditor.SyncVS");
            if (SyncVS == null)
            {
                Debug.LogWarning("Type not found: UnityEditor.SyncVS");
                return;
            }

            var method = SyncVS.GetMethod("SyncSolution", BindingFlags.Public | BindingFlags.Static);
            if (method == null)
            {
                Debug.LogWarning("Method not found: UnityEditor.SyncVS.SyncSolution");
                return;
            }

            method.Invoke(null, null);
        }

    }

}
