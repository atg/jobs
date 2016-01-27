//
//  JobsScheduler.h
//  jobs
//
//  Created by Alex Gordon on 27/01/2016.
//  Copyright © 2016 Chocolat. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol GenericTerminal
@required
@property (copy) NSString* projectDir;
@property (copy) NSString* workingDir;
- (void)runCommand:(NSString*)cmd;
@end

@interface AppleTerminal : NSObject<GenericTerminal>
@end

@interface iTermTerminal : NSObject<GenericTerminal>
@end
