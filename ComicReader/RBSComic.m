//
//  RBSComic.m
//  ComicReader
//
//  Created by Łukasz Adamczak on 4.06.2013.
//  Copyright (c) 2013 Rebased s.c. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import <MWPhotoBrowser.h>
#import <zipzap.h>
#import <NSArray+BlocksKit.h>
#import <RXMLElement.h>
#import "RBSComic.h"

@interface RBSComic ()
@property ZZArchive *archive;
@property RXMLElement *metadata;
@property (readonly) NSArray *pages;

- (RXMLElement *)loadMetadata;
@end

@implementation RBSComic

@synthesize archive = _archive;
@synthesize metadata = _metadata;
@synthesize pages = _pages;

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        self.archive = [ZZArchive archiveWithContentsOfURL:url];
        self.metadata = [self loadMetadata];
    }
    return self;
}

- (NSArray *)pages
{
    if (_pages == nil) {
        // Pages are ZZArchiveEntry objects which represent image files
        _pages = [self.archive.entries select:^BOOL(ZZArchiveEntry *entry) {
            CFStringRef fileExtension = (__bridge CFStringRef) entry.fileName.pathExtension;
            CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
            return (UTTypeConformsTo(fileUTI, kUTTypeImage));
        }];
    }
    return _pages;
}

- (NSString *)title
{
    if (self.metadata) {
        return [self.metadata attribute:@"title"];
    }
    else {
        return self.archive.URL.lastPathComponent;
    }    
}

- (NSInteger)numPages
{
    return self.pages.count;
}

- (MWPhoto *)pageAtIndex:(NSInteger)index
{
    if (index >= self.numPages)
        return nil;
    
    ZZArchiveEntry *entry = self.pages[index];
    UIImage *pageImage = [UIImage imageWithData:entry.data];
    
    MWPhoto *photo = [MWPhoto photoWithImage:pageImage];
    photo.caption = self.title;
    
    return photo;
}

#pragma mark Private methods

- (RXMLElement *)loadMetadata
{
    ZZArchiveEntry *entry = [[self.archive.entries select:^BOOL(ZZArchiveEntry *e) {
        return [e.fileName isEqualToString:@"comic.xml"];
    }] lastObject];
    
    if (entry == nil) {
        return nil;
    }
    else {
        return [RXMLElement elementFromXMLData:entry.data];
    }
}

@end
