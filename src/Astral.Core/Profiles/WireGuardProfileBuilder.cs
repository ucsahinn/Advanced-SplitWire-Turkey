namespace Astral.Core.Profiles;

public static class WireGuardProfileBuilder
{
    private const string StableCloudflareWarpIpv4Endpoint =
        "162.159.192.1:2408";
    private static readonly string[] CloudflareWarpEndpointsRequiringIpv4 =
    [
        "engage.cloudflareclient.com:2408",
        "[2606:4700:d0::a29f:c001]:2408"
    ];

    public static string BuildScopedProfile(
        string sourceProfile,
        IEnumerable<string> allowedApplications)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(sourceProfile);
        ArgumentNullException.ThrowIfNull(allowedApplications);

        var apps = allowedApplications
            .Select(NormalizeApplication)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Order(StringComparer.OrdinalIgnoreCase)
            .Select(FormatApplication)
            .ToArray();

        if (apps.Length == 0)
        {
            throw new InvalidOperationException(
                "At least one application must be present in AllowedApps.");
        }

        var sourceLines = sourceProfile
            .Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace('\r', '\n')
            .Split('\n');

        if (!sourceLines.Any(line =>
                line.Trim().Equals("[Interface]", StringComparison.OrdinalIgnoreCase))
            || !sourceLines.Any(line =>
                line.Trim().Equals("[Peer]", StringComparison.OrdinalIgnoreCase)))
        {
            throw new InvalidDataException("The generated WireGuard profile is incomplete.");
        }

        var result = new List<string>(sourceLines.Length + 1);
        var inserted = false;

        foreach (var sourceLine in sourceLines)
        {
            var trimmed = sourceLine.Trim();
            if (IsAllowedAppsDirective(trimmed))
            {
                continue;
            }

            result.Add(NormalizeCloudflareWarpEndpoint(sourceLine).TrimEnd());

            if (!inserted && trimmed.StartsWith("Endpoint", StringComparison.OrdinalIgnoreCase))
            {
                result.Add($"AllowedApps = {string.Join(", ", apps)}");
                inserted = true;
            }
        }

        if (!inserted)
        {
            throw new InvalidDataException("The generated profile does not contain a peer endpoint.");
        }

        return string.Join("\r\n", result).TrimEnd() + "\r\n";
    }

    private static string NormalizeCloudflareWarpEndpoint(string sourceLine)
    {
        var trimmed = sourceLine.Trim();
        var separatorIndex = trimmed.IndexOf('=');
        if (separatorIndex < 0
            || !trimmed[..separatorIndex].Trim().Equals(
                "Endpoint",
                StringComparison.OrdinalIgnoreCase))
        {
            return sourceLine;
        }

        var endpoint = trimmed[(separatorIndex + 1)..].Trim();
        return CloudflareWarpEndpointsRequiringIpv4.Contains(
            endpoint,
            StringComparer.OrdinalIgnoreCase)
            ? "Endpoint = " + StableCloudflareWarpIpv4Endpoint
            : sourceLine;
    }

    private static string NormalizeApplication(string value)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            throw new InvalidDataException("AllowedApps cannot contain an empty value.");
        }

        if (normalized.IndexOfAny([',', '"', '\r', '\n']) >= 0)
        {
            throw new InvalidDataException(
                $"AllowedApps contains an unsafe value: {normalized}");
        }

        return normalized;
    }

    private static string FormatApplication(string value)
    {
        if (!value.Any(char.IsWhiteSpace))
        {
            return value;
        }

        return "\"" + value + "\"";
    }

    private static bool IsAllowedAppsDirective(string value)
    {
        return value.StartsWith("AllowedApps", StringComparison.OrdinalIgnoreCase)
            || value.StartsWith("#@ws:AllowedApps", StringComparison.OrdinalIgnoreCase);
    }
}
