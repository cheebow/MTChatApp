//
//  ViewController.swift
//  ChatApp
//
//  Created by CHEEBOW on 2016/02/15.
//  Copyright © 2016年 CHEEBOW. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import MTDataAPI_SDK
import SwiftyJSON
import SDWebImage

class ViewController: JSQMessagesViewController {
    var messages: [JSQMessage]?
    var avatars: [String: JSQMessagesAvatarImage]?
    var incomingBubble: JSQMessagesBubbleImage!
    var outgoingBubble: JSQMessagesBubbleImage!
    
    let api = DataAPI.sharedInstance
    
    let ENDPOINT    = "http://localhost/cgi-bin/MT-6.1/mt-data-api.cgi"
    let USERNAME    = "hoge"
    let PASSWORD    = "mogemoge"
    let SITE_ID     = "2"
    let ENTRY_ID    = "388"
    let SENDER_ID   = "3"
    let SENDER_NAME = "HOGE"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        api.APIBaseURL = ENDPOINT

        self.inputToolbar?.contentView?.leftBarButtonItem = nil
        
        self.senderId = SENDER_ID
        self.senderDisplayName = SENDER_NAME
        
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        self.incomingBubble = bubbleFactory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
        self.outgoingBubble = bubbleFactory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleGreenColor())
        
        self.messages = []
        self.avatars = [String: JSQMessagesAvatarImage]()
     
        self.receiveMessage()
        NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "receiveMessage", userInfo: nil, repeats: true)
        
        self.inputToolbar?.contentView?.textView?.becomeFirstResponder()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
        
        var comment = [String:String]()
        comment["body"] = text

        self.inputToolbar?.contentView?.rightBarButtonItem?.enabled = false
        
        self.api.authentication(USERNAME, password: PASSWORD, remember: true,
            success:{_ in
                self.api.createCommentForEntry(
                    siteID: self.SITE_ID,
                    entryID: self.ENTRY_ID,
                    comment: comment,
                    
                    success: {(result: JSON!)-> Void in
                        self.inputToolbar?.contentView?.rightBarButtonItem?.enabled = true
                        self.finishSendingMessageAnimated(true)
                        self.receiveMessage()
                    },
                    failure: {(error: JSON!)-> Void in
                        self.inputToolbar?.contentView?.rightBarButtonItem?.enabled = true
                    }
                )
            },
            failure: {(error: JSON!)-> Void in
                self.inputToolbar?.contentView?.rightBarButtonItem?.enabled = true
            }
        )
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
        return self.messages?[indexPath.item]
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = self.messages?[indexPath.item]
        if message?.senderId == self.senderId {
            return self.outgoingBubble
        }
        return self.incomingBubble
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        if let message = self.messages?[indexPath.item] {
            return self.avatars?[message.senderId]
        }
        
        return JSQMessagesAvatarImage(placeholder: UIImage())
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (self.messages?.count)!
    }
    
    private func messagesFromJSON(items: [JSON]) {
        self.messages?.removeAll()
        for item in items {
            let author = item["author"]
            let id = author["id"].stringValue
            let name = author["displayName"].stringValue
            let text = item["body"].stringValue
            let message = JSQMessage(senderId: id, displayName: name, text: text)
            self.messages?.append(message)
            
            if self.avatars?[id] == nil {
                if let endpointUrl = NSURL(string: self.ENDPOINT) {
                    let scheme = endpointUrl.scheme
                    let host = endpointUrl.host!
                    let pictUrl = scheme + "://" + host + author["userpicUrl"].stringValue
                    let avatar = JSQMessagesAvatarImage(placeholder: UIImage())
                    SDWebImageDownloader.sharedDownloader().downloadImageWithURL(NSURL(string: pictUrl), options: .UseNSURLCache, progress: nil, completed: {(image, data, error, finished) in
                        avatar.avatarImage = JSQMessagesAvatarImageFactory.circularAvatarHighlightedImage(image, withDiameter: 64)
                    })
                    self.avatars?[id] = avatar
                }
            }
        }
        self.messages = self.messages?.reverse()
        self.finishReceivingMessageAnimated(true)
    }
    
    func receiveMessage() {
        let options = [
            "limit":"100",
            "no_text_filter":"1",
            "fields":"author,body"
        ]

        self.api.authentication(USERNAME, password: PASSWORD, remember: true,
            success:{_ in
                self.api.listCommentsForEntry(
                    siteID: self.SITE_ID,
                    entryID: self.ENTRY_ID,
                    options: options,
                    
                    success: {(items:[JSON]!, total:Int!)-> Void in
                        self.messagesFromJSON(items)
                    },
                    failure: {(error: JSON!)-> Void in
                    }
                )
            },
            failure: {(error: JSON!)-> Void in
            }
        )
    }
}

