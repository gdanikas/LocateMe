//
//  SelectCountryViewController.m
//  LocateMe
//
//  Created by gdanikas on 15/10/15.
//  Copyright © 2015 George Danikas. All rights reserved.
//

#import "SelectCountryViewController.h"

@interface SelectCountryViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@property (nonatomic) NSArray *filteredCountriesArray;
@property (nonatomic) NSMutableArray *sections;
@property (nonatomic) UIBarButtonItem *doneBtn;

@end

@implementation SelectCountryViewController {
    BOOL _filteredMode;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Reset flags
    _filteredMode = NO;
    
    // Set up buttons
    self.doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneBtnTapped:)];
    self.doneBtn.tintColor = [UIColor whiteColor];
    
    // Sort countries alphabetically
    self.countries = [self.countries sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    // Initialize arrays
    self.filteredCountriesArray = self.countries;
    self.sections = [NSMutableArray array];
    
    // Set sections
    for (NSString *country in self.countries) {
        NSString *key = [[country substringToIndex:1] uppercaseString];
        if (![self.sections containsObject:key])
            [self.sections addObject:key];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Scroll to selected country
    if (self.currentCountry) {
        [self scrollToCountry:self.currentCountry withAnimation:YES];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)scrollToCountry:(NSString *)countryName withAnimation:(BOOL)animated {
    NSString *key = [[countryName substringToIndex:1] uppercaseString];
    NSArray *sectionArray = [self.countries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF beginswith[c] %@", key]];
    
    NSUInteger idx = [sectionArray indexOfObject:self.currentCountry];
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:[self.sections indexOfObject:key]] animated:animated scrollPosition:UITableViewScrollPositionTop];
}

#pragma mark - Actions

- (IBAction)cancelBtnTapped:(id)sender {
    // Dismiss keyboard
    [self.view endEditing:NO];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)doneBtnTapped:(id)sender {
    // Dismiss keyboard
    [self.view endEditing:NO];
    
    // Trigger delgate
    if ([self.delegate respondsToSelector:@selector(currentCountryDidChanged)])
        [self.delegate currentCountryDidChanged];
    
    // Save current country to user defautls
    [[NSUserDefaults standardUserDefaults] setObject:self.currentCountry forKey:@"currentCountry"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return !_filteredMode ? self.sections.count : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_filteredMode) {
        NSArray *sectionArray = [self.countries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF beginswith[c] %@", [self.sections objectAtIndex:section]]];
        
        return sectionArray.count;
    }
    
    return self.filteredCountriesArray.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return !_filteredMode ? [self.sections objectAtIndex:section] : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CountryCell" forIndexPath:indexPath];
    
    NSString *countryName;
    if (!_filteredMode) {
        NSArray *sectionArray = [self.countries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF beginswith[c] %@", [self.sections objectAtIndex:indexPath.section]]];
        
        countryName = [sectionArray objectAtIndex:indexPath.row];
    } else {
        countryName = [self.filteredCountriesArray objectAtIndex:indexPath.row];
    }
    
    cell.textLabel.text = countryName;
    
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    if (self.currentCountry && [self.currentCountry isEqualToString:countryName]) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    
    // Find selected country
    if (!_filteredMode) {
        NSArray *sectionArray = [self.countries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF beginswith[c] %@", [self.sections objectAtIndex:indexPath.section]]];
        
        self.currentCountry = [sectionArray objectAtIndex:indexPath.row];
    } else {
        self.currentCountry = [self.filteredCountriesArray objectAtIndex:indexPath.row];
        
        // Dismiss search bar by triggering Cancel actino
        [self searchBarCancelButtonClicked:self.searchBar];
        
        // Scroll to selected country
        [self scrollToCountry:self.currentCountry withAnimation:YES];
    }

    // Show done button
    if (self.navigationItem.rightBarButtonItem == nil) {
        self.navigationItem.rightBarButtonItem = self.doneBtn;
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [cell setAccessoryType:UITableViewCellAccessoryNone];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)filterCountriesForSearchText:(NSString *)searchText {
    if (searchText && searchText.length > 0) {
        NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", searchText];
        self.filteredCountriesArray = [self.countries filteredArrayUsingPredicate:resultPredicate];
        _filteredMode = YES;
    } else {
        _filteredMode = NO;
    }
    
    [self.tableView reloadData];
}

#pragma mark - Search bar delegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    searchBar.showsCancelButton = YES;
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.showsCancelButton = NO;
    searchBar.text = nil;
    [searchBar resignFirstResponder];
    
    [self filterCountriesForSearchText:searchBar.text];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterCountriesForSearchText:searchText];
}

@end
