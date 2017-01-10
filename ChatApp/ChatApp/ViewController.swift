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
    
    let ENDPOINT    = "http://localhost/cgi-bin/MT/mt-data-api.cgi"
    let USERNAME    = "hoge"
    let PASSWORD    = "mogemoge"
    let SITE_ID     = "1"
    let ENTRY_ID    = "3"
    let SENDER_ID   = "2"
    let SENDER_NAME = "HOGE"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        api.APIBaseURL = ENDPOINT

        inputToolbar?.contentView?.leftBarButtonItem = nil
        
        senderId = SENDER_ID
        senderDisplayName = SENDER_NAME
        
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        incomingBubble = bubbleFactory?.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
        outgoingBubble = bubbleFactory?.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleGreen())
        
        messages = []
        avatars = [String: JSQMessagesAvatarImage]()
     
        receiveMessage()
        Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(ViewController.receiveMessage), userInfo: nil, repeats: true)
        
        inputToolbar?.contentView?.textView?.becomeFirstResponder()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        var comment = [String:String]()
        comment["body"] = text

        inputToolbar?.contentView?.rightBarButtonItem?.isEnabled = false
        
        api.authentication(USERNAME, password: PASSWORD, remember: true,
            success:{_ in
                self.api.createCommentForEntry(
                    siteID: self.SITE_ID,
                    entryID: self.ENTRY_ID,
                    comment: comment,
                    
                    success: {(result: JSON?)-> Void in
                        self.inputToolbar?.contentView?.rightBarButtonItem?.isEnabled = true
                        self.finishSendingMessage(animated: true)
                        self.receiveMessage()
                    },
                    failure: {(error: JSON?)-> Void in
                        self.inputToolbar?.contentView?.rightBarButtonItem?.isEnabled = true
                    }
                )
            },
            failure: {(error: JSON?)-> Void in
                self.inputToolbar?.contentView?.rightBarButtonItem?.isEnabled = true
            }
        )
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages?[indexPath.item]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages?[indexPath.item]
        if message?.senderId == self.senderId {
            return self.outgoingBubble
        }
        return self.incomingBubble
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        if let message = messages?[indexPath.item] {
            return avatars?[message.senderId]
        }
        
        return JSQMessagesAvatarImage(placeholder: UIImage())
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (self.messages?.count)!
    }
    
    fileprivate func messagesFromJSON(_ items: [JSON]) {
        messages?.removeAll()
        for item in items {
            let author = item["author"]
            let id = author["id"].stringValue
            let name = author["displayName"].stringValue
            let text = item["body"].stringValue
            let message = JSQMessage(senderId: id, displayName: name, text: text)
            messages?.append(message!)
            
            if avatars?[id] == nil {
                if let endpointUrl = NSURL(string: ENDPOINT) {
                    let scheme = endpointUrl.scheme
                    let host = endpointUrl.host!
                    let pictUrl = scheme! + "://" + host + author["userpicUrl"].stringValue
                    let avatar = JSQMessagesAvatarImage(placeholder: UIImage())
                    SDWebImageDownloader.shared().downloadImage(with: NSURL(string: pictUrl) as URL!, options: .useNSURLCache, progress: nil, completed: {(image, data, error, finished) in
                        avatar?.avatarImage = JSQMessagesAvatarImageFactory.circularAvatarHighlightedImage(image, withDiameter: 64)
                    })
                    avatars?[id] = avatar
                }
            }
        }
        messages = messages?.reversed()
        finishReceivingMessage(animated: true)
    }
    
    func receiveMessage() {
        let options = [
            "limit":"100",
            "no_text_filter":"1",
            "fields":"author,body"
        ]

        api.authentication(USERNAME, password: PASSWORD, remember: true,
            success:{_ in
                self.api.listCommentsForEntry(
                    siteID: self.SITE_ID,
                    entryID: self.ENTRY_ID,
                    options: options,
                    
                    success: {(items:[JSON]?, total:Int?)-> Void in
                        guard let items = items else { return }
                        self.messagesFromJSON(items)
                    },
                    failure: {(error: JSON?)-> Void in
                    }
                )
            },
            failure: {(error: JSON?)-> Void in
            }
        )
    }
}

