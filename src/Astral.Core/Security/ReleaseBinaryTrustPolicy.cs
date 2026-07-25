namespace Astral.Core.Security;

public static class ReleaseBinaryTrustPolicy
{
    public static bool ValidateCompanions(
        string applicationPath,
        IReadOnlyList<string> companionPaths,
        Func<string, string?> signerResolver,
        bool requireSignedApplication = false)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(applicationPath);
        ArgumentNullException.ThrowIfNull(companionPaths);
        ArgumentNullException.ThrowIfNull(signerResolver);

        var applicationSigner = Normalize(signerResolver(applicationPath));
        if (applicationSigner is null)
        {
            if (requireSignedApplication)
            {
                throw new InvalidDataException(
                    "Resmi Astral release imzası doğrulanamadı.");
            }

            return false;
        }

        foreach (var companionPath in companionPaths)
        {
            ArgumentException.ThrowIfNullOrWhiteSpace(companionPath);
            var companionSigner = Normalize(signerResolver(companionPath));
            if (!string.Equals(
                    applicationSigner,
                    companionSigner,
                    StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException(
                    $"{Path.GetFileName(companionPath)} Astral release imzasıyla eşleşmiyor.");
            }
        }

        return true;
    }

    private static string? Normalize(string? thumbprint)
    {
        if (string.IsNullOrWhiteSpace(thumbprint))
        {
            return null;
        }

        return string.Concat(thumbprint.Where(character => !char.IsWhiteSpace(character)))
            .ToUpperInvariant();
    }
}
