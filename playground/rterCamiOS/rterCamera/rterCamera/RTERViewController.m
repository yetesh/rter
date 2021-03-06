//
//  rterCameraViewController.m
//  rterCamera
//
//  Created by Stepan Salenikovich on 2013-03-05.
//  Copyright (c) 2013 rtER. All rights reserved.
//

#import "RTERViewController.h"
#import "Config.h"

@interface RTERViewController () {
    NSUserDefaults *defaults;
    SSKeychainQuery *query;
}

@end

@implementation RTERViewController

@synthesize userField;
@synthesize passField;
@synthesize cookieString;
@synthesize userName;

RTERPreviewController *preview;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	userField.delegate = self;
	passField.delegate = self;
	preview = nil;
    
    // user and password stuff
    defaults = [NSUserDefaults standardUserDefaults];
    query = [[SSKeychainQuery alloc] init];
    
    // check to see if a user name is stored
    NSString *username = [defaults objectForKey:@"username"];
    
    NSLog(@"username %@", username);
    
    if(username) {        
        self.userField.text = username;
        
        // now check if password is stored for this user name
        NSString *password = [SSKeychain passwordForService:@"login" account:username];
        if (password) {
            [self.passField setText:password];
        } else {
            NSLog(@"can't find password");
        }
        
    }

}

- (void) viewDidAppear:(BOOL)animated {


}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startCamera:(id)sender {
    //if (![cookieString isEqualToString: @""]) {
    preview = [[RTERPreviewController alloc] init];
		
    preview.delegate = self;
    preview.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;

    userName = userField.text;
    
    [self presentViewController:preview
                       animated:YES
                     completion:nil];
    
	//}
    
}

- (IBAction)login:(id)sender {
	
	// for ASync method
	// NSOperationQueue *opQueue = [[NSOperationQueue alloc] init];
	
	NSLog(@"Attempting auth:\n\t%@\n\t%@", self.userField.text, self.passField.text);
    
    [defaults setObject:self.userField.text forKey:@"username"];
    
    // forget old passwords for now, ie: ones not used with the current attempted username
    NSArray *accounts = [query fetchAll:nil];
    if (accounts) {
        [query delete:nil];
    }
    // save current password
    [SSKeychain setPassword:self.passField.text forService:@"login" account:self.userField.text];
    
    NSString *password = [SSKeychain passwordForService:@"login" account:self.userField.text];
    
    NSLog(@"saved password %@", password);

    [self loginWithUser:self.userField.text Password:self.passField.text];
}

- (IBAction)anonymousLogin:(id)sender {
    NSLog(@"Attempting anonymous login");
    
    [self loginWithUser:@"anonymous" Password:@"anonymous"];

}

- (void)loginWithUser:(NSString *)user Password:(NSString *)password {
    
    userName = user;
    
	// the json string to post
	NSString *jsonString = [NSString stringWithFormat:@"{\"Username\": \"%@\", \"Password\":\"%@\"}", [user stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSData *postData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
	
	// setup the request
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@/auth",SERVER]]];
	
	//NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://142.157.58.36:8080/auth"]];
	[request setHTTPMethod:@"POST"];
	[request setHTTPShouldHandleCookies:YES];
	[request setHTTPBody:postData];
	[request setAllowsCellularAccess:YES];
	[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	[request setValue:[NSString stringWithFormat:@"%d",[postData length]] forHTTPHeaderField:@"Content-Length"];
	
	// post the data - ASync
//	[NSURLConnection sendAsynchronousRequest:request queue:opQueue completionHandler:^(NSURLResponse *urlResponse, NSData * responseData, NSError * responseError) {
//		NSLog(@"%d - %@\n%@", [(NSHTTPURLResponse*)urlResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[(NSHTTPURLResponse*)urlResponse statusCode]], [[(NSHTTPURLResponse*)urlResponse allHeaderFields] description]);
//		if (responseError) {
//			NSLog(@"%@", [responseError description]);
//			NSLog(@"=========Data===========");
//			NSLog(@"%@", [responseData description]);
//		}
//	}];
	
	[NSURLConnection connectionWithRequest:request delegate:self];
	
	//[connection sendSynchronousRequest:request returningResponse:&response error:&httpError];
	//NSLog(@"%d - %@\n%@", [response statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], [response allHeaderFields]);
	//[connection start];
	
	
	//print the result
//	NSLog(@"========= Other Data ==========");
//	NSLog(@"%d - %@\n%@", [response statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], [[response allHeaderFields] description]);
//	if (httpError) {
//		NSLog(@"%@", [httpError description]);
//	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	//NSLog(@"Connection: %@\n, AuthConnection: %@", connection, [preview getAuthConnection]);
	
	if (connection == [preview getAuthConnection]) {
		NSLog(@"DidRecieveResponse");

		// Streaming token
		NSLog(@"===Streaming Auth Response===");
		NSLog(@"%d - %@", [(NSHTTPURLResponse*)response statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[(NSHTTPURLResponse*)response statusCode]] );
		
		if ([(NSHTTPURLResponse*)response statusCode] == 200) {
		} else {
			
		}
	} else {
		// login auth
		NSLog(@"%d - %@", [(NSHTTPURLResponse*)response statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[(NSHTTPURLResponse*)response statusCode]] );
		NSLog(@"%@", [(NSHTTPURLResponse*)response allHeaderFields]);
		if ([(NSHTTPURLResponse*)response statusCode] == 200) {
			NSDictionary *dict = [(NSHTTPURLResponse*)response allHeaderFields];
			cookieString = [dict valueForKey:@"Set-Cookie"];
			NSLog(@"Set-Cookie: %@", cookieString);
			[self startCamera:nil];
		}
	}
}

- (void)connection:(NSURLConnection *)aConn didReceiveData:(NSData *)data

{
	if (aConn == [preview getAuthConnection]) {
		NSLog(@"DATA:");
		//NSLog(@"%@", [data description]);
		NSError *error;
		NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:
								  NSJSONReadingMutableContainers error:&error];
		NSLog(@"%@",jsonDict);
		NSLog(@"AuthString:=====\nrtER rter_resource=\"%@\", rter_signature=\"%@\", rter_valid_until=\"%@\"", [[jsonDict objectForKey:@"Token"] objectForKey:@"rter_resource"], [[jsonDict objectForKey:@"Token"] objectForKey:@"rter_signature"], [[jsonDict objectForKey:@"Token"] objectForKey:@"rter_valid_until"]);
		NSString *authString = [NSString stringWithFormat:@"rtER rter_resource=\"%@\", rter_signature=\"%@\", rter_valid_until=\"%@\"",
								[[jsonDict objectForKey:@"Token"] objectForKey:@"rter_resource"],
								[[jsonDict objectForKey:@"Token"] objectForKey:@"rter_signature"],
								[[jsonDict objectForKey:@"Token"] objectForKey:@"rter_valid_until"]];
		[preview setAuthString:authString];
		preview.streamingEndpoint = [jsonDict objectForKey:@"UploadURI"];
        [preview setItemID:[jsonDict objectForKey:@"ID"]];
        NSLog(@"\n\nITEMID: %@\n\n\n",preview.itemID);
	}
}


- (void)back {
    [self dismissViewControllerAnimated:YES completion: nil];
	cookieString = @"";
}

#pragma mark - UITextFieldDelegate

// for dismissing
- (BOOL) textFieldShouldReturn:(UITextField *)textField {
	if (textField == self.userField) {
		[textField resignFirstResponder];
		[passField becomeFirstResponder];
	} else {
		[textField resignFirstResponder];
		[self login:nil];
	}
	return YES;
}

@end
