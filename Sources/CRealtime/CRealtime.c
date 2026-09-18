#include "CRealtime.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <math.h>

struct NTRing {
    float *left, *right;
    uint32_t capacity, mask;
    _Alignas(64) _Atomic uint64_t write;
    _Alignas(64) _Atomic uint64_t read;
    _Atomic uint64_t dropped, callbacks, invalid;
};

NTRing *nt_ring_create(uint32_t capacity) {
    if (capacity < 2 || (capacity & (capacity - 1))) return NULL;
    NTRing *r = NULL;
    if (posix_memalign((void **)&r, _Alignof(NTRing), sizeof(NTRing))) return NULL;
    r->left = calloc(capacity, sizeof(float));
    r->right = calloc(capacity, sizeof(float));
    if (!r->left || !r->right) { free(r->left); free(r->right); free(r); return NULL; }
    r->capacity = capacity; r->mask = capacity - 1;
    atomic_init(&r->write, 0); atomic_init(&r->read, 0);
    atomic_init(&r->dropped, 0); atomic_init(&r->callbacks, 0); atomic_init(&r->invalid, 0);
    return r;
}
void nt_ring_destroy(NTRing *r) { if (r) { free(r->left); free(r->right); free(r); } }
uint32_t nt_ring_write(NTRing *r, const float *l, const float *rr, uint32_t n, uint32_t stride) {
    uint64_t w = atomic_load_explicit(&r->write, memory_order_relaxed);
    uint64_t rd = atomic_load_explicit(&r->read, memory_order_acquire);
    // Drop a complete incoming block on overflow. Never overwrite data the consumer is reading.
    if (n > r->capacity - (w - rd)) { atomic_fetch_add_explicit(&r->dropped, n, memory_order_relaxed); return 0; }
    for (uint32_t i = 0; i < n; i++) {
        float a = l[i * stride], b = rr[i * stride];
        r->left[(w + i) & r->mask] = isfinite(a) ? a : 0;
        r->right[(w + i) & r->mask] = isfinite(b) ? b : 0;
    }
    atomic_store_explicit(&r->write, w + n, memory_order_release);
    return n;
}
uint32_t nt_ring_read(NTRing *r, float *l, float *rr, uint32_t capacity) {
    uint64_t rd = atomic_load_explicit(&r->read, memory_order_relaxed);
    uint64_t w = atomic_load_explicit(&r->write, memory_order_acquire);
    uint32_t n = (uint32_t)((w - rd < capacity) ? w - rd : capacity);
    for (uint32_t i = 0; i < n; i++) { l[i] = r->left[(rd + i) & r->mask]; rr[i] = r->right[(rd + i) & r->mask]; }
    atomic_store_explicit(&r->read, rd + n, memory_order_release);
    return n;
}
uint64_t nt_ring_dropped(const NTRing *r) { return atomic_load_explicit(&r->dropped, memory_order_relaxed); }
uint64_t nt_ring_callbacks(const NTRing *r) { return atomic_load_explicit(&r->callbacks, memory_order_relaxed); }
uint64_t nt_ring_invalid(const NTRing *r) { return atomic_load_explicit(&r->invalid, memory_order_relaxed); }
OSStatus nt_audio_callback(AudioObjectID device, const AudioTimeStamp *now,
    const AudioBufferList *in, const AudioTimeStamp *inTime,
    AudioBufferList *out, const AudioTimeStamp *outTime, void *context) {
    NTRing *r = context;
    atomic_fetch_add_explicit(&r->callbacks, 1, memory_order_relaxed);
    if (!in || !in->mNumberBuffers) return noErr;
    const AudioBuffer *a = &in->mBuffers[0];
    if (!a->mData || !a->mDataByteSize) return noErr;
    if (in->mNumberBuffers == 1 && a->mNumberChannels == 2 && a->mDataByteSize % 8 == 0) {
        nt_ring_write(r, a->mData, (float *)a->mData + 1, a->mDataByteSize / 8, 2);
    } else if (in->mNumberBuffers == 2 && a->mNumberChannels == 1) {
        const AudioBuffer *b = &in->mBuffers[1];
        if (b->mNumberChannels == 1 && b->mData && b->mDataByteSize == a->mDataByteSize && a->mDataByteSize % 4 == 0)
            nt_ring_write(r, a->mData, b->mData, a->mDataByteSize / 4, 1);
        else atomic_fetch_add_explicit(&r->invalid, 1, memory_order_relaxed);
    } else atomic_fetch_add_explicit(&r->invalid, 1, memory_order_relaxed);
    return noErr;
}
