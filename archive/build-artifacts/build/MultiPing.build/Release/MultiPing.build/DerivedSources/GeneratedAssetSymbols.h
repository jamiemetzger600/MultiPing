#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "icon_128x128" asset catalog image resource.
static NSString * const ACImageNameIcon128X128 AC_SWIFT_PRIVATE = @"icon_128x128";

/// The "icon_16x16" asset catalog image resource.
static NSString * const ACImageNameIcon16X16 AC_SWIFT_PRIVATE = @"icon_16x16";

/// The "icon_256x256" asset catalog image resource.
static NSString * const ACImageNameIcon256X256 AC_SWIFT_PRIVATE = @"icon_256x256";

/// The "icon_32x32" asset catalog image resource.
static NSString * const ACImageNameIcon32X32 AC_SWIFT_PRIVATE = @"icon_32x32";

/// The "icon_512x512" asset catalog image resource.
static NSString * const ACImageNameIcon512X512 AC_SWIFT_PRIVATE = @"icon_512x512";

#undef AC_SWIFT_PRIVATE
