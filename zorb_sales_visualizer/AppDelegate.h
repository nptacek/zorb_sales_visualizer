//
//  AppDelegate.h
//  zorb_sales_visualizer
//
//  Created by nptacek.eth on 6/23/22.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface NSDictionary (NullReplacement)

- (NSDictionary *)dictionaryByReplacingNullsWithBlanks;

@end

@interface NSArray (NullReplacement)

- (NSArray *)arrayByReplacingNullsWithBlanks;

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak, nonatomic) IBOutlet WKWebView *salesWebView;

@end

