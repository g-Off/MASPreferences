
#import "MASPreferencesWindowController.h"

NSString *const kMASPreferencesWindowControllerDidChangeViewNotification = @"MASPreferencesWindowControllerDidChangeViewNotification";

static NSString *const kMASPreferencesFrameTopLeftKey = @"MASPreferences Frame Top Left";
static NSString *const kMASPreferencesSelectedViewKey = @"MASPreferences Selected Identifier View";

static NSString *const PreferencesKeyForViewBounds (NSString *identifier)
{
    return [NSString stringWithFormat:@"MASPreferences %@ Frame", identifier];
}

@interface MASPreferencesWindowController () // Private

- (NSViewController <MASPreferencesViewController> *)viewControllerForIdentifier:(NSString *)identifier;

@property (readonly) NSArray *toolbarItemIdentifiers;

@end

#pragma mark -

@implementation MASPreferencesWindowController

#pragma mark -

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    return [self initWithViewControllers:viewControllers title:nil];
}

- (id)initWithViewControllers:(NSArray *)viewControllers title:(NSString *)title
{
    if ((self = [super initWithWindowNibName:@"MASPreferencesWindow"]))
    {
        _viewControllers = viewControllers;
        _title = [title copy];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self window] setDelegate:nil];
}

#pragma mark -

- (void)windowDidLoad
{
    if ([self.title length] > 0)
        [[self window] setTitle:self.title];

    if ([self.viewControllers count])
		[self setSelectedViewController:[self viewControllerForIdentifier:[[NSUserDefaults standardUserDefaults] stringForKey:kMASPreferencesSelectedViewKey]] ?: [self.viewControllers objectAtIndex:0]];

    NSString *origin = [[NSUserDefaults standardUserDefaults] stringForKey:kMASPreferencesFrameTopLeftKey];
    if (origin)
        [self.window setFrameTopLeftPoint:NSPointFromString(origin)];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidMove:)   name:NSWindowDidMoveNotification object:self.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:self.window];
}

#pragma mark -
#pragma mark NSWindowDelegate

- (BOOL)windowShouldClose:(id)sender
{
    return !self.selectedViewController || [self.selectedViewController commitEditing];
}

- (void)windowDidMove:(NSNotification*)aNotification
{
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromPoint(NSMakePoint(NSMinX([self.window frame]), NSMaxY([self.window frame]))) forKey:kMASPreferencesFrameTopLeftKey];
}

- (void)windowDidResize:(NSNotification*)aNotification
{
    NSViewController <MASPreferencesViewController> *viewController = self.selectedViewController;
    if (viewController)
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([viewController.view bounds]) forKey:PreferencesKeyForViewBounds(viewController.identifier)];
}

#pragma mark -
#pragma mark Accessors

- (NSArray *)toolbarItemIdentifiers
{
    NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity:_viewControllers.count];
    for (id viewController in _viewControllers)
        if (viewController == [NSNull null])
            [identifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];
        else
            [identifiers addObject:[viewController identifier]];
    return identifiers;
}

#pragma mark -

- (NSUInteger)indexOfSelectedController
{
    NSUInteger index = [self.toolbarItemIdentifiers indexOfObject:self.selectedViewController.identifier];
    return index;
}

#pragma mark -
#pragma mark NSToolbarDelegate

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    NSArray *identifiers = self.toolbarItemIdentifiers;
    return identifiers;
}                   
                   
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    NSArray *identifiers = self.toolbarItemIdentifiers;
    return identifiers;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    NSArray *identifiers = self.toolbarItemIdentifiers;
    return identifiers;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    NSArray *identifiers = self.toolbarItemIdentifiers;
    NSUInteger controllerIndex = [identifiers indexOfObject:itemIdentifier];
    if (controllerIndex != NSNotFound)
    {
        id <MASPreferencesViewController> controller = [_viewControllers objectAtIndex:controllerIndex];
        toolbarItem.image = controller.toolbarItemImage;
        toolbarItem.label = controller.toolbarItemLabel;
        toolbarItem.target = self;
        toolbarItem.action = @selector(toolbarItemDidClick:);
    }
    return toolbarItem;
}

#pragma mark -
#pragma mark Private methods

- (void)clearResponderChain
{
    // Remove view controller from the responder chain
    NSResponder *chainedController = self.window.nextResponder;
    if ([self.viewControllers indexOfObject:chainedController] == NSNotFound)
        return;
    self.window.nextResponder = chainedController.nextResponder;
    chainedController.nextResponder = nil;
}

- (void)patchResponderChain
{
    [self clearResponderChain];
    
    NSViewController *selectedController = self.selectedViewController;
    if (!selectedController)
        return;
    
    // Add current controller to the responder chain
    NSResponder *nextResponder = self.window.nextResponder;
    self.window.nextResponder = selectedController;
    selectedController.nextResponder = nextResponder;
}

- (NSViewController <MASPreferencesViewController> *)viewControllerForIdentifier:(NSString *)identifier
{
    for (id viewController in self.viewControllers) {
        if (viewController == [NSNull null]) continue;
        if ([[viewController identifier] isEqualToString:identifier])
            return viewController;
    }
    return nil;
}

#pragma mark -

- (void)setSelectedViewController:(NSViewController <MASPreferencesViewController> *)controller
{
    if (_selectedViewController == controller)
        return;

    if (_selectedViewController)
    {
        // Check if we can commit changes for old controller
        if (![_selectedViewController commitEditing])
        {
            [[self.window toolbar] setSelectedItemIdentifier:_selectedViewController.identifier];
            return;
        }
		
        [self.window setContentView:[[NSView alloc] init]];
        if ([_selectedViewController respondsToSelector:@selector(viewDidDisappear)])
            [_selectedViewController viewDidDisappear];

        _selectedViewController = nil;
    }

    if (!controller)
        return;

    // Retrieve the new window tile from the controller view
    if ([self.title length] == 0)
    {
        NSString *label = controller.toolbarItemLabel;
        self.window.title = label;
    }

    [[self.window toolbar] setSelectedItemIdentifier:controller.identifier];

    // Record new selected controller in user defaults
    [[NSUserDefaults standardUserDefaults] setObject:controller.identifier forKey:kMASPreferencesSelectedViewKey];
    
    NSView *controllerView = controller.view;
    
    _selectedViewController = controller;
    if ([controller respondsToSelector:@selector(viewWillAppear)])
        [controller viewWillAppear];
    
	[self.window.contentView addSubview:controllerView];
	NSDictionary *views = NSDictionaryOfVariableBindings(controllerView);
	NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|[controllerView]|"
																   options:0
																   metrics:nil
																	 views:views];
	[self.window.contentView addConstraints:constraints];
	constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[controllerView]|"
														  options:0
														  metrics:nil
															views:views];
	[self.window.contentView addConstraints:constraints];
	
	[self.window layoutIfNeeded];
	
    [self.window recalculateKeyViewLoop];
    if ([self.window firstResponder] == self.window) {
        if ([controller respondsToSelector:@selector(initialKeyView)])
            [self.window makeFirstResponder:[controller initialKeyView]];
        else
            [self.window selectKeyViewFollowingView:controllerView];
    }
    
    // Insert view controller into responder chain
    [self patchResponderChain];

    [[NSNotificationCenter defaultCenter] postNotificationName:kMASPreferencesWindowControllerDidChangeViewNotification object:self];
}

- (void)toolbarItemDidClick:(id)sender
{
    if ([sender respondsToSelector:@selector(itemIdentifier)])
		[self setSelectedViewController:[self viewControllerForIdentifier:[sender itemIdentifier]]];
}

#pragma mark -
#pragma mark Public methods

- (void)selectControllerAtIndex:(NSUInteger)controllerIndex
{
    if (NSLocationInRange(controllerIndex, NSMakeRange(0, _viewControllers.count)))
		[self setSelectedViewController:[self.viewControllers objectAtIndex:controllerIndex]];
}

#pragma mark -
#pragma mark Actions

- (IBAction)goNextTab:(id)sender
{
    NSUInteger selectedIndex = self.indexOfSelectedController;
    NSUInteger numberOfControllers = [_viewControllers count];
    selectedIndex = (selectedIndex + 1) % numberOfControllers;
    [self selectControllerAtIndex:selectedIndex];
}

- (IBAction)goPreviousTab:(id)sender
{
    NSUInteger selectedIndex = self.indexOfSelectedController;
    NSUInteger numberOfControllers = [_viewControllers count];
    selectedIndex = (selectedIndex + numberOfControllers - 1) % numberOfControllers;
    [self selectControllerAtIndex:selectedIndex];
}

@end
