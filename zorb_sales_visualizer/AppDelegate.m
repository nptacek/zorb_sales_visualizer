//
//  AppDelegate.m
//  zorb_sales_visualizer
//
//  Created by nptacek.eth on 6/23/22.
//

#import "AppDelegate.h"

#pragma mark - NSDictionary and NSArray Null Replacement Code
@implementation NSDictionary (NullReplacement)

- (NSDictionary *)dictionaryByReplacingNullsWithBlanks {
    const NSMutableDictionary *replaced = [self mutableCopy];
    const id nul = [NSNull null];
    const NSString *blank = @"";

    for (NSString *key in self) {
        id object = [self objectForKey:key];
        if (object == nul) [replaced setObject:blank forKey:key];
        else if ([object isKindOfClass:[NSDictionary class]]) [replaced setObject:[object dictionaryByReplacingNullsWithBlanks] forKey:key];
        else if ([object isKindOfClass:[NSArray class]]) [replaced setObject:[object arrayByReplacingNullsWithBlanks] forKey:key];
    }
    return [NSDictionary dictionaryWithDictionary:[replaced copy]];
}

@end

@implementation NSArray (NullReplacement)

- (NSArray *)arrayByReplacingNullsWithBlanks  {
    NSMutableArray *replaced = [self mutableCopy];
    const id nul = [NSNull null];
    const NSString *blank = @"";
    for (int idx = 0; idx < [replaced count]; idx++) {
        id object = [replaced objectAtIndex:idx];
        if (object == nul) [replaced replaceObjectAtIndex:idx withObject:blank];
        else if ([object isKindOfClass:[NSDictionary class]]) [replaced replaceObjectAtIndex:idx withObject:[object dictionaryByReplacingNullsWithBlanks]];
        else if ([object isKindOfClass:[NSArray class]]) [replaced replaceObjectAtIndex:idx withObject:[object arrayByReplacingNullsWithBlanks]];
    }
    return [replaced copy];
}

@end

@interface AppDelegate () <WKScriptMessageHandler>

@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [self getRecentZorbSales];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

#pragma mark - query Zora API for recent Zorb sales
- (void)getRecentZorbSales
{
    NSString *contractAddressString = @"0xca21d4228cdcc68d4e23807e5e370c07577dd152";
    NSString *tokenSalesQueryString = [NSString stringWithFormat:@"query GetZorbs ($contractAddress: String=\"%@\") {sales(where:{collectionAddresses:[$contractAddress]}, pagination:{ limit: 500}, sort:{sortKey: TIME, sortDirection: DESC}){ nodes { sale { tokenId transactionInfo { blockTimestamp } price { chainTokenPrice { decimal }}} token { metadata } }} }", contractAddressString];
    
    [self getDataForQuery:tokenSalesQueryString withCompletionHandler:^(NSDictionary *salesDataDict) {
        if (salesDataDict != nil) {
            NSMutableArray *mutSalesArray = [[NSMutableArray alloc] initWithCapacity:0];
            
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
            
      //      NSCalendar *gregorian = [[NSCalendar alloc]
      //                               initWithCalendarIdentifier:NSCalendarIdentifierGregorian];   //for alternate date handling method, see comment in function below
            
            for(NSDictionary *saleDict in [salesDataDict valueForKeyPath:@"data.sales.nodes"]){
                //we need to reformat the date string before passing it along to canvasJS
                NSString *saleDateString = [[saleDict valueForKeyPath:@"sale.transactionInfo"] objectForKey:@"blockTimestamp"];
                NSDate *saleDate = [formatter dateFromString:saleDateString];
                
                NSTimeInterval timestamp = [saleDate timeIntervalSince1970];
                NSString *timeStampString = [NSString stringWithFormat:@"%f", (timestamp * 1000)];
                
                //another way of handling the date conversion, if you go this route don't forget to remove 'xValueType: "dateTime",' from your canvasJS code
             /*   NSDateComponents *dateComponents =
                [gregorian components:(NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:saleDate];
                
                NSString *formatedSaleDateString = [NSString stringWithFormat:@"new Date(%ld, %ld, %ld)", (long)[dateComponents year], (long)[dateComponents month]-1, (long)[dateComponents day]]; //we're subtracting 1 from the month here due to the way canvasJS handles dates (https://canvasjs.com/forums/topic/minutedata-gives-monthissue/#post-4630)
            */
                
                //get the tokenId
                NSString *tokenIdString = [NSString stringWithString:[[saleDict valueForKeyPath:@"sale"] objectForKey:@"tokenId"]];
                
                //get the sales price in ETH
                NSString *salePriceETHString = [NSString stringWithFormat:@"%f", [[[saleDict valueForKeyPath:@"sale.price.chainTokenPrice"] objectForKey:@"decimal"] floatValue]];
                
                //get the base64-encoded image string and decode it so we can extract the HSL values for Zorb color
                NSString *imageString = [[saleDict valueForKeyPath:@"token.metadata"] objectForKey:@"image"];
                NSString *base64String = [imageString stringByReplacingOccurrencesOfString:@"data:image/svg+xml;base64," withString:@""];
                NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
                NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
                NSRange range = [decodedString rangeOfString:@"hsl(" options:NSBackwardsSearch];    //we're only interested in the last HSL value, so we'll start our pattern match from the end of the string
                if (range.location != NSNotFound) {
                    NSString *hslValue = [decodedString substringFromIndex:range.location];
                    NSArray *stringComponents = [hslValue componentsSeparatedByString:@"\""];   //split the string, we only care about the hsl value
                    
                    NSDictionary *saleDataPointDict = @{@"x" : timeStampString, @"y" : salePriceETHString, @"tokenId" : tokenIdString, @"markerColor" : [stringComponents objectAtIndex: 0]};
                    
                    [mutSalesArray addObject:saleDataPointDict];
                }
            }
            
            [self parseSalesWithData:[mutSalesArray copy]];
        }
    }];
}

#pragma mark - parse data returned by Zora API and hand off to canvasJS
- (void)parseSalesWithData:(NSArray *)salesArray
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:salesArray options:NSJSONWritingWithoutEscapingSlashes error:&error];
    
    //we need to manually fix some quote marks that got messed up as we serialized the string
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"scatter" withString:@"\"scatter\""];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"hsl(" withString:@"\"hsl("];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@")," withString:@")\","];
    
    //programmatically create the canvasJS template code utilizing our dataPoints, additionally includes a custom click: function to pass the tokenId back to obj-c code to extend functionality via userContentController:didReceiveScriptMessage:
    NSString *htmlString = [NSString stringWithFormat:@"<!DOCTYPE HTML><html><head><script>window.onload = function () {var chart = new CanvasJS.Chart(\"chartContainer\", {backgroundColor: \"black\", animationEnabled: true, title : {fontFamily:\"Inter\", text : \"Recent Zorb Sales\", fontColor: \"white\"},axisX:{labelFontFamily:\"Verdana\",labelFontColor:\"white\"},axisY:{labelFontFamily:\"Verdana\",labelFontColor:\"white\",suffix: \" Ξ\",includeZero: true},data: [{type : \"scatter\", toolTipContent: \"<b>Sale Date:</b> {x}<br><b>Price:</b> {y} ETH<br><b>Token ID:</b> {tokenId}\", xValueType : \"dateTime\", markerBorderColor:\"white\", markerBorderThickness: 0.5, click: function(e){window.webkit.messageHandlers.showTokenHandler.postMessage(e.dataPoint.tokenId);}, dataPoints : %@}]});chart.render();}</script></head><body><div id=\"chartContainer\" style=\"height: 100%%; width: 100%%;\"></div><script src=\"https://canvasjs.com/assets/script/canvasjs.min.js\"></script></body></html>", jsonString];
    
    //register for our click message handler and then load our custom scatter chart as an html string in our web view
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.salesWebView.configuration.userContentController addScriptMessageHandler:self name:@"showTokenHandler"];
        [self.salesWebView loadHTMLString:htmlString baseURL:[NSBundle mainBundle].bundleURL];
    });
}

#pragma mark - code to handle clicking on individual Zorb sales
- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message
{
    //handle clicks on individual zorb sales
    if([message.name isEqualToString:@"showTokenHandler"]) {
        //the metadata for https://zorb.dev/nft/ doesn't seem to be up-to-date, so we're going to link to OpenSea instead. if the zorb color doesn't match what you were expecting to see, try refreshing it's metadata on OpenSea
        NSURL *url = [[NSURL alloc] initWithString: [NSString stringWithFormat:@"https://opensea.io/assets/ethereum/0xca21d4228cdcc68d4e23807e5e370c07577dd152/%@", message.body]];
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

#pragma mark - code to communicate with ZORA API
- (void)getDataForQuery:(NSString *)queryString withCompletionHandler:(void (^)(NSDictionary *responseDataDict))completionHandler
{
    // serialize our graphql query string to json and store it as nsdata
    NSDictionary *jsonStringDict = @{
        @"query": queryString
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonStringDict options:NSJSONWritingFragmentsAllowed error:&error];
 
    // create URL request, set up the headers, and set the body to our graphql query
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.zora.co/graphql"]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:60.0];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;

    // initiatialize the session and data task
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *taskError) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response; //DEBUG CODE
    //    NSLog(@"response status code: %ld", (long)httpResponse.statusCode);   //DEBUG CODE
        if (taskError) {
          // data task encountered an error
            NSLog(@"getDataForQuery task error: %@", taskError);
            completionHandler(nil); //return nil so we can handle the error in ther UI
        }
        else if(httpResponse.statusCode == 502){
            NSLog(@"Status code 502, try again later!");
        }
        else if(httpResponse.statusCode == 429){
            NSLog(@"Status code 429, try again later!");
        }
        else {
            //  we got data back, let's extract the json response from it
                NSError *jsonError;
                NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if (jsonError) {
                    // encountered an error parsing json
                    NSLog(@"getDataFrom jsonError: %@", jsonError);
                    completionHandler(nil); //return nil so we can handle the error in ther UI
                } else {
                    // successfully parsed json response
                    NSDictionary *jsonResponseDict = [jsonResponse dictionaryByReplacingNullsWithBlanks]; //  strip NSNulls from the json output, otherwise it won't play well with obj-c later on for core data stuff
                    completionHandler(jsonResponseDict);    //  return the stripped json response dict for further parsing by app
                }
        }
      }];

    [dataTask resume];  //  start the data query task asynchronously
}

@end
