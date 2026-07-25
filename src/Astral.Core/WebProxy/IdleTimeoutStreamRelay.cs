using System.Diagnostics;

namespace Astral.Core.WebProxy;

public static class IdleTimeoutStreamRelay
{
    public static async Task RelayAsync(
        Stream first,
        Stream second,
        TimeSpan idleTimeout,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(first);
        ArgumentNullException.ThrowIfNull(second);
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(
            idleTimeout,
            TimeSpan.Zero);

        using var relayCancellation =
            CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        long lastActivityTimestamp = Stopwatch.GetTimestamp();
        void MarkActivity() =>
            Interlocked.Exchange(
                ref lastActivityTimestamp,
                Stopwatch.GetTimestamp());
        var firstToSecond = CopyAsync(
            first,
            second,
            MarkActivity,
            relayCancellation.Token);
        var secondToFirst = CopyAsync(
            second,
            first,
            MarkActivity,
            relayCancellation.Token);
        var idleMonitor = MonitorIdleAsync(
            () => Interlocked.Read(ref lastActivityTimestamp),
            idleTimeout,
            relayCancellation.Token);

        await Task.WhenAny(firstToSecond, secondToFirst, idleMonitor);
        relayCancellation.Cancel();
        try
        {
            await Task.WhenAll(firstToSecond, secondToFirst, idleMonitor);
        }
        catch (Exception exception)
            when (exception is OperationCanceledException
                or IOException
                or ObjectDisposedException)
        {
        }
    }

    private static async Task CopyAsync(
        Stream source,
        Stream destination,
        Action markActivity,
        CancellationToken cancellationToken)
    {
        var buffer = new byte[16 * 1024];
        while (!cancellationToken.IsCancellationRequested)
        {
            var read = await source.ReadAsync(buffer, cancellationToken);
            if (read == 0)
            {
                return;
            }

            markActivity();
            await destination.WriteAsync(
                buffer.AsMemory(0, read),
                cancellationToken);
            await destination.FlushAsync(cancellationToken);
        }
    }

    private static async Task MonitorIdleAsync(
        Func<long> getLastActivityTimestamp,
        TimeSpan idleTimeout,
        CancellationToken cancellationToken)
    {
        var pollInterval = TimeSpan.FromTicks(Math.Clamp(
            idleTimeout.Ticks / 4,
            TimeSpan.FromMilliseconds(10).Ticks,
            TimeSpan.FromSeconds(5).Ticks));
        while (!cancellationToken.IsCancellationRequested)
        {
            await Task.Delay(pollInterval, cancellationToken);
            if (Stopwatch.GetElapsedTime(getLastActivityTimestamp()) >= idleTimeout)
            {
                return;
            }
        }
    }
}
