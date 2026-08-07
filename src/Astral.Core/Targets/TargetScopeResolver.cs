using Astral.Core.Discord;
using Astral.Core.WebProxy;

namespace Astral.Core.Targets;

public sealed class TargetScopeResolver
{
    private readonly TargetRegistry _registry;
    private readonly DiscordAppScope _discordScope;
    private readonly string _webProxyExecutablePath;
    private readonly ITargetExecutablePathResolver _targetExecutablePathResolver;

    public TargetScopeResolver(
        TargetRegistry registry,
        DiscordAppScope discordScope,
        string webProxyExecutablePath,
        ITargetExecutablePathResolver? targetExecutablePathResolver = null)
    {
        _registry = registry ?? throw new ArgumentNullException(nameof(registry));
        _discordScope = discordScope ?? throw new ArgumentNullException(nameof(discordScope));
        _webProxyExecutablePath = Path.GetFullPath(
            string.IsNullOrWhiteSpace(webProxyExecutablePath)
                ? throw new ArgumentException("Web proxy yolu boş olamaz.", nameof(webProxyExecutablePath))
                : webProxyExecutablePath);
        _targetExecutablePathResolver = targetExecutablePathResolver
            ?? new WindowsTargetExecutablePathResolver();
    }

    public RoutingPlan Resolve(TargetSelection selection)
    {
        ArgumentNullException.ThrowIfNull(selection);

        var selectedTargets = new List<TargetDefinition>();
        var allowedApplications = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        var proxyRules = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var targetId in selection.SelectedTargetIds
                     .Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (!_registry.TryGet(targetId, out var target))
            {
                continue;
            }

            selectedTargets.Add(target);
            AddApplications(target, allowedApplications);
            AddProxyRules(target.Domains, proxyRules);
        }

        if (proxyRules.Count > 0)
        {
            allowedApplications.Add(_webProxyExecutablePath);
        }

        var allowed = allowedApplications
            .Where(app => !RoutingPlan.IsBrowserExecutable(app))
            .ToArray();

        if (allowed.Length == 0)
        {
            throw new InvalidOperationException("Tünel kapsamı en az bir uygulama içermelidir.");
        }

        return new RoutingPlan(
            selectedTargets,
            allowed,
            proxyRules.Select(DomainPattern.Parse).ToArray());
    }

    private void AddApplications(
        TargetDefinition target,
        SortedSet<string> allowedApplications)
    {
        if (!target.HasApplicationScope)
        {
            return;
        }

        if (target.Id.Equals(TargetIds.Discord, StringComparison.OrdinalIgnoreCase))
        {
            foreach (var app in _discordScope.GetAllowedApplications(includeBrowserAccess: false))
            {
                allowedApplications.Add(app);
            }

            return;
        }

        foreach (var executablePath in _targetExecutablePathResolver.Resolve(target))
        {
            if (Path.IsPathFullyQualified(executablePath))
            {
                allowedApplications.Add(Path.GetFullPath(executablePath));
            }
        }
    }

    private static void AddProxyRules(
        IEnumerable<DomainPattern> domains,
        SortedSet<string> proxyRules)
    {
        foreach (var domain in domains)
        {
            proxyRules.Add(domain.Pattern);
        }
    }
}
