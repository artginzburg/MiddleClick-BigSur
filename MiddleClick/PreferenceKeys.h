// The number of fingers needed to simulate a middle click.
#define kFingersNum @"fingers"
#define kFingersNumDefault 3

// Can be more than defined kFingersNum.
#define kAllowMoreFingers @"allowMoreFingers"
#define kAllowMoreFingersDefault false

// The maximum distance the cursor can travel between touch and release for a tap to be considered valid.
// The position is normalized and values go from 0 to 1.
#define kMaxDistanceDelta @"maxDistanceDelta"
#define kMaxDistanceDeltaDefault 0.05f

// The maximum interval in milliseconds between touch and release for a tap to be considered valid.
#define kMaxTimeDeltaMs @"maxTimeDelta"
#define kMaxTimeDeltaMsDefault 300

// List of applications that should be ignored
#define kIgnoredAppBundles @"ignoredAppBundles"
#define kIgnoredAppBundlesDefault [NSArray array]
