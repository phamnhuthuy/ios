//
//  HCSRouteListViewController.m
//  CycleStreets
//
//  Created by Neil Edwards on 20/01/2014.
//  Copyright (c) 2014 CycleStreets Ltd. All rights reserved.
//

#import "HCSRouteListViewController.h"
#import "CoreDataStore.h"
#import "TripManager.h"
#import "UIView+Additions.h"
#import "AppConstants.h"
#import "GenericConstants.h"
#import "UIAlertView+BlocksKit.h"
#import "HCSMapViewController.h"
#import "HCSSavedTrackCellView.h"
#import "UIActionSheet+BlocksKit.h"
#import "constants.h"
#import "Trip.h"
#import "GlobalUtilities.h"

static NSString *const  kCellReuseIdentifierCheck=@"CheckMark";
static NSString *const kCellReuseIdentifierExclamation=@"Exclamataion";
static NSString *const kCellReuseIdentifierInProgress=@"InProgress";

static NSString *const VIEWTITLE=@"Saved Routes";


@interface HCSRouteListViewController ()<UIActionSheetDelegate>

// data
@property (nonatomic,strong) NSMutableArray					*dataProvider;
@property (nonatomic,strong)  Trip							*selectedTrip;

// ui
@property (nonatomic,weak) IBOutlet UITableView				*tableView;
@property (weak, nonatomic) IBOutlet UILabel				*distanceLabel;


// state


@end

@implementation HCSRouteListViewController


//
/***********************************************
 * @description		NOTIFICATIONS
 ***********************************************/
//

-(void)listNotificationInterests{
	
	[self initialise];
	
	[notifications addObject:RESPONSE_GPSUPLOADMULTI];
	
	[super listNotificationInterests];
	
}

-(void)didReceiveNotification:(NSNotification*)notification{
	
	[super didReceiveNotification:notification];
	
	NSString *name=notification.name;
	
	if([name isEqualToString:RESPONSE_GPSUPLOADMULTI]){
		
		[self refreshUIFromDataProvider];
		
	}
	
}


#pragma mark - Data Provider


-(void)refreshUIFromDataProvider{
	
	NSMutableArray *tripArray=[[Trip allForPredicate:[NSPredicate predicateWithFormat:@"saved != nil"] orderBy:@"start" ascending:NO] mutableCopy];
	
	if (tripArray.count==0) {
		
		[self showViewOverlayForType:kViewOverlayTypeNoResults show:YES withMessage:@"noresults_SAVEDTRIPS" withIcon:@"SAVED_TRIPS"];
		
	}else{
		[self showViewOverlayForType:kViewOverlayTypeNone show:NO withMessage:@"" withIcon:@""];
	}
	
	[self updateUploaddUI];
	
	self.dataProvider=tripArray;
	[self.tableView reloadData];
	
}


-(int)updateUploaddUI{
	
	int unsyncedCount= [[TripManager sharedInstance] countUnSyncedTrips];
	self.navigationItem.rightBarButtonItem.enabled=unsyncedCount>0;
	
	return unsyncedCount;
}


//
/***********************************************
 * @description			VIEW METHODS
 ***********************************************/
//

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.selectedTrip = nil;
	_distanceLabel.text=EMPTYSTRING;
	
    [self createPersistentUI];
}


-(void)viewWillAppear:(BOOL)animated{
	
	[self.navigationController setNavigationBarHidden:NO animated:YES];
    
    [self createNonPersistentUI];
    
    [super viewWillAppear:animated];
}


-(void)createPersistentUI{
	
	[_tableView registerNib:[HCSSavedTrackCellView nib] forCellReuseIdentifier:[HCSSavedTrackCellView cellIdentifier]];
	
	
	self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(didSelectActionButton)];
	
	
	int unsyncedCount=[self updateUploaddUI];
	
	if(unsyncedCount>1){
		
		
		UIAlertView *alert=[UIAlertView  bk_alertViewWithTitle:[NSString stringWithFormat:@"Found Unsynced Trip%@",unsyncedCount>1 ? @"s" : EMPTYSTRING] message:
							[NSString stringWithFormat:@"You have %i saved trip%@ that %@ not yet been uploaded.",unsyncedCount,unsyncedCount>1 ? @"s" : EMPTYSTRING, unsyncedCount>1 ? @"have" : @"has"]];
		[alert bk_addButtonWithTitle:@"OK" handler:^{
			
		}];
		[alert show];
		
	}
	
}

-(void)createNonPersistentUI{
    
	[self refreshUIFromDataProvider];
	
	_distanceLabel.text=[TripManager sharedInstance].totalTripDistanceString;
    
}



#pragma mark UITableView
//
/***********************************************
 * @description			UITABLEVIEW DELEGATES
 ***********************************************/
//

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [_dataProvider count];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}


-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
	Trip *trip = (Trip *)[_dataProvider objectAtIndex:indexPath.row];
	
	//Trip *currentTripinProgress = [[TripManager sharedInstance] currentRecordingTrip];
	
	// if cell is current recording one dont allow selection, should have different icon too
	
	HCSSavedTrackCellView *cell=[_tableView dequeueReusableCellWithIdentifier:[HCSSavedTrackCellView cellIdentifier]];
	
	cell.dataProvider=trip;
	[cell populate];
	
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{

	self.selectedTrip = (Trip *)[_dataProvider objectAtIndex:indexPath.row];
	
	[self displaySelectedTripMap];

}



#pragma mark - Table View Editing


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete){
		
		NSLog(@"Delete");
		
        // Delete the managed object at the given index path.
        Trip *tripToDelete = [_dataProvider objectAtIndex:indexPath.row];
        [[TripManager sharedInstance] deleteTrip:tripToDelete];
		
        // Update the array and table view.
        [_dataProvider removeObjectAtIndex:indexPath.row];
        [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
		
		[self updateUploaddUI];
		
		_distanceLabel.text=[TripManager sharedInstance].totalTripDistanceString;
		
    }
	
}





#pragma mark - Map ViewController display


- (void)displaySelectedTripMap{
	
	if ( _selectedTrip ){
		HCSMapViewController *controller = [[HCSMapViewController alloc] initWithNibName:[HCSMapViewController nibName] bundle:nil];
		controller.trip=_selectedTrip;
		controller.viewMode=HCSMapViewModeShow;
		[[self navigationController] pushViewController:controller animated:YES];
	}
	
}


//
/***********************************************
 * @description			UI EVENTS
 ***********************************************/
//


- (void)didSelectActionButton{
	
	int unsyncedCount= [[TripManager sharedInstance] countUnSyncedTrips];
	
	UIActionSheet *actionSheet=[UIActionSheet bk_actionSheetWithTitle:[NSString stringWithFormat:@"You have %i un-synced trip%@, do you wish to upload %@ now. This may take a little time.",
					unsyncedCount,unsyncedCount>1 ? @"s" : EMPTYSTRING,
					unsyncedCount>1 ? @"them all":@"this"]];
	
	[actionSheet bk_addButtonWithTitle:[NSString stringWithFormat:@"Upload%@",unsyncedCount>1 ? @" All":EMPTYSTRING] handler:^{
		[[TripManager sharedInstance] uploadAllUnsyncedTrips];
	}];
	
	[actionSheet bk_setCancelButtonWithTitle:@"Cancel" handler:^{
		
	}];
	
	[actionSheet showInView:[[[UIApplication sharedApplication]delegate]window]];
	
}






//
/***********************************************
 * @description			MEMORY
 ***********************************************/
//
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

@end