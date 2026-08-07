using System.Diagnostics;
using System.Runtime.Versioning;
using Microsoft.Win32;

namespace Astral.Core.Targets;

public interface ITargetExecutablePathResolver
{
    IReadOnlyList<string> Resolve(TargetDefinition target);
}

public sealed class WindowsTargetExecutablePathResolver : ITargetExecutablePathResolver
{
    private const int MaxSearchDepth = 4;
    private const int MaxInspectedEntries = 2_000;

    public IReadOnlyList<string> Resolve(TargetDefinition target)
    {
        ArgumentNullException.ThrowIfNull(target);
        if (!OperatingSystem.IsWindows())
        {
            return [];
        }

        var paths = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var candidate in EnumerateCandidates(target))
        {
            if (TryValidateCandidate(target, candidate, out var trustedPath))
            {
                paths.Add(trustedPath);
            }
        }

        return paths.ToArray();
    }

    [SupportedOSPlatform("windows")]
    private static IEnumerable<string> EnumerateCandidates(TargetDefinition target)
    {
        foreach (var hint in target.ExecutableHints)
        {
            var processName = Path.GetFileNameWithoutExtension(hint.FileName);
            Process[] processes;
            try
            {
                processes = Process.GetProcessesByName(processName);
            }
            catch
            {
                processes = [];
            }

            foreach (var process in processes)
            {
                using (process)
                {
                    string? path = null;
                    try
                    {
                        path = process.MainModule?.FileName;
                    }
                    catch (Exception exception) when (
                        exception is InvalidOperationException
                            or System.ComponentModel.Win32Exception
                            or NotSupportedException)
                    {
                    }

                    if (!string.IsNullOrWhiteSpace(path))
                    {
                        yield return path;
                    }
                }
            }

            foreach (var path in EnumerateMachineAppPaths(hint.FileName))
            {
                yield return path;
            }

            foreach (var path in EnumerateKnownInstallRoots(target, hint.FileName))
            {
                yield return path;
            }
        }
    }

    [SupportedOSPlatform("windows")]
    private static IEnumerable<string> EnumerateMachineAppPaths(string executableName)
    {
        foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
        {
            RegistryKey? baseKey = null;
            RegistryKey? appKey = null;
            try
            {
                baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view);
                appKey = baseKey.OpenSubKey(
                    @"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" + executableName,
                    writable: false);
                if (appKey?.GetValue(null) is string path
                    && !string.IsNullOrWhiteSpace(path))
                {
                    yield return path.Trim().Trim('"');
                }
            }
            finally
            {
                appKey?.Dispose();
                baseKey?.Dispose();
            }
        }
    }

    private static IEnumerable<string> EnumerateKnownInstallRoots(
        TargetDefinition target,
        string executableName)
    {
        var roots = new[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)
        }
        .Where(path => !string.IsNullOrWhiteSpace(path) && Directory.Exists(path))
        .Distinct(StringComparer.OrdinalIgnoreCase);

        var directoryNames = new[]
        {
            target.Label,
            target.Id,
            Path.GetFileNameWithoutExtension(executableName)
        }
        .Where(name => !string.IsNullOrWhiteSpace(name))
        .Distinct(StringComparer.OrdinalIgnoreCase);

        foreach (var root in roots)
        {
            foreach (var directoryName in directoryNames)
            {
                var candidateRoot = Path.Combine(root, directoryName);
                foreach (var path in EnumerateBoundedFiles(candidateRoot, executableName))
                {
                    yield return path;
                }
            }
        }
    }

    private static IEnumerable<string> EnumerateBoundedFiles(
        string root,
        string executableName)
    {
        if (!Directory.Exists(root) || IsReparsePoint(root))
        {
            yield break;
        }

        var pending = new Queue<(DirectoryInfo Directory, int Depth)>();
        pending.Enqueue((new DirectoryInfo(root), 0));
        var inspected = 0;
        while (pending.Count > 0 && inspected < MaxInspectedEntries)
        {
            var (directory, depth) = pending.Dequeue();
            FileSystemInfo[] entries;
            try
            {
                entries = directory.GetFileSystemInfos();
            }
            catch (Exception exception) when (
                exception is IOException or UnauthorizedAccessException)
            {
                continue;
            }

            foreach (var entry in entries)
            {
                inspected++;
                if (inspected > MaxInspectedEntries
                    || entry.Attributes.HasFlag(FileAttributes.ReparsePoint))
                {
                    continue;
                }

                if (entry is FileInfo file
                    && file.Name.Equals(executableName, StringComparison.OrdinalIgnoreCase))
                {
                    yield return file.FullName;
                }
                else if (entry is DirectoryInfo child && depth < MaxSearchDepth)
                {
                    pending.Enqueue((child, depth + 1));
                }
            }
        }
    }

    private static bool TryValidateCandidate(
        TargetDefinition target,
        string candidate,
        out string trustedPath)
    {
        trustedPath = string.Empty;
        try
        {
            var fullPath = Path.GetFullPath(candidate);
            if (!Path.IsPathFullyQualified(fullPath)
                || !File.Exists(fullPath)
                || IsReparsePoint(fullPath)
                || HasReparsePointInExistingAncestors(fullPath)
                || !target.ExecutableHints.Any(hint =>
                    hint.FileName.Equals(
                        Path.GetFileName(fullPath),
                        StringComparison.OrdinalIgnoreCase)))
            {
                return false;
            }

            if (IsUnderProtectedInstallRoot(fullPath))
            {
                trustedPath = fullPath;
                return true;
            }
        }
        catch (Exception exception) when (
            exception is IOException
                or UnauthorizedAccessException
                or ArgumentException
                or NotSupportedException
                or PlatformNotSupportedException)
        {
        }

        return false;
    }

    private static bool IsUnderProtectedInstallRoot(string path)
    {
        foreach (var root in new[]
                 {
                     Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                     Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)
                 })
        {
            if (string.IsNullOrWhiteSpace(root))
            {
                continue;
            }

            var normalizedRoot = Path.GetFullPath(root)
                .TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            if (path.StartsWith(normalizedRoot, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static bool HasReparsePointInExistingAncestors(string path)
    {
        var current = new FileInfo(path).Directory;
        while (current is not null)
        {
            if (current.Exists
                && current.Attributes.HasFlag(FileAttributes.ReparsePoint))
            {
                return true;
            }

            current = current.Parent;
        }

        return false;
    }

    private static bool IsReparsePoint(string path)
    {
        try
        {
            return File.GetAttributes(path).HasFlag(FileAttributes.ReparsePoint);
        }
        catch (Exception exception) when (
            exception is IOException or UnauthorizedAccessException)
        {
            return true;
        }
    }
}
