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

NSString* AppleTerminalTabDescriptionSubstring(id s) {
    return [[s description] substringFromIndex:29];
}

@implementation AppleTerminal {
    NSMutableDictionary* tabCwdMap;
    NSMutableArray* tabCwdList;
}
@synthesize projectDir, workingDir;

- (NSString*)cwdForTTY:(NSString*)tty {
    NSCharacterSet* whitespace = whitespaceCharset();
    NSString* ttyNoDev = [tty stringByReplacingOccurrencesOfString:@"/dev/" withString:@""];
    
    NSString* psF = runTask(@"/bin/bash", NSHomeDirectory(), @[ @"-c", [NSString stringWithFormat:@"ps -f | grep bash | grep %@", ttyNoDev] ]);
    
    NSMutableArray* cols = [[psF componentsSeparatedByCharactersInSet:whitespace] mutableCopy];
    [cols removeObject:@""];
    if ([cols count] < 2) return nil;
    
    NSInteger pid = [cols[1] integerValue];
    if (pid <= 0 || pid >= INT_MAX) return nil;
    
    NSString* lsofP = runTask(@"/bin/bash", NSHomeDirectory(), @[ @"-c", [NSString stringWithFormat:@"lsof -p %d | grep cwd", (int)pid] ]);
    cols = [[lsofP componentsSeparatedByCharactersInSet:whitespace] mutableCopy];
    [cols removeObject:@""];
    
    long N = (long)[cols count];
    if (N <= 2) return nil;
    
    NSString* penultimate = cols[N-2];
    NSRange range = [lsofP rangeOfString:penultimate];
    
    long M = (long)[lsofP length];
    if (M <= 2) return nil;
    NSString* cwd = [lsofP substringWithRange:NSMakeRange(NSMaxRange(range), [lsofP length] - NSMaxRange(range))];
    cwd = [cwd stringByTrimmingCharactersInSet:whitespace];
    return cwd;
}

/*
NSString* tty = tab.tty;
NSString* cwd = [tabCwdMap valueForKey:tty];
if (!cwd) {
    cwd = [self cwdForTTY:tty];
    NSLog(@"UNSTORED cwd = %@ has %@", tty, cwd);
    [tabCwdMap setValue:cwd ?: [NSNull null] forKey:tty];
    [tabCwdList addObject:tty];
}
else {
    NSLog(@"STORED cwd = %@ has %@", tty, cwd);
}
*/

static BOOL isCaseInsensitiveEqual(NSString* a, NSString* b) {
    if (a == b)
        return YES;
    if (!a || !b)
        return NO;
    return [a caseInsensitiveCompare:b] == 0;
}
- (NSArray*)tabForTerm:(TerminalApplication*)term directories:(NSArray*)dirs {
    // TODO: currently we are searching self.projectDir and not dirs
    
    if (!tabCwdMap) tabCwdMap = [NSMutableDictionary dictionary];
    if (!tabCwdList) tabCwdList = [NSMutableArray array];
    
    // Try to find an old tab with the given directory
    for (TerminalWindow* win in term.windows) {
        for (TerminalTab* tab in win.tabs) {
            if (tab.busy) continue;
            NSString* tty = tab.tty;
            NSString* cwd = tabCwdMap[tty];
            if (!cwd || cwd == (id)[NSNull null]) continue;
            
            if (isCaseInsensitiveEqual(cwd, self.projectDir)) {
                NSLog(@"STORED cwd = %@ has %@", tty, cwd);
                return @[ win, tab ];
            }
        }
    }
    
    // Clear the caches, we didn't find anything and have to research.
    tabCwdMap = [NSMutableDictionary dictionary];
    tabCwdList = [NSMutableArray array];
    
    // Iterate over the windows and tabs
    for (TerminalWindow* win in term.windows) {
        for (TerminalTab* tab in win.tabs) {
            if (tab.busy) continue;
            NSString* tty = tab.tty;
            NSString* cwd = [self cwdForTTY:tty];
            NSLog(@"UNSTORED cwd = %@ has %@", tty, cwd);
            [tabCwdMap setValue:cwd ?: [NSNull null] forKey:tty];
            [tabCwdList addObject:tty];
            
            if (isCaseInsensitiveEqual(cwd, self.projectDir)) {
                NSLog(@"STORED cwd = %@ has %@", tty, cwd);
                return @[ win, tab ];
            }
        }
    }
    
    return nil;
}

static NSString* bashQuote(NSString* cmd) {
    return [NSString stringWithFormat:@"'%@'", cmd];
}
- (void)runCommand:(NSString*)cmd {
	TerminalApplication *term = [SBApplication applicationWithBundleIdentifier:@"com.apple.Terminal"];
    [term activate];
    
    self.projectDir = [self.projectDir stringByExpandingTildeInPath];
    self.projectDir = [self.projectDir stringByResolvingSymlinksInPath];
    
    self.workingDir = [self.workingDir stringByExpandingTildeInPath];
    self.workingDir = [self.workingDir stringByResolvingSymlinksInPath];
    
    TerminalWindow* win = nil;
    TerminalTab* tab = nil;
    
    NSArray* winAndTab = [self tabForTerm:term directories:nil];
    if ([winAndTab count] == 2) {
        win = winAndTab[0];
        tab = winAndTab[1];
    }
    else {
        cmd = [NSString stringWithFormat:@"cd %@ && %@", bashQuote(self.workingDir), cmd];
    }
    
    TerminalTab* outTab = [term doScript:cmd in:tab];
    outTab.selected = true;
    
    if (outTab != tab) {
        BOOL isBroken = NO;
        for (TerminalWindow* outWinCandidate in term.windows) {
            for (TerminalTab* outTabCandidate in outWinCandidate.tabs) {
                if (isCaseInsensitiveEqual(outTabCandidate.tty, outTab.tty)) {
                    win = outWinCandidate;
                    isBroken = YES;
                    break;
                }
            }
            if (isBroken)
                break;
        }
    }
    
    win.frontmost = YES;
//    NSLog(@"outtab = %@ %@, %d", outTab.tty, win, win.frontmost);
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