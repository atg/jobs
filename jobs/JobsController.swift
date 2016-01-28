import Cocoa

class JobsController: NSObject {

    @IBOutlet var win: NSWindow!
    @IBOutlet weak var cmdField: NSTextField!
    @IBOutlet weak var dirField: NSTextField!
    
    @IBAction func cmdField(sender: NSTextField) {
        let cmd = cmdField.stringValue
        print(cmd)
        JobsScheduler.shared.runCommand(cmd, dirField.stringValue, dirField.stringValue)
    }
}
