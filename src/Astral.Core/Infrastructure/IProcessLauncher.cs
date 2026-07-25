namespace Astral.Core.Infrastructure;

public interface IProcessLauncher
{
    IManagedProcess Start(
        string executable,
        IReadOnlyList<string> arguments,
        string workingDirectory,
        string logPath);

    IManagedProcess Start(
        string executable,
        IReadOnlyList<string> arguments,
        string workingDirectory,
        string logPath,
        IReadOnlyDictionary<string, string?> environment) =>
        Start(executable, arguments, workingDirectory, logPath);
}
