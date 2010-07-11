#import "MyDocument.h"

int temporaryViewPosition = -1;
int startViewPosition = -2;
int endViewPosition = -3;

#define temporaryViewPositionNum [NSNumber numberWithInt:temporaryViewPosition]
#define startViewPositionNum [NSNumber numberWithInt:startViewPosition]
#define endViewPositionNum [NSNumber numberWithInt:endViewPosition]

NSString *DemoItemsDropType = @"DemoItemsDropType";

@implementation MyDocument

- (id)init 
{
    self = [super init];
    if (self != nil) {
        // initialization code
    }
    return self;
}

- (NSString *)windowNibName 
{
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
	
	[itemsTableView setDataSource:self];
	[itemsTableView registerForDraggedTypes:[NSArray arrayWithObjects:DemoItemsDropType, nil]];
	[itemsTableView setDraggingSourceOperationMask:(NSDragOperationMove | NSDragOperationCopy) forLocal:YES];
}

- (IBAction)addNewItem:(id)sender
{
	NSManagedObject *newItem = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:[self managedObjectContext]];
	
	[newItem setValue:@"New Item" forKey:@"name"];
	[newItem setValue:endViewPositionNum forKey:@"viewPosition"];
	
	[self renumberViewPositions];
}

- (IBAction)removeSelectedItems:(id)sender
{
	NSArray *selectedItems = [itemsArrayController selectedObjects];
	
	int count;
	for( count = 0; count < [selectedItems count]; count ++ )
	{
		NSManagedObject *currentObject = [selectedItems objectAtIndex:count];
		[[self managedObjectContext] deleteObject:currentObject];
	}
	
	[self renumberViewPositions];
}

- (NSArray *)sortDescriptors
{
	if( _sortDescriptors == nil )
	{
		_sortDescriptors = [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"viewPosition" ascending:YES]];
	}
	return _sortDescriptors;
}

- (NSArray *)itemsUsingFetchPredicate:(NSPredicate *)fetchPredicate
{
	NSError *error = nil;
	NSEntityDescription *entityDesc = [NSEntityDescription entityForName:@"Item" inManagedObjectContext:[self managedObjectContext]];
	
	NSArray *arrayOfItems;
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:entityDesc];
	[fetchRequest setPredicate:fetchPredicate];
	[fetchRequest setSortDescriptors:[self sortDescriptors]];
	arrayOfItems = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
	[fetchRequest release];
	
	return arrayOfItems;
}

- (NSArray *)itemsWithViewPosition:(int)value
{
	NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"viewPosition == %i", value];
	
	return [self itemsUsingFetchPredicate:fetchPredicate];
}

- (NSArray *)itemsWithNonTemporaryViewPosition
{
	NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"viewPosition >= 0"];
	
	return [self itemsUsingFetchPredicate:fetchPredicate];
}

- (NSArray *)itemsWithViewPositionGreaterThanOrEqualTo:(int)value
{
	NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"viewPosition >= %i", value];
	
	return [self itemsUsingFetchPredicate:fetchPredicate];
}

- (NSArray *)itemsWithViewPositionBetween:(int)lowValue and:(int)highValue
{
	NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"viewPosition >= %i && viewPosition <= %i", lowValue, highValue];
	
	return [self itemsUsingFetchPredicate:fetchPredicate];
}

- (int)renumberViewPositionsOfItems:(NSArray *)array startingAt:(int)value
{
	int currentViewPosition = value;
	
	int count = 0;
	
	if( array && ([array count] > 0) )
	{
		for( count = 0; count < [array count]; count++ )
		{
			NSManagedObject *currentObject = [array objectAtIndex:count];
			[currentObject setValue:[NSNumber numberWithInt:currentViewPosition] forKey:@"viewPosition"];
			currentViewPosition++;
		}
	}
	
	return currentViewPosition;
}

- (void)renumberViewPositions
{
	NSArray *startItems = [self itemsWithViewPosition:startViewPosition];
	
	NSArray *existingItems = [self itemsWithNonTemporaryViewPosition];
	
	NSArray *endItems = [self itemsWithViewPosition:endViewPosition];
	
	int currentViewPosition = 0;
	
	if( startItems && ([startItems count] > 0) )
		currentViewPosition = [self renumberViewPositionsOfItems:startItems startingAt:currentViewPosition];
	
	if( existingItems && ([existingItems count] > 0) )
		currentViewPosition = [self renumberViewPositionsOfItems:existingItems startingAt:currentViewPosition];
	
	if( endItems && ([endItems count] > 0) )
		currentViewPosition = [self renumberViewPositionsOfItems:endItems startingAt:currentViewPosition];
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pasteboard
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
	[pasteboard declareTypes:[NSArray arrayWithObject:DemoItemsDropType] owner:self];
	[pasteboard setData:data forType:DemoItemsDropType];
	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
	if( [info draggingSource] == itemsTableView )
	{
		if( op == NSTableViewDropOn )
			[tv setDropRow:row dropOperation:NSTableViewDropAbove];
		
		if(( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSAlternateKeyMask ) )
			return NSDragOperationCopy;
		else
			return NSDragOperationMove;
	}
	else
	{
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard *pasteboard = [info draggingPasteboard];
	NSData *rowData = [pasteboard dataForType:DemoItemsDropType];
	NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
	
	NSArray *allItemsArray = [itemsArrayController arrangedObjects];
	NSMutableArray *draggedItemsArray = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
	
	unsigned int currentItemIndex;
	NSRange range = NSMakeRange( 0, [rowIndexes lastIndex] + 1 );
	while([rowIndexes getIndexes:&currentItemIndex maxCount:1 inIndexRange:&range] > 0)
	{
		NSManagedObject *thisItem = [allItemsArray objectAtIndex:currentItemIndex];
		
		[draggedItemsArray addObject:thisItem];
	}
	
	if( [info draggingSourceOperationMask] & NSDragOperationMove )
	{
		int count;
		for( count = 0; count < [draggedItemsArray count]; count++ )
		{
			NSManagedObject *currentItemToMove = [draggedItemsArray objectAtIndex:count];
			[currentItemToMove setValue:temporaryViewPositionNum forKey:@"viewPosition"];
		}
		
		int tempRow;
		if( row == 0 )
			tempRow = -1;
		else
			tempRow = row;
		
		NSArray *startItemsArray = [self itemsWithViewPositionBetween:0 and:tempRow];
		NSArray *endItemsArray = [self itemsWithViewPositionGreaterThanOrEqualTo:row];
		
		int currentViewPosition;
		
		currentViewPosition = [self renumberViewPositionsOfItems:startItemsArray startingAt:0];
		
		currentViewPosition = [self renumberViewPositionsOfItems:draggedItemsArray startingAt:currentViewPosition];
		
		currentViewPosition = [self renumberViewPositionsOfItems:endItemsArray startingAt:currentViewPosition];
		
		return YES;
	}
	else if( [info draggingSourceOperationMask] & NSDragOperationCopy )
	{
		NSArray *copiedItemsArray = [self copyItems:draggedItemsArray];
		
		int tempRow;
		if( row == 0 )
			tempRow = -1;
		else
			tempRow = row;
		
		NSArray *startItemsArray = [self itemsWithViewPositionBetween:0 and:tempRow];
		NSArray *endItemsArray = [self itemsWithViewPositionGreaterThanOrEqualTo:row];
		
		int currentViewPosition;
		
		currentViewPosition = [self renumberViewPositionsOfItems:startItemsArray startingAt:0];
		
		currentViewPosition = [self renumberViewPositionsOfItems:copiedItemsArray startingAt:currentViewPosition];
		
		currentViewPosition = [self renumberViewPositionsOfItems:endItemsArray startingAt:currentViewPosition];		
		
		return YES;
	}
	
	return NO;
}

- (NSArray *)copyItems:(NSArray *)itemsToCopyArray
{
	NSMutableArray *arrayOfCopiedItems = [NSMutableArray arrayWithCapacity:[itemsToCopyArray count]];
	
	int count;
	for( count = 0; count < [itemsToCopyArray count]; count++ )
	{
		NSManagedObject *itemToCopy = [itemsToCopyArray objectAtIndex:count];
		NSManagedObject *copiedItem = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:[self managedObjectContext]];
		
		[copiedItem setValue:[itemToCopy valueForKey:@"name"] forKey:@"name"];
		[copiedItem setValue:temporaryViewPositionNum forKey:@"viewPosition"];
		
		[arrayOfCopiedItems addObject:copiedItem];
	}
	
	return arrayOfCopiedItems;
}

@end