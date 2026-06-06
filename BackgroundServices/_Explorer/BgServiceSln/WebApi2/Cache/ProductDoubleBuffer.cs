// Active/passive double buffer (a.k.a. ping-pong buffer):
// - Two slots hold product snapshots; one is "active" (served to HTTP readers), one is "passive" (written during refresh).
// - Refresh never mutates the active slot — it loads fresh data into passive, then flips which slot is active.
// - Readers always read the active slot, so they never block or wait while a refresh is in progress.
//
// Thread-safety split:
// - Volatile: safe handoff between one writer and many readers (index flip visibility).
// - Single writer: PublishPassiveSnapshot must not be called concurrently — enforced by _refreshLock in ProductCacheService.
public sealed class ProductDoubleBuffer
{
    private readonly IReadOnlyList<Product>?[] _buffers = [null, null];
    private int _activeIndex; // 0 or 1 — points at the slot readers should use.

    public IReadOnlyList<Product>? GetActiveSnapshot()
    {
        // Volatile.Read ensures this thread sees the latest _activeIndex written by another thread (the refresher).
        // Without it, the CPU/runtime could cache a stale index or reorder reads, and a reader might miss a swap.
        var index = Volatile.Read(ref _activeIndex);
        return _buffers[index];
    }

    public int PassiveIndex => 1 - Volatile.Read(ref _activeIndex);

    // Caller must hold the refresh lock — two concurrent writers would race on the same passive slot.
    // Volatile does not prevent that; it only makes a single swap visible to readers in the right order.
    public void PublishPassiveSnapshot(int passiveIndex, IReadOnlyList<Product> products)
    {
        // 1. Write the full new snapshot into the passive slot first.
        _buffers[passiveIndex] = products;

        // 2. Volatile.Write publishes the swap: passive becomes active.
        //    It acts as a memory fence — the buffer write above is visible before readers observe the new index.
        //    Readers therefore never see a new index pointing at a slot that is still being written.
        Volatile.Write(ref _activeIndex, passiveIndex);
    }
}
