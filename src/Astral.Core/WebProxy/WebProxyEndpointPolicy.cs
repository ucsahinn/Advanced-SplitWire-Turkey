using System.Net;
using System.Net.Sockets;

namespace Astral.Core.WebProxy;

public static class WebProxyEndpointPolicy
{
    public static bool IsAllowedPort(string method, int port)
    {
        return method.Equals("CONNECT", StringComparison.OrdinalIgnoreCase)
            ? port == 443
            : port == 80;
    }

    public static bool HasMatchingHttpAuthority(
        string requestTarget,
        string hostHeader)
    {
        if (!Uri.TryCreate(requestTarget, UriKind.Absolute, out var targetUri))
        {
            return true;
        }

        if (!targetUri.Scheme.Equals(Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase)
            || !string.IsNullOrEmpty(targetUri.UserInfo)
            || !TryParseHttpAuthority(hostHeader, out var headerHost, out var headerPort))
        {
            return false;
        }

        return string.Equals(
                targetUri.IdnHost.TrimEnd('.'),
                headerHost,
                StringComparison.OrdinalIgnoreCase)
            && targetUri.Port == headerPort;
    }

    public static bool IsPublicAddress(IPAddress address)
    {
        if (address.IsIPv4MappedToIPv6)
        {
            address = address.MapToIPv4();
        }

        if (IPAddress.IsLoopback(address)
            || address.Equals(IPAddress.Any)
            || address.Equals(IPAddress.IPv6Any))
        {
            return false;
        }

        if (address.AddressFamily == AddressFamily.InterNetwork)
        {
            var bytes = address.GetAddressBytes();
            return bytes[0] switch
            {
                0 or 10 or 127 => false,
                100 when bytes[1] is >= 64 and <= 127 => false,
                169 when bytes[1] == 254 => false,
                172 when bytes[1] is >= 16 and <= 31 => false,
                192 when bytes[1] == 0 && bytes[2] is 0 or 2 => false,
                192 when bytes[1] == 88 && bytes[2] == 99 => false,
                192 when bytes[1] == 168 => false,
                198 when bytes[1] is 18 or 19 => false,
                198 when bytes[1] == 51 && bytes[2] == 100 => false,
                203 when bytes[1] == 0 && bytes[2] == 113 => false,
                >= 224 => false,
                _ => true
            };
        }

        if (address.AddressFamily != AddressFamily.InterNetworkV6
            || address.IsIPv6LinkLocal
            || address.IsIPv6Multicast
            || address.IsIPv6SiteLocal)
        {
            return false;
        }

        var ipv6 = address.GetAddressBytes();
        if ((ipv6[0] & 0xFE) == 0xFC)
        {
            return false;
        }

        if (ipv6.AsSpan(0, 12).SequenceEqual(
                new byte[] { 0x00, 0x64, 0xFF, 0x9B, 0, 0, 0, 0, 0, 0, 0, 0 })
            || ipv6.AsSpan(0, 6).SequenceEqual(
                new byte[] { 0x00, 0x64, 0xFF, 0x9B, 0x00, 0x01 }))
        {
            return false;
        }

        return !(ipv6[0] == 0x20
            && ipv6[1] == 0x01
            && ipv6[2] == 0x0D
            && ipv6[3] == 0xB8);
    }

    private static bool TryParseHttpAuthority(
        string value,
        out string host,
        out int port)
    {
        host = string.Empty;
        port = 80;
        if (string.IsNullOrWhiteSpace(value)
            || value.IndexOfAny(['/', '\\', '?', '#', '@']) >= 0
            || !Uri.TryCreate(
                Uri.UriSchemeHttp + "://" + value.Trim(),
                UriKind.Absolute,
                out var uri)
            || string.IsNullOrWhiteSpace(uri.Host)
            || !string.IsNullOrEmpty(uri.UserInfo))
        {
            return false;
        }

        host = uri.IdnHost.TrimEnd('.');
        port = uri.Port;
        return port is > 0 and <= 65535;
    }
}
