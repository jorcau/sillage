#pragma once
#include <CoreAudio/CoreAudio.h>
#include <stdint.h>
#include <stddef.h>

typedef struct NTRing NTRing;
// One producer (HAL callback), one consumer (analysis queue). No locks or allocation in IO.
NTRing * _Nullable nt_ring_create(uint32_t capacity);
void nt_ring_destroy(NTRing * _Nullable ring);
uint32_t nt_ring_write(NTRing * _Nonnull ring, const float * _Nonnull left, const float * _Nonnull right, uint32_t count, uint32_t stride);
uint32_t nt_ring_read(NTRing * _Nonnull ring, float * _Nonnull left, float * _Nonnull right, uint32_t capacity);
uint64_t nt_ring_dropped(const NTRing * _Nonnull ring);
uint64_t nt_ring_callbacks(const NTRing * _Nonnull ring);
uint64_t nt_ring_invalid(const NTRing * _Nonnull ring);
OSStatus nt_audio_callback(AudioObjectID device, const AudioTimeStamp * _Nonnull now,
    const AudioBufferList * _Nonnull input, const AudioTimeStamp * _Nonnull inputTime,
    AudioBufferList * _Nonnull output, const AudioTimeStamp * _Nonnull outputTime, void * _Nullable context);
