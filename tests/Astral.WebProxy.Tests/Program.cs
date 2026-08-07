using System.Reflection;
using System.Text;

var tests = new (string Name, Func<Task> Run)[]
{
    ("HTTP header reader splits body bytes received in the same read", HeaderReaderSplitsSameReadBodyAsync),
    ("HTTP request prefix writes same-read body upstream exactly once", RequestPrefixWritesSameReadBodyExactlyOnceAsync)
};

var failures = 0;
foreach (var (name, run) in tests)
{
    try
    {
        await run();
        Console.WriteLine($"PASS {name}");
    }
    catch (Exception exception)
    {
        failures++;
        Console.Error.WriteLine($"FAIL {name}: {exception.Message}");
    }
}

return failures == 0 ? 0 : 1;

static async Task HeaderReaderSplitsSameReadBodyAsync()
{
    const string header =
        "POST http://example.com/upload HTTP/1.1\r\n" +
        "Host: example.com\r\n" +
        "Content-Length: 5\r\n\r\n";
    const string body = "hello";
    var requestBytes = Encoding.ASCII.GetBytes(header + body);
    await using var source = new SingleReadStream(requestBytes);

    var result = await ReadRequestHeadAsync(source);

    var headerBytes = result.GetType().GetProperty("HeaderBytes")?.GetValue(result) as byte[];
    var remainder = result.GetType().GetProperty("Remainder")?.GetValue(result) as byte[];
    AssertSequence(Encoding.ASCII.GetBytes(header), headerBytes, "header");
    AssertSequence(Encoding.ASCII.GetBytes(body), remainder, "same-read body remainder");
    if (source.ReadCount != 1)
    {
        throw new InvalidOperationException(
            $"Expected the complete request prefix to be accepted after one read, got {source.ReadCount} reads.");
    }
}

static async Task RequestPrefixWritesSameReadBodyExactlyOnceAsync()
{
    const string request =
        "POST http://example.com/upload HTTP/1.1\r\n" +
        "Host: example.com\r\n" +
        "Content-Length: 5\r\n\r\n" +
        "hello";
    await using var source = new SingleReadStream(Encoding.ASCII.GetBytes(request));
    var requestHead = await ReadRequestHeadAsync(source);
    var writer = requestHead.GetType().GetMethod(
        "WriteToAsync",
        BindingFlags.Public | BindingFlags.Instance)
        ?? throw new InvalidOperationException("Request prefix has no upstream writer.");
    await using var upstream = new MemoryStream();
    var operation = (Task)(writer.Invoke(requestHead, [upstream, CancellationToken.None])
        ?? throw new InvalidOperationException("Request prefix writer did not return a task."));
    await operation;

    AssertSequence(
        Encoding.ASCII.GetBytes(request),
        upstream.ToArray(),
        "upstream request prefix");
}

static async Task<object> ReadRequestHeadAsync(Stream source)
{
    var programType = Assembly.Load("Astral.WebProxy")
        .GetTypes()
        .Single(type => type.Name == "Program");
    var reader = programType
        .GetMethods(BindingFlags.NonPublic | BindingFlags.Static)
        .Single(method => method.Name.Contains("ReadHeaderAsync", StringComparison.Ordinal));
    var operation = (Task)(reader.Invoke(null, [source, CancellationToken.None])
        ?? throw new InvalidOperationException("Header reader did not return a task."));
    await operation;
    return operation.GetType().GetProperty("Result")?.GetValue(operation)
        ?? throw new InvalidOperationException("Header reader returned no result.");
}

static void AssertSequence(byte[] expected, byte[]? actual, string label)
{
    if (actual is null || !actual.AsSpan().SequenceEqual(expected))
    {
        throw new InvalidOperationException($"Unexpected {label} bytes.");
    }
}

file sealed class SingleReadStream(byte[] bytes) : Stream
{
    private bool consumed;

    public int ReadCount { get; private set; }

    public override bool CanRead => true;
    public override bool CanSeek => false;
    public override bool CanWrite => false;
    public override long Length => throw new NotSupportedException();
    public override long Position
    {
        get => throw new NotSupportedException();
        set => throw new NotSupportedException();
    }

    public override int Read(byte[] buffer, int offset, int count) =>
        throw new NotSupportedException();

    public override ValueTask<int> ReadAsync(
        Memory<byte> buffer,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ReadCount++;
        if (consumed)
        {
            return ValueTask.FromResult(0);
        }

        consumed = true;
        bytes.CopyTo(buffer);
        return ValueTask.FromResult(bytes.Length);
    }

    public override void Flush() => throw new NotSupportedException();
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
    public override void SetLength(long value) => throw new NotSupportedException();
    public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
}
