//
//  UploadDSAD.h

#import <UIKit/UIKit.h>
#import "TransferDSADDelegate.h"

@interface UploadDSAD : NSObject <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) id<TransferDSADDelegate> delegate;

- (BOOL)selectAllTasks;

- (void)deselectAllTasks:(BOOL)animated;

- (void)deleteAllSelected;

@end
