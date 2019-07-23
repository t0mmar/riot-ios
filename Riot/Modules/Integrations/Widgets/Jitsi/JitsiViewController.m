/*
 Copyright 2017 Vector Creations Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "JitsiViewController.h"
@import JitsiMeet;

static const NSString *kJitsiDataErrorKey = @"error";

@interface JitsiViewController () <JitsiMeetViewDelegate>

// The jitsi-meet SDK view
@property (nonatomic, weak) IBOutlet JitsiMeetView *jitsiMeetView;

@property (nonatomic, strong) NSString *conferenceId;
@property (nonatomic) BOOL startWithVideo;

@end

@implementation JitsiViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass(self.class)
                          bundle:[NSBundle bundleForClass:self.class]];
}

+ (instancetype)jitsiViewController
{
    JitsiViewController *jitsiViewController = [[[self class] alloc] initWithNibName:NSStringFromClass(self.class)
                                          bundle:[NSBundle bundleForClass:self.class]];
    return jitsiViewController;
}

#pragma mark - Life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.jitsiMeetView.delegate = self;
    
    [self joinConference];
}

- (BOOL)prefersStatusBarHidden
{    
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Public

- (void)openWidget:(Widget*)widget withVideo:(BOOL)aVideo
           success:(void (^)(void))success
           failure:(void (^)(NSError *error))failure
{
    self.startWithVideo = aVideo;
    _widget = widget;
    
    MXWeakify(self);

    [_widget widgetUrl:^(NSString * _Nonnull widgetUrl) {
        
        MXStrongifyAndReturnIfNil(self);

        // Extract the jitsi conference id from the widget url
        NSString *confId;
        NSURL *url = [NSURL URLWithString:widgetUrl];
        if (url)
        {
            NSURLComponents *components = [[NSURLComponents new] initWithURL:url resolvingAgainstBaseURL:NO];
            NSArray *queryItems = [components queryItems];

            for (NSURLQueryItem *item in queryItems)
            {
                if ([item.name isEqualToString:@"confId"])
                {
                    confId = item.value;
                    break;
                }
            }
        }
        
        self.conferenceId = confId;

        if (confId)
        {
            if (success)
            {
                success();
            }
        }
        else
        {
            NSLog(@"[JitsiVC] Failed to load widget: %@. Widget event: %@", widget, widget.widgetEvent);

            if (failure)
            {
                failure(nil);
            }
        }

    } failure:^(NSError * _Nonnull error) {

        NSLog(@"[JitsiVC] Failed to load widget 2: %@. Widget event: %@", widget, widget.widgetEvent);

        if (failure)
        {
            failure(nil);
        }
    }];
}

- (void)hangup
{
    [self.jitsiMeetView leave];
}

#pragma mark - Private

- (void)joinConference
{
    [self joinConferenceWithId:self.conferenceId];
}

- (void)joinConferenceWithId:(NSString*)conferenceId
{
    if (conferenceId)
    {
        // TODO: Set up user info but it is not yet available in the jitsi-meet iOS SDK
        // See https://github.com/jitsi/jitsi-meet/issues/1880
        
        JitsiMeetConferenceOptions *jitsiMeetConferenceOptions = [JitsiMeetConferenceOptions fromBuilder:^(JitsiMeetConferenceOptionsBuilder * _Nonnull jitsiMeetConferenceOptionsBuilder) {
            jitsiMeetConferenceOptionsBuilder.room = conferenceId;
            jitsiMeetConferenceOptionsBuilder.videoMuted = !self.startWithVideo;
        }];
        
        [self.jitsiMeetView join:jitsiMeetConferenceOptions];
    }
}

#pragma mark - JitsiMeetViewDelegate

- (void)conferenceWillJoin:(NSDictionary *)data
{
}

- (void)conferenceJoined:(NSDictionary *)data
{
}

- (void)conferenceTerminated:(NSDictionary *)data
{
    if (data[kJitsiDataErrorKey] != nil)
    {
        NSLog(@"[JitsiViewController] conferenceTerminated - data: %@", data);
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // The conference is over. Let the delegate close this view controller.
            if (self.delegate)
            {
                [self.delegate jitsiViewController:self dismissViewJitsiController:nil];
            }
            else
            {
                // Do it ourself
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        });
    }
}

- (void)enterPictureInPicture:(NSDictionary *)data
{
    if (self.delegate)
    {
        [self.delegate jitsiViewController:self goBackToApp:nil];
    }
}

@end
