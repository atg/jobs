//
//  JobsScheduler.m
//  jobs
//
//  Created by Alex Gordon on 27/01/2016.
//  Copyright © 2016 Chocolat. All rights reserved.
//

#import "JobsTerminals.h"
#import "scripting/Terminal.h"
#import "scripting/iTerm2.h"

// https://superuser.com/questions/220679/how-to-get-tty-shell-working-directory

static NSString* runTask(NSString* name, NSString* cwd, NSArray<NSString*>* args) {
    NSTask * task = [[NSTask alloc] init];
    [task setLaunchPath:name];
    [task setCurrentDirectoryPath:cwd];
    [task setArguments:args];

    NSPipe *outPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];

    [task launch];
    [task waitUntilExit];

    NSFileHandle* read = [outPipe fileHandleForReading];
    NSData* data = [read readDataToEndOfFile];
    NSString* txt = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return txt;
}


static NSCharacterSet* whitespaceCharset() {
    static NSMutableCharacterSet* whitespace;
    static dispatch_once_t whitespaceOnce;
    dispatch_once(&whitespaceOnce, ^{
        whitespace = [[NSMutableCharacterSet alloc] init];
        [whitespace addCharactersInString:@" \t\f\r\n"];
    });
    return whitespace;
}

@implementation AppleTerminal
@synthesize projectDir, workingDir;
- (void)runCommand:(NSString*)cmd {
	TerminalApplication *term = [SBApplication applicationWithBundleIdentifier:@"com.apple.Terminal"];
    [term activate];
    
    NSCharacterSet* whitespace = whitespaceCharset();
    
    // Iterate over the windows and tabs
    for (TerminalWindow* win in term.windows) {
        for (TerminalTab* tab in win.tabs) {
            
            NSString* tty = tab.tty;
            NSString* ttyNoDev = [tty stringByReplacingOccurrencesOfString:@"/dev/" withString:@""];
            
            NSString* psF = runTask(@"/bin/bash", NSHomeDirectory(), @[ @"-c", [NSString stringWithFormat:@"ps -f | grep bash | grep %@", ttyNoDev] ]);
            
            NSMutableArray* cols = [[psF componentsSeparatedByCharactersInSet:whitespace] mutableCopy];
            [cols removeObject:@""];
            if ([cols count] < 2) continue;
            
            NSInteger pid = [cols[1] integerValue];
            if (pid <= 0 || pid >= INT_MAX) continue;
            
            NSString* lsofP = runTask(@"/bin/bash", NSHomeDirectory(), @[ @"-c", [NSString stringWithFormat:@"lsof -p %d | grep cwd", (int)pid] ]);
            cols = [[lsofP componentsSeparatedByCharactersInSet:whitespace] mutableCopy];
            [cols removeObject:@""];
            
            long N = (long)[cols count];
            if (N <= 2) continue;
            
            NSString* penultimate = cols[N-2];
            NSRange range = [lsofP rangeOfString:penultimate];
            
            long M = (long)[lsofP length];
            if (M <= 2) continue;
            NSString* cwd = [lsofP substringWithRange:NSMakeRange(NSMaxRange(range), [lsofP length] - NSMaxRange(range))];
            cwd = [cwd stringByTrimmingCharactersInSet:whitespace];
            NSLog(@"cwd = %@", cwd);
        }
    }
    
//    TerminalTab* tab = [term doScript:cmd in:nil];
//    tab.selected = true;
}
@end

@implementation iTermTerminal
@synthesize projectDir, workingDir;
- (void)runCommand:(NSString*)cmd {
	iTerm2ITermApplication *term = [SBApplication applicationWithBundleIdentifier:@"com.googlecode.iterm2"];
    [term activate];

//    TerminalTab* tab = [term doScript:cmd in:nil];
//    tab.selected = true;
}
@end

/*
class iTermTerminal: GenericTerminal {
    func runCommand(cmd: String) {
        let term = SBApplication(bundleIdentifier: "com.googlecode.iterm2") as! iTerm2ITermApplication
        term.activate()

//        term.doScript(cmd, `in`: nil)
    }
}*/


/*
class JobsScheduler: NSObject {
    static let shared = JobsScheduler()
    var preferedTerm: GenericTerminal? = nil
    
    override init() {
        self.preferedTerm = AppleTerminal()
    }
    func runCommand(cmd: String) {
        self.preferedTerm?.runCommand(cmd)
    }
}
*/