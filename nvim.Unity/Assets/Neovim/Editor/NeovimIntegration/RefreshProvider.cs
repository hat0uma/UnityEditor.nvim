using System;
using Unity.CodeEditor;
using UnityEditor;

namespace NeovimEditor
{
    public class RefreshProvider
    {
        private const string RefreshRequestedKey = "NeovimEditor.RefreshRequested";
        private const string GenerateSolutionRequestedKey = "NeovimEditor.GenerateSolutionRequested";

        /// <summary>
        /// Event for refresh completed
        /// </summary>
        public event Action onRefreshCompleted;

        /// <summary>
        /// Event for generate solution completed
        /// </summary>
        public event Action onGenerateSolutionCompleted;

        /// <summary>
        /// Refresh requested state
        /// </summary>
        public bool RefreshRequested
        {
            get => SessionState.GetBool(RefreshRequestedKey, false);
            set => SessionState.SetBool(RefreshRequestedKey, value);
        }

        /// <summary>
        /// Generate solution requested state
        /// </summary>
        public bool GenerateSolutionRequested
        {
            get => SessionState.GetBool(GenerateSolutionRequestedKey, false);
            set => SessionState.SetBool(GenerateSolutionRequestedKey, value);
        }

        /// <summary>
        /// Refresh
        /// </summary>
        public void Refresh()
        {
            AssetDatabase.Refresh();
            RefreshRequested = true;
        }

        /// <summary>
        /// Generate solution
        /// </summary>
        public void GenerateSolution()
        {
            AssetDatabase.Refresh();
            CodeEditor.Editor.CurrentCodeEditor.SyncAll();
            GenerateSolutionRequested = true;
        }

        public void Update()
        {
            // Check if refresh is completed
            var refreshing = EditorApplication.isCompiling || EditorApplication.isUpdating;
            if (RefreshRequested && !refreshing)
            {
                RefreshRequested = false;
                onRefreshCompleted?.Invoke();
            }

            // Check if generate solution is completed
            if (GenerateSolutionRequested && !refreshing)
            {
                GenerateSolutionRequested = false;
                onGenerateSolutionCompleted?.Invoke();
            }
        }
    }
}
