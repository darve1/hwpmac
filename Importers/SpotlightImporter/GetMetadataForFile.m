// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>

#import "rhwp_native_ffi.h"

/// Spotlight indexes a bounded amount of text per file anyway.
static const NSUInteger MaxCharacters = 1000000;

/// Gives Spotlight the document text and page count, read by rhwp.
Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes,
                           CFStringRef contentTypeUTI, CFStringRef pathToFile) {
    @autoreleasepool {
        NSString *path = (__bridge NSString *)pathToFile;
        char *result = rhwp_read_text(path.fileSystemRepresentation, -1);
        if (result == NULL) {
            return FALSE;
        }
        NSData *data = [NSData dataWithBytes:result length:strlen(result)];
        rhwp_string_free(result);

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if (![json isKindOfClass:NSDictionary.class] || ![json[@"ok"] boolValue]) {
            return FALSE;
        }
        NSMutableString *text = [NSMutableString string];
        for (NSDictionary *page in json[@"pages"]) {
            NSString *pageText = [page isKindOfClass:NSDictionary.class] ? page[@"text"] : nil;
            if ([pageText isKindOfClass:NSString.class]) {
                [text appendString:pageText];
            }
            if (text.length >= MaxCharacters) {
                break;
            }
        }
        NSMutableDictionary *metadata = (__bridge NSMutableDictionary *)attributes;
        metadata[(__bridge NSString *)kMDItemTextContent] =
            text.length > MaxCharacters ? [text substringToIndex:MaxCharacters] : text;
        if ([json[@"pageCount"] isKindOfClass:NSNumber.class]) {
            metadata[(__bridge NSString *)kMDItemNumberOfPages] = json[@"pageCount"];
        }
        return TRUE;
    }
}
