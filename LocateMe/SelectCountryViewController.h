//
//  SelectCountryViewController.h
//  LocateMe
//
//  Created by gdanikas on 15/10/15.
//  Copyright © 2015 George Danikas. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SelectCountryDelegate <NSObject>
- (void)currentCountryDidChangeTo:(NSString *)newCountry;
@end

@interface SelectCountryViewController : UIViewController

@property (nonatomic) NSArray *countries;
@property (nonatomic) NSString *currentCountry;

@property (weak, nonatomic) id <SelectCountryDelegate> delegate;

@end
