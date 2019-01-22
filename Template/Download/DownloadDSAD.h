//
//  DownloadDSAD.h
//  DSAS: DataSource and Delegate

#import <UIKit/UIKit.h>
#import "TransferDSADDelegate.h"

@interface DownloadDSAD : NSObject <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) id<TransferDSADDelegate> delegate;

- (BOOL)selectAllTasks;

- (void)deselectAllTasks:(BOOL)animated;

- (void)deleteAllSelected;

@end
