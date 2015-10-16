//
//  MyLocationViewController.m
//  LocateMe
//
//  Created by gdanikas on 13/10/15.
//  Copyright © 2015 George Danikas. All rights reserved.
//

#import "MyLocationViewController.h"
#import <MapKit/MapKit.h>
#import "KMLParser.h"
#import "SelectCountryViewController.h"

@interface MyLocationViewController () <MKMapViewDelegate, CLLocationManagerDelegate, KMLParserDelegate, SelectCountryDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIView *overlayView;
@property (weak, nonatomic) IBOutlet UILabel *currentCountryLbl;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *overlayViewTopConstr;

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) KMLParser *kmlParser;
@property (nonatomic) NSArray *overlays;
@property (nonatomic) NSString *currentCountry;
@property (nonatomic) UIBarButtonItem *settingsBtn;
@property (nonatomic) MKMapRect visibleMapRect;

@end

@implementation MyLocationViewController {
    BOOL _firstInitialization;
    BOOL _kmlIsParsed;
    BOOL _currentCountryChanged;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Reset flags
    _firstInitialization = _kmlIsParsed = _currentCountryChanged = NO;
    
    // Set initial positions for overlay view
    self.overlayViewTopConstr.constant = -self.overlayView.bounds.size.height;
    
    // Set buttons
    self.settingsBtn = self.navigationItem.rightBarButtonItem;
    
    // Show activity indicator while parsing KML file
    [self showActivityIndicator];
    
    // Initialize visible map rect
    self.visibleMapRect = MKMapRectNull;
    
    // Locate the path to the world-stripped.kml file in the application's bundle and parse it with the KMLParser
    NSString *path = [[NSBundle mainBundle] pathForResource:@"world-stripped" ofType:@"kml"];
    if (path) {
        NSURL *url = [NSURL fileURLWithPath:path];
        self.kmlParser = [[KMLParser alloc] initWithURL:url];
        self.kmlParser.delegate = self;
        
        // Parse KML file in a background thread
        [[NSOperationQueue new] addOperationWithBlock:^{
            [self.kmlParser parseKML];
        }];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_kmlIsParsed && _currentCountryChanged) {
        [self processKMLData];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!_firstInitialization)
        _firstInitialization = YES;
    
    if (_kmlIsParsed && _currentCountryChanged) {
        [self performSelector:@selector(zoomMap) withObject:nil afterDelay:0.2f];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)processKMLData {
    // Remove existing overlays
    [self.mapView removeOverlays:self.mapView.overlays];
    
    // Check if user has a selected country
    self.currentCountry = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentCountry"];
    if (self.currentCountry) {
        self.currentCountryLbl.text = self.currentCountry;
        [self.kmlParser setFilter:self.currentCountry];
        
        // Get filtered MKOverlay objects parsed from the KML file and add them to the map
        self.overlays = [self.kmlParser overlays];
    } else {
        // Get all of the MKOverlay objects parsed from the KML file
        self.overlays = [self.kmlParser overlays];
        
        // Initialize location manager
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        // Check unknown selector (<= iOS 7)
        if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            [self.locationManager requestWhenInUseAuthorization];
        }
        
        // Find user location
        [self.locationManager startUpdatingLocation];
        
        // Show user location in map view
        self.mapView.showsUserLocation = YES;
    }
    
    // Walk the list of overlays and create a MKMapRect that bounds all of them and store it into mapRect
    self.visibleMapRect = MKMapRectNull;
    for (id <MKOverlay> overlay in self.overlays) {
        if (MKMapRectIsNull(self.visibleMapRect)) {
            self.visibleMapRect = [overlay boundingMapRect];
        } else {
            self.visibleMapRect = MKMapRectUnion(self.visibleMapRect, [overlay boundingMapRect]);
        }
    }
}

- (void)zoomMap {
    // Zoom to fetched MKOverlay objects
    if (!MKMapRectIsNull(self.visibleMapRect) && _firstInitialization) {
        [self.mapView setVisibleMapRect:self.visibleMapRect edgePadding:UIEdgeInsetsMake(80.0, 80.0, 80.0, 80.0) animated:YES];
    }
}

- (void)showActivityIndicator {
    // Adding Activity Indicator
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhite];
    [activityIndicator startAnimating];
    
    UIBarButtonItem *barBtnItem = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
    self.navigationItem.rightBarButtonItem = barBtnItem;
}

- (void)hideActivityIndicator {
    // Remove Activity Indicator
    self.navigationItem.rightBarButtonItem = self.settingsBtn;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    _currentCountryChanged = NO;
    
    UINavigationController *nc = (UINavigationController *)segue.destinationViewController;
    SelectCountryViewController *vc = (SelectCountryViewController *)nc.topViewController;
    vc.countries = self.kmlParser.countries;
    vc.currentCountry = self.currentCountry;
    vc.delegate = self;
}

#pragma mark - Map view delegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    // Find in which MKPolygon overlays the user location is contained in and add them to the map
    MKMapPoint mapPoint = MKMapPointForCoordinate(userLocation.coordinate);

    // Find user current country from the MKOverlay objects parsed from the KML file
    for (id <MKOverlay> overlay in self.overlays) {
        BOOL pointInside = MKMapRectContainsPoint([overlay boundingMapRect], mapPoint);
        if (pointInside) {
            // Set selected country
            self.currentCountry = overlay.title;
            
            // Save current country to user defautls
            [[NSUserDefaults standardUserDefaults] setObject:overlay.title forKey:@"currentCountry"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            break;
        }
    }
    
    // If current country found
    if (self.currentCountry) {
        [self.kmlParser setFilter:self.currentCountry];
        
        // Get filtered MKOverlay objects based on user's current country and add them to the map
        self.overlays = [self.kmlParser overlays];
        
        // Walk the list of overlays and create a MKMapRect that bounds all of them and store it into mapRect
        MKMapRect mapRect = MKMapRectNull;
        for (id <MKOverlay> overlay in self.overlays) {
            if (MKMapRectIsNull(mapRect)) {
                mapRect = [overlay boundingMapRect];
            } else {
                mapRect = MKMapRectUnion(mapRect, [overlay boundingMapRect]);
            }
        }
        
        // Zoom to created MKMapRect
        [self.mapView setVisibleMapRect:mapRect edgePadding:UIEdgeInsetsMake(80.0, 80.0, 80.0, 80.0) animated:YES];
    }
    
    mapView.showsUserLocation = NO;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    MKOverlayPathRenderer *overlayRenderer = [self.kmlParser rendererForOverlay:overlay];
    overlayRenderer.strokeColor = self.navigationController.navigationBar.tintColor;
    
    return overlayRenderer;
}

- (void)mapView:(MKMapView * _Nonnull)mapView regionDidChangeAnimated:(BOOL)animated {
    // Remove existing overlays
    [self.mapView removeOverlays:self.mapView.overlays];
    
    if (_firstInitialization && self.currentCountry) {
        self.currentCountryLbl.text = self.currentCountry;
        
        // Show overlay view by moving its Y position
        self.overlayViewTopConstr.constant = 0.0;
        [UIView animateWithDuration:0.2 animations:^{
            [self.view layoutIfNeeded];
        }];
        
        // Add overlays to the map
        [self.mapView addOverlays:self.overlays];
    }
}

#pragma mark - Location manager delegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        // Show user location in map view
        self.mapView.showsUserLocation = YES;
    }
}

#pragma mark - KML parser delegate

- (void)parsingDidFinished:(NSError *)error {
    if (!error) {
        // Update UI on main thread
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self hideActivityIndicator];
            [self processKMLData];
            
            [self zoomMap];
        }];
    }
    
    _kmlIsParsed = YES;
}

#pragma mark - Select country  delegate

- (void)currentCountryDidChanged {
    _currentCountryChanged = YES;
    
    // Hide overlay view by moving its Y position
    self.overlayViewTopConstr.constant = -self.overlayView.bounds.size.height;
    [self.view layoutIfNeeded];
}

@end
