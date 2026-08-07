namespace Astral.Core.Updates;

internal static class AppUpdateStagingRetention
{
    internal const int MaxRetainedAttempts = 3;

    private const int MaxEntriesPerAttempt = 4096;
    private const string ActiveMarkerName = ".astral-update-active";
    private const string CompletedMarkerName = ".astral-update-completed";
    private const string AbandonedMarkerName = ".astral-update-abandoned";
    private static readonly TimeSpan MaxAttemptAge = TimeSpan.FromDays(7);

    internal static string BeginAttempt(
        string rootDirectory,
        string version,
        bool restrictAccess)
    {
        return BeginAttempt(
            rootDirectory,
            version,
            restrictAccess,
            DateTimeOffset.UtcNow);
    }

    internal static string BeginAttempt(
        string rootDirectory,
        string version,
        bool restrictAccess,
        DateTimeOffset now)
    {
        Cleanup(rootDirectory, now);
        var directory = ProtectedUpdateStaging.CreateVersionDirectory(
            rootDirectory,
            version,
            restrictAccess);
        WriteStateMarker(directory, ActiveMarkerName);
        return directory;
    }

    internal static void MarkCompleted(string attemptDirectory)
    {
        TransitionState(attemptDirectory, CompletedMarkerName);
    }

    internal static void MarkAbandoned(string attemptDirectory)
    {
        TransitionState(attemptDirectory, AbandonedMarkerName);
    }

    internal static void TryMarkAbandoned(string attemptDirectory)
    {
        try
        {
            MarkAbandoned(attemptDirectory);
        }
        catch (Exception exception) when (
            exception is IOException
                or UnauthorizedAccessException
                or InvalidOperationException
                or ArgumentException)
        {
            // Retention metadata must never replace the original preparation failure.
        }
    }

    internal static void Cleanup(string rootDirectory, DateTimeOffset now)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(rootDirectory);
        var root = Path.GetFullPath(rootDirectory);
        if (!Directory.Exists(root) || HasReparsePointInExistingAncestors(root))
        {
            return;
        }

        var candidates = FindCandidates(root)
            .OrderByDescending(candidate => candidate.LastWriteTimeUtc)
            .ToArray();

        for (var index = 0; index < candidates.Length; index++)
        {
            var candidate = candidates[index];
            var age = now.UtcDateTime - candidate.LastWriteTimeUtc;
            if (index < MaxRetainedAttempts && age < MaxAttemptAge)
            {
                continue;
            }

            if (!IsSafeAttemptTree(root, candidate.FullName))
            {
                continue;
            }

            try
            {
                Directory.Delete(candidate.FullName, recursive: true);
            }
            catch (Exception exception) when (
                exception is IOException
                    or UnauthorizedAccessException
                    or DirectoryNotFoundException)
            {
                // A locked or concurrently changed directory is retained safely.
            }
        }
    }

    private static IEnumerable<DirectoryInfo> FindCandidates(string root)
    {
        DirectoryInfo[] versionDirectories;
        try
        {
            versionDirectories = new DirectoryInfo(root).GetDirectories();
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            yield break;
        }

        foreach (var versionDirectory in versionDirectories)
        {
            if (!IsVersionDirectoryName(versionDirectory.Name)
                || IsReparsePoint(versionDirectory.FullName))
            {
                continue;
            }

            DirectoryInfo[] attemptDirectories;
            try
            {
                attemptDirectories = versionDirectory.GetDirectories();
            }
            catch (Exception exception) when (
                exception is IOException or UnauthorizedAccessException)
            {
                continue;
            }

            foreach (var attemptDirectory in attemptDirectories)
            {
                if (!IsAstralAttemptName(attemptDirectory.Name)
                    || IsReparsePoint(attemptDirectory.FullName)
                    || !HasSingleTerminalMarker(attemptDirectory.FullName))
                {
                    continue;
                }

                attemptDirectory.Refresh();
                yield return attemptDirectory;
            }
        }
    }

    private static bool IsVersionDirectoryName(string name)
    {
        return Version.TryParse(name, out var version)
            && string.Equals(
                AppUpdateService.FormatVersion(version),
                name,
                StringComparison.Ordinal);
    }

    private static bool IsAstralAttemptName(string name)
    {
        return name.Length == 32
            && string.Equals(name, name.ToLowerInvariant(), StringComparison.Ordinal)
            && Guid.TryParseExact(name, "N", out _);
    }

    private static bool HasSingleTerminalMarker(string directory)
    {
        var active = Path.Combine(directory, ActiveMarkerName);
        if (File.Exists(active))
        {
            return false;
        }

        var completed = Path.Combine(directory, CompletedMarkerName);
        var abandoned = Path.Combine(directory, AbandonedMarkerName);
        return IsSafeEmptyMarker(completed) ^ IsSafeEmptyMarker(abandoned);
    }

    private static bool IsSafeEmptyMarker(string path)
    {
        try
        {
            var marker = new FileInfo(path);
            return marker.Exists
                && marker.Length == 0
                && !marker.Attributes.HasFlag(FileAttributes.ReparsePoint);
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }

    private static bool IsSafeAttemptTree(string root, string attemptDirectory)
    {
        var fullAttempt = Path.GetFullPath(attemptDirectory);
        var relative = Path.GetRelativePath(root, fullAttempt);
        var parts = relative.Split(
            [Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar],
            StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length != 2
            || !IsVersionDirectoryName(parts[0])
            || !IsAstralAttemptName(parts[1])
            || relative.StartsWith("..", StringComparison.Ordinal))
        {
            return false;
        }

        var expected = Path.GetFullPath(Path.Combine(root, parts[0], parts[1]));
        if (!string.Equals(expected, fullAttempt, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var pending = new Stack<DirectoryInfo>();
        pending.Push(new DirectoryInfo(fullAttempt));
        var inspectedEntries = 0;
        try
        {
            while (pending.Count > 0)
            {
                var directory = pending.Pop();
                if (!directory.Exists
                    || directory.Attributes.HasFlag(FileAttributes.ReparsePoint))
                {
                    return false;
                }

                foreach (var entry in directory.EnumerateFileSystemInfos())
                {
                    inspectedEntries++;
                    if (inspectedEntries > MaxEntriesPerAttempt
                        || entry.Attributes.HasFlag(FileAttributes.ReparsePoint))
                    {
                        return false;
                    }

                    if (entry is DirectoryInfo childDirectory)
                    {
                        pending.Push(childDirectory);
                    }
                }
            }
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            return false;
        }

        return HasSingleTerminalMarker(fullAttempt);
    }

    private static bool IsReparsePoint(string directory)
    {
        try
        {
            var info = new DirectoryInfo(directory);
            return info.Exists
                && info.Attributes.HasFlag(FileAttributes.ReparsePoint);
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            return true;
        }
    }

    private static bool HasReparsePointInExistingAncestors(string path)
    {
        var fullPath = Path.GetFullPath(path);
        var pathRoot = Path.GetPathRoot(fullPath);
        if (string.IsNullOrWhiteSpace(pathRoot))
        {
            return true;
        }

        var current = pathRoot;
        foreach (var part in fullPath[pathRoot.Length..].Split(
                     [Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar],
                     StringSplitOptions.RemoveEmptyEntries))
        {
            current = Path.Combine(current, part);
            try
            {
                if (Directory.Exists(current) && IsReparsePoint(current))
                {
                    return true;
                }
            }
            catch (Exception exception) when (
                exception is IOException
                    or UnauthorizedAccessException
                    or ArgumentException)
            {
                return true;
            }
        }

        return false;
    }

    private static void TransitionState(string attemptDirectory, string terminalMarkerName)
    {
        ValidateAttemptDirectory(attemptDirectory);
        var activeMarker = Path.Combine(attemptDirectory, ActiveMarkerName);
        var terminalMarker = Path.Combine(attemptDirectory, terminalMarkerName);
        if (File.Exists(activeMarker))
        {
            File.Move(activeMarker, terminalMarker, overwrite: false);
            return;
        }

        WriteStateMarker(attemptDirectory, terminalMarkerName);
    }

    private static void WriteStateMarker(string attemptDirectory, string markerName)
    {
        ValidateAttemptDirectory(attemptDirectory);
        using var _ = new FileStream(
            Path.Combine(attemptDirectory, markerName),
            FileMode.CreateNew,
            FileAccess.Write,
            FileShare.None);
    }

    private static void ValidateAttemptDirectory(string attemptDirectory)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(attemptDirectory);
        var info = new DirectoryInfo(Path.GetFullPath(attemptDirectory));
        if (!info.Exists
            || !IsAstralAttemptName(info.Name)
            || IsReparsePoint(info.FullName)
            || info.Parent is null
            || !IsVersionDirectoryName(info.Parent.Name)
            || IsReparsePoint(info.Parent.FullName))
        {
            throw new InvalidOperationException(
                "Güncelleme staging denemesi güvenli bir Astral yolu değil.");
        }
    }
}
