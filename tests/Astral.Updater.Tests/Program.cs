using System.Reflection;

var tests = new (string Name, Action Run)[]
{
    ("Rollback silme hatasinda diger dosyalari geri yukler ve fail-closed davranir", RollbackDeleteFailureIsFailClosed),
    ("Rollback geri tasima hatasinda karisik durum uyarisi verir", RollbackMoveFailureReportsMixedState),
    ("Apply sonrasi yeniden baslatma hatasi eski surum korundu demez", RelaunchFailureReportsAppliedState)
};

var failures = new List<string>();
foreach (var test in tests)
{
    try
    {
        test.Run();
        Console.WriteLine("PASS " + test.Name);
    }
    catch (Exception exception)
    {
        failures.Add(test.Name + ": " + exception.Message);
        Console.Error.WriteLine("FAIL " + test.Name + ": " + exception);
    }
}

if (failures.Count > 0)
{
    Console.Error.WriteLine($"{failures.Count} updater testi basarisiz.");
    return 1;
}

Console.WriteLine($"{tests.Length} updater testi basarili.");
return 0;

static void RollbackDeleteFailureIsFailClosed()
{
    using var fixture = new RollbackFixture();
    var lockedPartial = fixture.CreateFile("target/new-file.dll", "partial");
    var restoredDestination = Path.Combine(fixture.Root, "target", "old-file.dll");
    var backup = fixture.CreateFile("backup/old-file.dll", "old-version");

    using var lockStream = new FileStream(
        lockedPartial,
        FileMode.Open,
        FileAccess.Read,
        FileShare.Read);

    var exception = InvokeRestoreBackup(
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [restoredDestination] = backup
        },
        [lockedPartial],
        fixture.LogPath);

    Assert(exception is not null, "Rollback silme hatasini yuttu.");
    Assert(
        File.ReadAllText(restoredDestination) == "old-version",
        "Bir dosya silinemeyince diger yedek geri yuklenmedi.");
    Assert(
        !exception!.Message.Contains("Mevcut sürüm korundu", StringComparison.OrdinalIgnoreCase),
        "Rollback hatasi mevcut surumun korundugunu iddia etti.");
}

static void RollbackMoveFailureReportsMixedState()
{
    using var fixture = new RollbackFixture();
    var destination = fixture.CreateFile("target/locked.dll", "partial-version");
    var backup = fixture.CreateFile("backup/locked.dll", "old-version");

    using var lockStream = new FileStream(
        destination,
        FileMode.Open,
        FileAccess.Read,
        FileShare.Read);

    var exception = InvokeRestoreBackup(
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [destination] = backup
        },
        [],
        fixture.LogPath);

    Assert(exception is not null, "Rollback geri tasima hatasini yuttu.");
    var detail = InvokeFormatFailureDetail(exception!);
    Assert(
        detail.Contains("karışık durumda", StringComparison.OrdinalIgnoreCase),
        "Kullaniciya kurulumun karisik durumda olabilecegi soylenmedi.");
    Assert(
        !detail.Contains("Mevcut sürüm korundu", StringComparison.OrdinalIgnoreCase),
        "Karisik durumda mevcut surumun korundugu iddia edildi.");
}

static void RelaunchFailureReportsAppliedState()
{
    var detail = InvokeFormatFailureDetail(
        new InvalidOperationException("Process start failed."),
        payloadApplied: true);
    Assert(
        detail.Contains("dosyaları uygulandı", StringComparison.OrdinalIgnoreCase),
        "Apply sonrasi hata yeni dosyalarin uygulandigini soylemedi.");
    Assert(
        detail.Contains("elle açın", StringComparison.OrdinalIgnoreCase),
        "Apply sonrasi hata elle yeniden acma yonlendirmesi vermedi.");
    Assert(
        !detail.Contains("Mevcut sürüm korundu", StringComparison.OrdinalIgnoreCase),
        "Apply sonrasi hata yanlislikla eski surumun korundugunu iddia etti.");
}

static Exception? InvokeRestoreBackup(
    IReadOnlyDictionary<string, string> backups,
    IEnumerable<string> copiedWithoutBackup,
    string logPath)
{
    var assembly = LoadUpdaterAssembly();
    var updaterType = assembly.GetType("AstralUpdater", throwOnError: true)!;
    var logType = assembly.GetType("UpdateLog", throwOnError: true)!;
    var log = Activator.CreateInstance(
        logType,
        BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic,
        binder: null,
        args: [logPath],
        culture: null)!;
    var method = updaterType.GetMethod(
        "RestoreBackup",
        BindingFlags.Static | BindingFlags.NonPublic)
        ?? throw new InvalidOperationException("RestoreBackup bulunamadi.");

    try
    {
        method.Invoke(null, [backups, copiedWithoutBackup, log]);
        return null;
    }
    catch (TargetInvocationException exception)
    {
        return exception.InnerException ?? exception;
    }
}

static string InvokeFormatFailureDetail(
    Exception exception,
    bool payloadApplied = false)
{
    var updaterType = LoadUpdaterAssembly().GetType("AstralUpdater", throwOnError: true)!;
    var method = updaterType.GetMethod(
        "FormatFailureDetail",
        BindingFlags.Static | BindingFlags.NonPublic)
        ?? throw new InvalidOperationException("FormatFailureDetail bulunamadi.");
    return (string)method.Invoke(null, [exception, payloadApplied])!;
}

static Assembly LoadUpdaterAssembly()
{
    var path = Path.Combine(AppContext.BaseDirectory, "Astral.Updater.dll");
    return Assembly.LoadFrom(path);
}

static void Assert(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}

internal sealed class RollbackFixture : IDisposable
{
    public RollbackFixture()
    {
        Root = Path.Combine(Path.GetTempPath(), "astral-updater-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Root);
        LogPath = Path.Combine(Root, "logs", "updater.log");
    }

    public string Root { get; }

    public string LogPath { get; }

    public string CreateFile(string relativePath, string content)
    {
        var path = Path.Combine(Root, relativePath.Replace('/', Path.DirectorySeparatorChar));
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, content);
        return path;
    }

    public void Dispose()
    {
        try
        {
            Directory.Delete(Root, recursive: true);
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
