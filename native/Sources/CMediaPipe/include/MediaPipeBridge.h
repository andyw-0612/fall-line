#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MMHandTracker MMHandTracker;
// Errors are caller-owned; release with MMFreeError. Instances are serial-use only.
MMHandTracker* MMCreateHandTracker(const char* library, const char* model, char** error);
void MMDestroyHandTracker(MMHandTracker* tracker);
// Packed RGBA, top-left origin. Returns 1 for index tip, 0 for no hand, -1 for error.
int MMDetectIndexTip(MMHandTracker* tracker, const uint8_t* rgba, int width, int height,
                     int64_t timestamp, float* x, float* y, char** error);
// Writes 21 normalized xyz landmarks (63 floats). Returns 21, 0, or -1.
int MMDetectHandLandmarks(MMHandTracker* tracker, const uint8_t* rgba, int width, int height,
                          int64_t timestamp, float* xyz, char** error);
void MMFreeError(char* error);

#ifdef __cplusplus
}
#endif
