using System.IO;

namespace Astral.App;

internal static class PortablePackageSelfTest
{
    private static readonly string[] RequiredRelativePaths =
    [
        "Astral.Updater.exe",
        "Astral.WebProxy.exe",
        Path.Combine("Assets", "background.mp4"),
        "astral.update-manifest.json"
    ];

    public static void Verify(string applicationDirectory)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(applicationDirectory);
        var root = Path.GetFullPath(applicationDirectory);
        foreach (var relativePath in RequiredRelativePaths)
        {
            var path = Path.Combine(root, relativePath);
            var file = new FileInfo(path);
            if (!file.Exists)
            {
                throw new FileNotFoundException(
                    $"Portable pakette zorunlu dosya eksik: {relativePath}",
                    path);
            }
            if (file.Length <= 0)
            {
                throw new InvalidDataException(
                    $"Portable pakette zorunlu dosya boş: {relativePath}");
            }

            using var stream = file.Open(FileMode.Open, FileAccess.Read, FileShare.Read);
            _ = stream.ReadByte();
        }
    }
}
