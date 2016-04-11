//
//  ViewController.swift
//  VideoSampleCaptureRender
//
//  Created by Piyush Tank on 3/10/16.
//  Copyright © 2016 Twilio. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITextFieldDelegate {
    
    // Twilio Access Token - Generate a demo Access Token at https://www.twilio.com/user/account/video/dev-tools/testing-tools
    let twilioAccessToken = "TWILIO_ACCESS_TOKEN";
    
    // Storyboard's outlets
    @IBOutlet weak var statusMessage: UILabel!
    @IBOutlet weak var inConversationsButtonsContainer: UIView!
    
    @IBOutlet weak var inviteParticipantButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    
    // Key Twilio ConversationsClient SDK objects
    var client: TwilioConversationsClient?
    var localMedia: TWCLocalMedia?
    var camera: TWCCameraCapturer?
    var conversation: TWCConversation?
    var outgoingInvite: TWCOutgoingInvite?
    var remoteVideoRenderer: TWCVideoViewRenderer?
    
    // Video containers used to display local camera track and remote Participant's camera track
    var localVideoContainer: UIView?
    var remoteVideoContainer: UIView?
    
    // If set to true, the remote video renderer (of type TWCVideoViewRenderer) will not automatically handle rotation of the remote party's video track. Instead, you should respond to the 'renderer:orientiationDidChange:' method in your TWCVideoViewRendererDelegate.
    let applicationHandlesRemoteVideoFrameRotation = false
    
    // ConversationsClient status - used to dynamically update our UI
    enum ConversationsClientStatus: Int {
        case None = 0
        case FailedToListen
        case Listening
        case Connecting
        case Connected
    }
    // Default status to None
    var clientStatus: ConversationsClientStatus = .None
    
    func updateClientStatus(status: ConversationsClientStatus, animated: Bool) {
        self.clientStatus = status
        self.inviteParticipantButton.hidden = true
        
        // Update UI elements when the ConversationsClient status changes
        switch self.clientStatus {
        case .None:
            break
        case .FailedToListen:
            break;
        case .Listening:
            self.inviteParticipantButton.hidden = false
            inConversationsButtonsContainer.hidden = true
            self.view.bringSubviewToFront(self.inviteParticipantButton)
            break;
        case .Connecting:
            //TODO: show spinner
            break;
        case .Connected:
            self.view.endEditing(true)
            inConversationsButtonsContainer.hidden = false
        }
        
        // Update UI Layout, optionally animated
        self.view.setNeedsLayout()
        if animated {
            UIView.animateWithDuration(0.2) { () -> Void in
                self.view.layoutIfNeeded()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // self.view is loaded from Main.storyboard, however the local and remote video containers are created programmatically
        
        // Video containers
        self.remoteVideoContainer = UIView(frame: self.view.frame)
        self.view.addSubview(self.remoteVideoContainer!)
        self.remoteVideoContainer!.backgroundColor = UIColor.blackColor()
        self.localVideoContainer = UIView(frame: self.view.frame)
        self.view.addSubview(self.localVideoContainer!)
        self.localVideoContainer!.backgroundColor = UIColor.blackColor()
        
        // Status message - used to display errors
        self.view.bringSubviewToFront(statusMessage)
        
        // Buttons container view
        self.inConversationsButtonsContainer.backgroundColor = UIColor.clearColor();
        
        // setup local media and preview
        self.setupLocalMedia()
        
        // Start listening for Invites
        self.listenForInvites()
        
        print("\(TwilioConversationsClient.version())");
        
        inConversationsButtonsContainer.hidden = true
        self.view.bringSubviewToFront(inConversationsButtonsContainer);
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // Layout video containers
        self.layoutLocalVideoContainer()
        self.layoutRemoteVideoContainer()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // touch the screen to flip the camera
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
    }
    
    // Pause button
    @IBAction func pauseButtonClicked (sender : AnyObject) {
        if conversation != nil {
            conversation?.disconnect()
        }
    }
    
    // Mute button
    @IBAction func muteButtonClicked (sender : AnyObject) {
        if conversation != nil {
            conversation?.disconnect()
        }
    }
    
    // Disconnect button
    @IBAction func disconnectButtonClicked (sender : AnyObject) {
        if conversation != nil {
            conversation?.disconnect()
        }

    }
    
    // Invite button
    @IBAction func inviteParticipantButtonClicked (sender : AnyObject) {
        let passwordPrompt = UIAlertController(title: "Create Conversation", message: "Identity to invite", preferredStyle: UIAlertControllerStyle.Alert)
        passwordPrompt.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil))
        
        var inviteeTextField: UITextField?
        passwordPrompt.addTextFieldWithConfigurationHandler({(textField: UITextField!) in
            textField.placeholder = "Identity to invite"
            textField.secureTextEntry = true
            inviteeTextField = textField
        })
        passwordPrompt.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            self.inviteParticipant(inviteeTextField!.text!)
            self.inviteParticipantButton.hidden = true
        }))
        presentViewController(passwordPrompt, animated: true, completion: nil)
    }
    
    func layoutLocalVideoContainer() {
        var rect:CGRect! = CGRectZero
        
        // If connected to a Conversation, display a small representaiton of the local video track in the bottom right corner
        if clientStatus == .Connected {
            rect!.size = UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation) ? CGSizeMake(128, 96) : CGSizeMake(96, 128)
            rect!.origin = CGPointMake(self.view.frame.width - rect!.width - 10, self.view.frame.height - rect!.height - 10)
        } else {
            // If not yet connected to a Conversation (e.g. Camera preview), display the local video feed as full screen
            rect = self.view.frame
        }
        self.localVideoContainer!.frame = rect
        
        //reducing the alapha in connectin state
        self.localVideoContainer?.alpha = clientStatus == .Connecting ? 0.25 : 1.0
    }
    
    func layoutRemoteVideoContainer() {
        if clientStatus == .Connected {
            self.remoteVideoContainer!.bounds = CGRectMake(0,0,self.view.frame.width, self.view.frame.height)
            self.remoteVideoContainer!.center = self.view.center
        } else {
            // If not connected to a Conversation, there is no remote video to display
            self.remoteVideoContainer!.frame = CGRectZero
        }
    }
    
    func listenForInvites() {
        assert(self.twilioAccessToken != "TWILIO_ACCESS_TOKEN", "Set the value of the placeholder property 'twilioAccessToken' to a valid Twilio Access Token.")
        let accessManager = TwilioAccessManager(token: self.twilioAccessToken, delegate:nil);
        self.client = TwilioConversationsClient(accessManager: accessManager!, delegate: self);
        self.client!.listen()
    }
    
    func setupLocalMedia() {
        // LocalMedia represents the collection of tracks that we are sending to other Participants from our ConversationsClient
        self.localMedia = TWCLocalMedia()
        
        // Currently, the microphone is automatically captured and an audio track is added to our LocalMedia. However, we should manually create a video track using the device's camera and the TWCCameraCapturer class
        if Platform.isSimulator == false {
            self.camera = self.localMedia?.addCameraTrack()
            self.camera!.videoTrack?.attach(self.localVideoContainer!)
            self.camera!.videoTrack?.delegate = self;
            
            setupLocalPreview()
        }
    }
    
    func setupLocalPreview() {
        self.camera!.startPreview()
        
        // Preview our local camera track in the local video container
        self.localVideoContainer!.addSubview((self.camera!.previewView)!)
        self.camera!.previewView!.frame = self.localVideoContainer!.bounds
        self.camera!.previewView!.contentMode = .ScaleAspectFit
        self.camera!.previewView!.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
    }
    
    func destroyLocalMedia() {
        self.camera?.previewView?.removeFromSuperview()
        self.camera = nil
        self.localMedia = nil
    }
    
    func inviteParticipant(inviteeIdentity: String) {
        if inviteeIdentity.isEmpty == false {
            self.outgoingInvite =
                self.client?.inviteToConversation(inviteeIdentity, localMedia:self.localMedia!) { conversation, err in
                    self.outgoingInviteCompletionHandler(conversation, err: err)
            }
            self.updateClientStatus(.Connecting, animated: false)
        }
    }
    
    func outgoingInviteCompletionHandler(conversation: TWCConversation?, err: NSError?) {
        if err == nil {
            // The invitee accepted our Invite
            self.conversation = conversation
            self.conversation?.delegate = self
        } else {
            // The invitee rejected our Invite or the Invite was not acknowledged
            let alertController = UIAlertController(title: "Oops!", message: "Unable to connect to the remote party.", preferredStyle: .Alert)
            let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in  }
            alertController.addAction(OKAction)
            self.presentViewController(alertController, animated: true) { }
            
            self.destroyLocalMedia()
            self.setupLocalMedia()
            
            // Return to listening state
            self.updateClientStatus(.Listening, animated: false)
            
            self.statusMessage.text = "Unable to connect to the remote party"
        }
    }
}

// MARK: TwilioConversationsClientDelegate
extension ViewController: TwilioConversationsClientDelegate {
    func conversationsClient(conversationsClient: TwilioConversationsClient,
        didFailToStartListeningWithError error: NSError) {
            self.updateClientStatus(.FailedToListen, animated: false)
            
        statusMessage.text = "Conversations client failed to listen for invite"
    }
    
    func conversationsClientDidStartListeningForInvites(conversationsClient: TwilioConversationsClient) {
        // Successfully listening for Invites
        self.updateClientStatus(.Listening, animated: true)
        statusMessage.text = "Conversations client did start to listening for invite"
    }
    
    // Automatically accept any incoming Invite
    func conversationsClient(conversationsClient: TwilioConversationsClient,
        didReceiveInvite invite: TWCIncomingInvite) {
            statusMessage.text = "Conversations client did receive invite"
            
            let alertController = UIAlertController(title: "Incoming Invite!", message: "Invite from \(invite.from)", preferredStyle: .Alert)
            let acceptAction = UIAlertAction(title: "Accept", style: .Default) { (action) in
                // Accept the incoming Invite with pre-configured LocalMedia
                self.updateClientStatus(.Connecting, animated: false)
                invite.acceptWithLocalMedia(self.localMedia!, completion: { (conversation, err) -> Void in
                    if err == nil {
                        self.conversation = conversation
                        conversation!.delegate = self
                    } else {
                        print("Error: Unable to connect to accepted Conversation")
                        // Return to listening state
                        self.updateClientStatus(.Listening, animated: false)
                    }
                })
            }
            alertController.addAction(acceptAction)
            let rejectAction = UIAlertAction(title: "Reject", style: .Cancel) { (action) in
                invite.reject()
            }
            alertController.addAction(rejectAction)
            self.presentViewController(alertController, animated: true) { }
    }
}

// MARK: TWCConversationDelegate
extension ViewController: TWCConversationDelegate {
    func conversation(conversation: TWCConversation, didConnectParticipant participant: TWCParticipant) {
        statusMessage.text = "Participant connected in the conversation"

        // Remote Participant connected
        participant.delegate = self
    }
    
    func conversationEnded(conversation: TWCConversation) {
        statusMessage.text = "Conversation ended"

        self.conversation = nil
        self.destroyLocalMedia()
        
        // Create a new instance of LocalMedia and use it when returning to the listening (preview) state
        self.setupLocalMedia()
        self.updateClientStatus(.Listening, animated: true)
    }
}

// MARK: TWCParticipantDelegate
extension ViewController: TWCParticipantDelegate {
    func participant(participant: TWCParticipant, addedVideoTrack videoTrack: TWCVideoTrack) {
        videoTrack.attach(self.remoteVideoContainer!)
        self.statusMessage.text = "Remote Participant added their video track"
        self.view.setNeedsLayout()
        self.updateClientStatus(.Connected, animated: true)
    }
    
    func participant(participant: TWCParticipant, removedVideoTrack videoTrack: TWCVideoTrack) {
        // Remote Participant removed their video track
        self.statusMessage.text = "Remote Participant removed their video track"
        videoTrack.detach(self.remoteVideoContainer!)
        self.view.setNeedsLayout()
    }
}

// MARK: TWCLocalMediaDelegate
extension ViewController: TWCLocalMediaDelegate {
    func localMedia(media: TWCLocalMedia, didAddVideoTrack videoTrack: TWCVideoTrack) {
        self.statusMessage.text = "Video track added to local media"
    }
    
    func localMedia(media: TWCLocalMedia, didRemoveVideoTrack videoTrack: TWCVideoTrack) {
        self.statusMessage.text = "Video track removed from local media"

    }
    func localMedia(media: TWCLocalMedia, didFailToAddVideoTrack videoTrack: TWCVideoTrack, error: NSError) {
        // Called when there is a failure attempting to add a local video track to LocalMedia. In this application, it is likely to be caused when capturing a video track from the device camera using invalid video constraints.
        print("Error: failed to add a local video track to LocalMedia.")
    }
}

// MARK: TWCVideoTrackDelegate
extension ViewController : TWCVideoTrackDelegate {
    func videoTrack(track: TWCVideoTrack, dimensionsDidChange dimensions: CMVideoDimensions) {
        if (track == self.camera?.videoTrack) {
            self.statusMessage.text = "Local video track dimension changed"
        } else {
            self.statusMessage.text = "Remote video track dimension changed"
        }
    }
}
