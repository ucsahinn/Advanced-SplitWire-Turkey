using Astral.Core.Updates;

namespace Astral.Core.Security;

public static class VerifiedExecutableStager
{
    public static string Stage(
        string sourcePath,
        string stagingRoot,
        string version,
        bool restrictAccess,
        Action<string> trustVerifier)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(sourcePath);
        ArgumentException.ThrowIfNullOrWhiteSpace(stagingRoot);
        ArgumentException.ThrowIfNullOrWhiteSpace(version);
        ArgumentNullException.ThrowIfNull(trustVerifier);

        var source = Path.GetFullPath(sourcePath);
        if (!File.Exists(source))
        {
            throw new FileNotFoundException(
                "Korumalı alana alınacak executable bulunamadı.",
                source);
        }

        if (File.GetAttributes(source).HasFlag(FileAttributes.ReparsePoint))
        {
            throw new InvalidDataException(
                "Executable kaynağı symlink veya reparse point olamaz.");
        }

        var stagingDirectory = ProtectedUpdateStaging.CreateVersionDirectory(
            stagingRoot,
            version,
            restrictAccess);
        var destination = Path.Combine(
            stagingDirectory,
            Path.GetFileName(source));
        File.Copy(source, destination, overwrite: false);
        if (File.GetAttributes(destination).HasFlag(FileAttributes.ReparsePoint))
        {
            throw new InvalidDataException(
                "Staging executable symlink veya reparse point olamaz.");
        }

        trustVerifier(destination);
        return destination;
    }
}
