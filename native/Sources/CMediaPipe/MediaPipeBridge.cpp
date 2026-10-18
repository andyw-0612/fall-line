#include "MediaPipeBridge.h"
#include "mediapipe/tasks/c/vision/hand_landmarker/hand_landmarker.h"
#include <dlfcn.h>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <climits>

// Use the unmodified 1.1.1 C ABI shipped in Google's macOS ARM64 wheel.
// Runtime loading keeps ordinary Swift builds/tests independent of downloaded assets.
struct MMHandTracker {
  void* library = nullptr;
  MpHandLandmarkerPtr hand = nullptr;
  decltype(&MpHandLandmarkerCreate) create = nullptr;
  decltype(&MpHandLandmarkerClose) close = nullptr;
  decltype(&MpHandLandmarkerDetectForVideo) detect = nullptr;
  decltype(&MpHandLandmarkerCloseResult) closeResult = nullptr;
  decltype(&MpImageCreateFromUint8Data) image = nullptr;
  decltype(&MpImageFree) freeImage = nullptr;
  int64_t lastTimestamp = -1;
};

template <typename T>
static bool symbol(void* library, const char* name, T& target, char** error) {
  target = reinterpret_cast<T>(dlsym(library, name));
  if (target) return true;
  if (error) *error = strdup(dlerror());
  return false;
}

MMHandTracker* MMCreateHandTracker(const char* library, const char* model, char** error) {
  auto* tracker = new MMHandTracker();
  tracker->library = dlopen(library, RTLD_NOW | RTLD_LOCAL | RTLD_NODELETE);
  if (!tracker->library) {
    if (error) *error = strdup(dlerror());
    delete tracker;
    return nullptr;
  }
  if (!symbol(tracker->library, "MpHandLandmarkerCreate", tracker->create, error) ||
      !symbol(tracker->library, "MpHandLandmarkerClose", tracker->close, error) ||
      !symbol(tracker->library, "MpHandLandmarkerDetectForVideo", tracker->detect, error) ||
      !symbol(tracker->library, "MpHandLandmarkerCloseResult", tracker->closeResult, error) ||
      !symbol(tracker->library, "MpImageCreateFromUint8Data", tracker->image, error) ||
      !symbol(tracker->library, "MpImageFree", tracker->freeImage, error)) {
    MMDestroyHandTracker(tracker);
    return nullptr;
  }
  MpHandLandmarkerOptions options{};
  options.base_options.model_asset_path = model;
  options.base_options.file_descriptor = -1;
  options.base_options.delegate = MP_DELEGATE_CPU;
  options.base_options.host_system = MP_HOST_SYSTEM_MAC;
  options.running_mode = MP_RUNNING_MODE_VIDEO;
  options.num_hands = 1;
  options.min_hand_detection_confidence = 0.6;
  options.min_hand_presence_confidence = 0.6;
  options.min_tracking_confidence = 0.5;
  if (tracker->create(&options, &tracker->hand, error) != 0) {
    MMDestroyHandTracker(tracker);
    return nullptr;
  }
  return tracker;
}

void MMDestroyHandTracker(MMHandTracker* tracker) {
  if (!tracker) return;
  if (tracker->hand && tracker->close) tracker->close(tracker->hand, nullptr);
  // MediaPipe owns process-wide calculator registrations and worker state.
  // Keep the module mapped for the process lifetime rather than unloading its code.
  if (tracker->library) dlclose(tracker->library);
  delete tracker;
}

int MMDetectHandLandmarks(MMHandTracker* tracker, const uint8_t* rgba, int width, int height,
                          int64_t timestamp, float* xyz, char** error) {
  if (!tracker || !rgba || !xyz || width <= 0 || height <= 0 ||
      int64_t(width) * height > INT_MAX / 4) {
    if (error) *error = strdup("Invalid MediaPipe input frame.");
    return -1;
  }
  timestamp = timestamp > tracker->lastTimestamp ? timestamp : tracker->lastTimestamp + 1;
  tracker->lastTimestamp = timestamp;
  MpImagePtr image = nullptr;
  if (tracker->image(kMpImageFormatSrgba, width, height, rgba, width * height * 4, &image, error) != 0) return -1;
  MpHandLandmarkerResult result{};
  auto status = tracker->detect(tracker->hand, image, nullptr, timestamp, &result, error);
  int found = status == 0 ? 0 : -1;
  if (status == 0 && result.hand_landmarks_count > 0 && result.hand_landmarks &&
      result.hand_landmarks[0].landmarks_count >= 21) {
    found = 21;
    for (int i = 0; i < 21; ++i) {
      const auto point = result.hand_landmarks[0].landmarks[i];
      if (!std::isfinite(point.x) || !std::isfinite(point.y) || !std::isfinite(point.z)) { found = 0; break; }
      xyz[i * 3] = point.x; xyz[i * 3 + 1] = point.y; xyz[i * 3 + 2] = point.z;
    }
  }
  tracker->closeResult(&result);
  tracker->freeImage(image);
  return found;
}

int MMDetectIndexTip(MMHandTracker* tracker, const uint8_t* rgba, int width, int height,
                     int64_t timestamp, float* x, float* y, char** error) {
  if (!x || !y) {
    if (error) *error = strdup("Missing index output coordinates.");
    return -1;
  }
  float xyz[63];
  int result = MMDetectHandLandmarks(tracker, rgba, width, height, timestamp, xyz, error);
  if (result <= 0) return result;
  constexpr int index = 8 * 3;
  if (xyz[index] < 0 || xyz[index] > 1 || xyz[index + 1] < 0 || xyz[index + 1] > 1) return 0;
  *x = xyz[index]; *y = xyz[index + 1];
  return 1;
}

void MMFreeError(char* error) { free(error); }
