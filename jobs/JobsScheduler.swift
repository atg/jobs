import Cocoa
/*
protocol GenericTerminal {
    func runCommand(cmd: String)
}
class AppleTerminal: GenericTerminal {
    func runCommand(cmd: String) {
        let term = SBApplication(bundleIdentifier: "com.apple.Terminal") as! TerminalApplication
        term.activate()

        let tab: TerminalTab = term.doScript(cmd, `in`: nil)
        tab.selected = true
    }
}
class iTermTerminal: GenericTerminal {
    func runCommand(cmd: String) {
        let term = SBApplication(bundleIdentifier: "com.googlecode.iterm2") as! iTerm2ITermApplication
        term.activate()

//        term.doScript(cmd, `in`: nil)
    }
}*/

class JobsScheduler: NSObject {
    static let shared = JobsScheduler()
    var preferedTerm: GenericTerminal? = nil
    
    override init() {
        self.preferedTerm = AppleTerminal()
    }
    func runCommand(cmd: String, _ projectDir: String, _ workingDir: String) {
        let term = self.preferedTerm
        term?.projectDir = projectDir
        term?.workingDir = workingDir
        term?.runCommand(cmd)
    }
}
