/*
    Modified Apple sample code, taken from https://developer.apple.com/library/ios/#samplecode/KMLViewer/Introduction/Intro.html
    Version: 3.0

    IMPORTANT:  This Apple software is supplied to you by Apple
    Inc. ("Apple") in consideration of your agreement to the following
    terms, and your use, installation, modification or redistribution of
    this Apple software constitutes acceptance of these terms.  If you do
    not agree with these terms, please do not use, install, modify or
    redistribute this Apple software.

    In consideration of your agreement to abide by the following terms, and
    subject to these terms, Apple grants you a personal, non-exclusive
    license, under Apple's copyrights in this original Apple software (the
    "Apple Software"), to use, reproduce, modify and redistribute the Apple
    Software, with or without modifications, in source and/or binary forms;
    provided that if you redistribute the Apple Software in its entirety and
    without modifications, you must retain this notice and the following
    text and disclaimers in all such redistributions of the Apple Software.
    Neither the name, trademarks, service marks or logos of Apple Inc. may
    be used to endorse or promote products derived from the Apple Software
    without specific prior written permission from Apple.  Except as
    expressly stated in this notice, no other rights or licenses, express or
    implied, are granted by Apple herein, including but not limited to any
    patent rights that may be infringed by your derivative works or by other
    works in which the Apple Software may be incorporated.

    The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
    MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
    THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
    OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

    IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
    MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
    AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
    STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.

    Copyright (C) 2015 Apple Inc. All Rights Reserved.
*/

#import "KMLParser.h"
#import <UIKit/UIKit.h>

#define ELTYPE(typeName) (NSOrderedSame == [elementName caseInsensitiveCompare:@#typeName])

// Convert a KML coordinate list string to a C array of CLLocationCoordinate2Ds.
// KML coordinate lists are longitude,latitude[,altitude] tuples specified by whitespace.
static void strToCoords(NSString *str, CLLocationCoordinate2D **coordsOut, NSUInteger *coordsLenOut) {
    NSUInteger read = 0, space = 10;
    CLLocationCoordinate2D *coords = malloc(sizeof(CLLocationCoordinate2D) * space);
    
    NSArray *tuples = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString *tuple in tuples) {
        if (read == space) {
            space *= 2;
            coords = realloc(coords, sizeof(CLLocationCoordinate2D) * space);
        }
        
        double lat = 0.0, lon;
        NSScanner *scanner = [[NSScanner alloc] initWithString:tuple];
        [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@","]];
        BOOL success = [scanner scanDouble:&lon];
        if (success)
            success = [scanner scanDouble:&lat];
        if (success) {
            CLLocationCoordinate2D c = CLLocationCoordinate2DMake(lat, lon);
            if (CLLocationCoordinate2DIsValid(c))
                coords[read++] = c;
        }
    }
    
    *coordsOut = coords;
    *coordsLenOut = read;
}

// -- KMLElement --
@interface KMLElement : NSObject {
    NSMutableString *accum;
}

// Returns YES if we're currently parsing an element that has character
// data contents that we are interested in saving.
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL canAddString;

// Add character data parsed from the xml
- (void)addString:(NSString *)str;

// Once the character data for an element has been parsed, use clearString to
// reset the character buffer to get ready to parse another element.
- (void)clearString;

@end

@implementation KMLElement

- (BOOL)canAddString {
    return NO;
}

- (void)addString:(NSString *)str {
    if ([self canAddString]) {
        if (!accum) {
            accum = [[NSMutableString alloc] init];
        }
        
        [accum appendString:str];
    }
}

- (void)clearString {
    accum = nil;
}

@end

// -- KMLStyle --
@interface KMLStyle : KMLElement {
    UIColor *fillColor;
    
    struct {
        int inPolyStyle:1;
        int inColor:1;
    } flags;
}

- (void)beginPolyStyle;
- (void)endPolyStyle;

- (void)beginColor;
- (void)endColor;

- (void)applyToOverlayPathRenderer:(MKOverlayPathRenderer *)renderer;

@end

@implementation KMLStyle

- (BOOL)canAddString {
    return flags.inColor;
}

- (void)beginPolyStyle {
    flags.inPolyStyle = YES;
}

- (void)endPolyStyle {
    flags.inPolyStyle = NO;
}

- (void)beginColor {
    flags.inColor = YES;
}

- (void)endColor {
    flags.inColor = NO;
    
    fillColor = [self colorWithKMLString:accum];
    [self clearString];
}


- (void)applyToOverlayPathRenderer:(MKOverlayPathRenderer *)renderer {
    renderer.strokeColor = fillColor;
}

- (UIColor *)colorWithKMLString:(NSString *)kmlColorString {
    NSScanner *scanner = [[NSScanner alloc] initWithString:kmlColorString];
    unsigned color = 0;
    [scanner scanHexInt:&color];
    
    unsigned b = (color >> 16) & 0x000000FF;
    unsigned g = (color >> 8) & 0x000000FF;
    unsigned r = color & 0x000000FF;
    
    return [UIColor colorWithRed:r / 255.0f
                           green:g / 255.0f
                            blue:b / 255.0f
                           alpha:1.0f];
}

@end


// -- KMLPlacemark --
@interface KMLGeometry : KMLElement {
    struct {
        int inCoords:1;
    } flags;
}

- (void)beginCoordinates;
- (void)endCoordinates;

// Create (if necessary) and return the corresponding Map Kit MKShape object
// corresponding to this KML Geometry node.
@property (NS_NONATOMIC_IOSONLY, readonly, strong) MKShape *mapkitShape;

// Create (if necessary) and return the corresponding MKOverlayPathRenderer for
// the MKShape object.
- (MKOverlayPathRenderer *)createOverlayPathRenderer:(MKShape *)shape;

@end

@implementation KMLGeometry

- (BOOL)canAddString {
    return flags.inCoords;
}

- (void)beginCoordinates {
    flags.inCoords = YES;
}

- (void)endCoordinates {
    flags.inCoords = NO;
}

- (MKShape *)mapkitShape {
    return nil;
}

- (MKOverlayPathRenderer *)createOverlayPathRenderer:(MKShape *)shape {
    return nil;
}

@end

// -- KMLPolygon --
@interface KMLPolygon : KMLGeometry {
    NSString *outerRing;
    NSMutableArray *innerRings;
    
    MKShape *mkShape;
    
    struct {
        int inOuterBoundary:1;
        int inInnerBoundary:1;
        int inLinearRing:1;
    } polyFlags;
}

@property (nonatomic, readonly) MKShape *mkShape;

- (void)beginOuterBoundary;
- (void)endOuterBoundary;

- (void)beginInnerBoundary;
- (void)endInnerBoundary;

- (void)beginLinearRing;
- (void)endLinearRing;

@end

@implementation KMLPolygon

@synthesize mkShape;

- (BOOL)canAddString {
    return polyFlags.inLinearRing && flags.inCoords;
}

- (void)beginOuterBoundary {
    polyFlags.inOuterBoundary = YES;
}

- (void)endOuterBoundary {
    polyFlags.inOuterBoundary = NO;
    outerRing = [accum copy];
    
    [self clearString];
}

- (void)beginInnerBoundary {
    polyFlags.inInnerBoundary = YES;
}

- (void)endInnerBoundary {
    polyFlags.inInnerBoundary = NO;
    NSString *ring = [accum copy];
    if (!innerRings) {
        innerRings = [[NSMutableArray alloc] init];
    }
    [innerRings addObject:ring];

    [self clearString];
}

- (void)beginLinearRing {
    polyFlags.inLinearRing = YES;
}

- (void)endLinearRing {
    polyFlags.inLinearRing = NO;
}

- (MKShape *)mapkitShape {
    // KMLPolygon corresponds to MKPolygon
    
    // The inner and outer rings of the polygon are stored as kml coordinate
    // list strings until we're asked for mapkitShape.  Only once we're here
    // do we lazily transform them into CLLocationCoordinate2D arrays.
    
    // First build up a list of MKPolygon cutouts for the interior rings.
    NSMutableArray *innerPolys = nil;
    if (innerRings) {
        innerPolys = [[NSMutableArray alloc] initWithCapacity:[innerPolys count]];
        for (NSString *coordStr in innerRings) {
            CLLocationCoordinate2D *coords = NULL;
            NSUInteger coordsLen = 0;
            strToCoords(coordStr, &coords, &coordsLen);
            [innerPolys addObject:[MKPolygon polygonWithCoordinates:coords count:coordsLen]];
            free(coords);
        }
    }
    // Now parse the outer ring.
    CLLocationCoordinate2D *coords = NULL;
    NSUInteger coordsLen = 0;
    strToCoords(outerRing, &coords, &coordsLen);
    
    // Build a polygon using both the outer coordinates and the list (if applicable)
    // of interior polygons parsed.
    MKPolygon *poly = [MKPolygon polygonWithCoordinates:coords count:coordsLen interiorPolygons:innerPolys];
    free(coords);
    
    mkShape = poly;
    return mkShape;
}

- (MKOverlayPathRenderer *)createOverlayPathRenderer:(MKShape *)shape {
    MKPolygonRenderer *polyPath = [[MKPolygonRenderer alloc] initWithPolygon:(MKPolygon *)shape];
    return polyPath;
}

@end


// -- KMLPlacemark --
@interface KMLPlacemark : KMLElement {
    NSString *name;
    NSString *placemarkDescription;
    
    KMLStyle *style;
    KMLGeometry *singleGeometry;
    
    NSMutableArray *geometries;
    
    struct {
        int inName:1;
        int inDescription:1;
        int inStyle:1;
        int inGeometry:1;
        int inMultiGeometry:1;
    } flags;
}

- (void)beginName;
- (void)endName;

- (void)beginDescription;
- (void)endDescription;

- (void)beginStyle;
- (void)endStyle;

- (void)beginGeometryOfType:(NSString *)type;
- (void)endGeometry;

- (void)beginMultiGeometry;
- (void)endMultiGeometry;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *placemarkDescription;
@property (nonatomic, strong) KMLStyle *style;

@property (nonatomic, readonly) KMLGeometry *singleGeometry;
@property (unsafe_unretained, nonatomic, readonly) KMLPolygon *polygon;

@property (nonatomic, readonly) NSMutableArray *geometries;

- (id <MKOverlay>)createShapeForGeometry:(KMLGeometry *)geometry;

@end

@implementation KMLPlacemark

@synthesize name, placemarkDescription, style, singleGeometry, geometries;

- (BOOL)canAddString {
    return flags.inName || flags.inDescription;
}

- (void)addString:(NSString *)str {
    if (flags.inStyle) {
        [style addString:str];
    } else if (flags.inGeometry) {
        [singleGeometry addString:str];
    } else {
        [super addString:str];
    }
}

- (void)beginName {
    flags.inName = YES;
}

- (void)endName {
    flags.inName = NO;
    name = [accum copy];
    
    [self clearString];
}

- (void)beginDescription {
    flags.inDescription = YES;
}

- (void)endDescription {
    flags.inDescription = NO;
    placemarkDescription = [accum copy];
    
    [self clearString];
}

- (void)beginStyle {
    flags.inStyle = YES;
    style = [[KMLStyle alloc] init];
}

- (void)endStyle {
    flags.inStyle = NO;
}

- (void)beginGeometryOfType:(NSString *)elementName {
    flags.inGeometry = YES;
    if (ELTYPE(Polygon)) {
        singleGeometry = [[KMLPolygon alloc] init];
        
        if (flags.inMultiGeometry) {
            if (geometries == nil) {
                geometries = [[NSMutableArray alloc] init];
            }
        }
    }
}

- (void)endGeometry {
    flags.inGeometry = NO;
    
    if (flags.inMultiGeometry)
        [geometries addObject:singleGeometry];
}

-(void)beginMultiGeometry {
    flags.inMultiGeometry = YES;
}

-(void)endMultiGeometry {
    flags.inMultiGeometry = NO;
    singleGeometry = nil;
}

- (KMLGeometry *)geometry {
    return singleGeometry;
}

- (KMLPolygon *)polygon {
    return [singleGeometry isKindOfClass:[KMLPolygon class]] ? (id)singleGeometry : nil;
}

- (id <MKOverlay>)createShapeForGeometry:(KMLGeometry *)geometry {
    KMLPolygon *polygon = (KMLPolygon *)geometry;
    if (!polygon.mkShape) {
        MKShape *tmpShape = [polygon mapkitShape];
        if (([tmpShape conformsToProtocol:@protocol(MKOverlay)])) {
            tmpShape.title = name;
            
            return (id <MKOverlay>)tmpShape;
        }
    }
    
    return (id <MKOverlay>)polygon.mkShape;
}

@end

@implementation KMLParser

- (instancetype)initWithURL:(NSURL *)url {
    if (self = [super init]) {
        _xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:url];
        [_xmlParser setDelegate:self];
        
        _placemarks = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)parseKML {
    [_xmlParser parse];
}

- (NSArray *)countries {
    NSMutableArray *countries = [[NSMutableArray alloc] init];
    for (KMLPlacemark *placemark in _placemarks) {
        [countries addObject:placemark.name];
    }
    
    return countries;
}

// Return the list of KMLPlacemarks from the object graph that contain overlays
// (as opposed to simply point annotations).
- (NSArray *)overlays {
    NSArray *filteredPlacemarks = _placemarks;
    
    if (self.filter && self.filter.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", self.filter];
        filteredPlacemarks = [_placemarks filteredArrayUsingPredicate:predicate];
    }
    
    NSMutableArray *overlays = [[NSMutableArray alloc] init];
    for (KMLPlacemark *placemark in filteredPlacemarks) {
        // If placemark has multi geometry
        for (KMLPolygon *geometry in placemark.geometries) {
            id <MKOverlay> overlay = [placemark createShapeForGeometry:geometry];
            if (overlay)
                [overlays addObject:overlay];
        }
        
        // If placemark has single geometry
        if (placemark.geometry) {
            id <MKOverlay> overlay = [placemark createShapeForGeometry:placemark.geometry];
            if (overlay)
                [overlays addObject:overlay];
        }
    }
    
    return overlays;
}

- (MKOverlayPathRenderer *)rendererForOverlay:(id <MKOverlay>)overlay {
    NSArray *filteredPlacemarks = _placemarks;
    
    if (self.filter && self.filter.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", self.filter];
        filteredPlacemarks = [_placemarks filteredArrayUsingPredicate:predicate];
    }
    
    // Find the KMLPlacemark object that owns this overlay and get
    // the view from it.
    for (KMLPlacemark *placemark in filteredPlacemarks) {
        // If placemark has multi geometry
        for (KMLPolygon *geometry in placemark.geometries) {
            id <MKOverlay> placemarkOverlay = [placemark createShapeForGeometry:geometry];
            if (placemarkOverlay == overlay) {
                MKOverlayPathRenderer *overlayPathRenderer = [geometry createOverlayPathRenderer:placemarkOverlay];
                [placemark.style applyToOverlayPathRenderer:overlayPathRenderer];
                
                return overlayPathRenderer;
            }
        }
        
        // If placemark has single geometry
        if (placemark.geometry) {
            id <MKOverlay> placemarkOverlay = [placemark createShapeForGeometry:placemark.geometry];
            if (placemarkOverlay == overlay) {
                MKOverlayPathRenderer *overlayPathRenderer = [placemark.geometry createOverlayPathRenderer:placemarkOverlay];
                [placemark.style applyToOverlayPathRenderer:overlayPathRenderer];
                
                return overlayPathRenderer;
            }
        }
    }
    
    return nil;
}

#pragma mark NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(nonnull NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName attributes:(nonnull NSDictionary<NSString *,NSString *> *)attributeDict {

    // Placemark and sub-elements
    if (ELTYPE(Placemark)) {
        _placemark = [[KMLPlacemark alloc] init];
    } else if (ELTYPE(Name)) {
        [_placemark beginName];
    } else if (ELTYPE(Description)) {
        [_placemark beginDescription];
    }
    
    else if (_placemark) {
        // Style and sub-elements
        if (ELTYPE(Style)) {
            [_placemark beginStyle];
        } else if (ELTYPE(PolyStyle)) {
            [[_placemark style] beginPolyStyle];
        } else if (ELTYPE(color)) {
            [[_placemark style] beginColor];
        }
        
        else if (ELTYPE(MultiGeometry)){
            [_placemark beginMultiGeometry];
        }
        else if (ELTYPE(Polygon)) {
            [_placemark beginGeometryOfType:elementName];
        }
        
        else if (_placemark.polygon) {
            // Polygon sub-elements
            if (ELTYPE(outerBoundaryIs)) {
                [_placemark.polygon beginOuterBoundary];
            } else if (ELTYPE(innerBoundaryIs)) {
                [_placemark.polygon beginInnerBoundary];
            } else if (ELTYPE(LinearRing)) {
                [_placemark.polygon beginLinearRing];
            }
            
            // Geometry sub-elements
            else if (ELTYPE(coordinates)) {
                [_placemark.geometry beginCoordinates];
            }
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(nonnull NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName {

    // Placemark and sub-elements
    if (ELTYPE(Placemark)) {
        if (_placemark) {
            [_placemarks addObject:_placemark];
            _placemark = nil;
        }
    } else if (ELTYPE(Name)) {
        [_placemark endName];
    } else if (ELTYPE(Description)) {
        [_placemark endDescription];
    }
    
    else if (_placemark) {
        // Style and sub-elements
        if (ELTYPE(Style)) {
            [_placemark endStyle];
        } else if (ELTYPE(PolyStyle)) {
            [[_placemark style] endPolyStyle];
        } else if (ELTYPE(color)) {
            [[_placemark style] endColor];
        }
        
        else if (ELTYPE(MultiGeometry)) {
            [_placemark endMultiGeometry];
        }
        else if (ELTYPE(Polygon)) {
            [_placemark endGeometry];
        }
        
        else if (_placemark.polygon) {
            // Polygon sub-elements
            if (ELTYPE(outerBoundaryIs)) {
                [_placemark.polygon endOuterBoundary];
            } else if (ELTYPE(innerBoundaryIs)) {
                [_placemark.polygon endInnerBoundary];
            } else if (ELTYPE(LinearRing)) {
                [_placemark.polygon endLinearRing];
            }
            
            // Geometry sub-elements
            else if (ELTYPE(coordinates)) {
                [_placemark.geometry endCoordinates];
            }
        }
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [_placemark addString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    NSLog(@"KML parsing finished");
    
    if ([self.delegate respondsToSelector:@selector(parsingDidFinished:)])
        [self.delegate parsingDidFinished:nil];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    NSLog(@"KML parsing finished with error: %@", parseError.localizedDescription);
    
    if ([self.delegate respondsToSelector:@selector(parsingDidFinished:)])
        [self.delegate parsingDidFinished:parseError];
}

@end