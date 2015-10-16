//
//  KMLParser.h
//  LocateMe
//
//  Created by gdanikas on 14/10/15.
//  Copyright © 2015 George Danikas. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol KMLParserDelegate <NSObject>
@optional
- (void)parsingDidFinished:(NSError *)error;
@end

@import MapKit;

@class KMLPlacemark;
@class KMLStyle;

@interface KMLParser : NSObject  <NSXMLParserDelegate> {
    NSMutableArray *_placemarks;
    KMLPlacemark *_placemark;
    
    NSXMLParser *_xmlParser;
}

@property (unsafe_unretained, nonatomic, readonly) NSArray *countries;
@property (unsafe_unretained, nonatomic, readonly) NSArray *overlays;
@property (unsafe_unretained, nonatomic) NSString *filter;

@property (weak, nonatomic) id <KMLParserDelegate> delegate;

- (instancetype)initWithURL:(NSURL *)url;
- (void)parseKML;

- (MKOverlayPathRenderer *)rendererForOverlay:(id <MKOverlay>)overlay;

@end