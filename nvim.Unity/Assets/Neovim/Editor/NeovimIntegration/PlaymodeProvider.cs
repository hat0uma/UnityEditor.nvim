using System;
using UnityEditor;

public class PlaymodeProvider
{
    private const string EnterPlaymodeRequestedKey = "NeovimEditor.EnterPlaymodeRequested";
    private const string ExitPlaymodeRequestedKey = "NeovimEditor.ExitPlaymodeRequested";

    /// <summary>
    /// Callback for entering playmode
    /// </summary>
    public event Action onPlaymodeEnter;

    /// <summary>
    /// Callback for exiting playmode
    /// </summary>
    public event Action onPlaymodeExit;

    /// <summary>
    /// Enter playmode
    /// </summary>
    public void EnterPlaymode()
    {
        EnterPlaymodeRequested = true;
        EditorApplication.EnterPlaymode();
    }

    /// <summary>
    /// Exit playmode
    /// </summary>
    public void ExitPlaymode()
    {
        ExitPlaymodeRequested = true;
        EditorApplication.ExitPlaymode();
    }

    /// <summary>
    /// Toggle playmode
    /// </summary>
    public void TogglePlaymode()
    {
        if (EditorApplication.isPlaying)
        {
            ExitPlaymode();
        }
        else
        {
            EnterPlaymode();
        }
    }

    /// <summary>
    /// Check if playmode is requested
    /// </summary>
    public bool EnterPlaymodeRequested
    {
        get => SessionState.GetBool(EnterPlaymodeRequestedKey, false);
        set => SessionState.SetBool(EnterPlaymodeRequestedKey, value);
    }

    /// <summary>
    /// Check if exit playmode is requested
    /// </summary>
    public bool ExitPlaymodeRequested
    {
        get => SessionState.GetBool(ExitPlaymodeRequestedKey, false);
        set => SessionState.SetBool(ExitPlaymodeRequestedKey, value);
    }

    public void Update()
    {
        if (EnterPlaymodeRequested && EditorApplication.isPlaying)
        {
            EnterPlaymodeRequested = false;
            onPlaymodeEnter?.Invoke();
        }

        if (ExitPlaymodeRequested && !EditorApplication.isPlaying)
        {
            ExitPlaymodeRequested = false;
            onPlaymodeExit?.Invoke();
        }
    }
}
