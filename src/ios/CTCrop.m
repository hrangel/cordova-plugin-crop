#import "CTCrop.h"

#define CDV_PHOTO_PREFIX @"cdv_photo_"

@interface CTCrop ()
@property (copy) NSString* callbackId;
@property (assign) NSUInteger quality;
@end

@implementation CTCrop

- (void) cropImage: (CDVInvokedUrlCommand *) command {
    UIImage *image;
    NSString *imagePath = [command.arguments objectAtIndex:0];
    NSDictionary *options = [command.arguments objectAtIndex:1];
    id quality = options[@"quality"] ?: @100;
    id idTargetWidth = options[@"targetWidth"] ?: @0;
    id idTargetHeight = options[@"targetHeight"] ?: @0;
    CGFloat targetWidth = (CGFloat) [idTargetWidth unsignedIntegerValue];
    CGFloat targetHeight = (CGFloat) [idTargetHeight unsignedIntegerValue];
    
    self.quality = [quality unsignedIntegerValue];
    NSString *filePrefix = @"file://";
    
    if ([imagePath hasPrefix:filePrefix]) {
        imagePath = [imagePath substringFromIndex:[filePrefix length]];
    }
    
    
    if (!(image = [UIImage imageWithContentsOfFile:imagePath])) {
        NSDictionary *err = @{
                              @"message": @"Image doesn't exist",
                              @"code": @"ENOENT"
                              };
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:err];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    PECropViewController *cropController = [[PECropViewController alloc] init];
    cropController.delegate = self;
    cropController.image = image;
    
    // e.g.) Cropping center square
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    CGFloat length = MIN(width, height);
    if (targetWidth <= 0 || targetWidth > width) {
        targetWidth = length;
    }
    if (targetHeight <= 0 || targetHeight > height) {
        targetHeight = length;
    }

    cropController.toolbarHidden = YES;
    cropController.rotationEnabled = NO;
    cropController.keepingCropAspectRatio = YES;
    
    // TODO parameterize this
    cropController.imageCropRect = CGRectMake(0,
                                          0,
                                          targetWidth,
                                          targetHeight);
    
    self.callbackId = command.callbackId;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:cropController];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [self.viewController presentViewController:navigationController animated:YES completion:NULL];
}

#pragma mark - PECropViewControllerDelegate

- (void)cropViewController:(PECropViewController *)controller didFinishCroppingImage:(UIImage *)croppedImage {
    [controller dismissViewControllerAnimated:YES completion:nil];
    if (!self.callbackId) return;
    
    NSData *data = UIImageJPEGRepresentation(croppedImage, (CGFloat) self.quality);
    NSString* filePath = [self tempFilePath:@"jpg"];
    CDVPluginResult *result;
    NSError *err;
    
    // save file
    if (![data writeToFile:filePath options:NSAtomicWrite error:&err]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[err localizedDescription]];
    }
    else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[NSURL fileURLWithPath:filePath] absoluteString]];
    }
    
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
    self.callbackId = nil;
}

- (void)cropViewControllerDidCancel:(PECropViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
    NSDictionary *err = @{
                          @"message": @"User cancelled",
                          @"code": @"userCancelled"
                          };
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:err];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    self.callbackId = nil;
}

#pragma mark - Utilites

- (NSString*)tempFilePath:(NSString*)extension
{
    NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];
    NSFileManager* fileMgr = [[NSFileManager alloc] init]; // recommended by Apple (vs [NSFileManager defaultManager]) to be threadsafe
    NSString* filePath;
    
    // generate unique file name
    int i = 1;
    do {
        filePath = [NSString stringWithFormat:@"%@/%@%03d.%@", docsPath, CDV_PHOTO_PREFIX, i++, extension];
    } while ([fileMgr fileExistsAtPath:filePath]);
    
    return filePath;
}

@end
