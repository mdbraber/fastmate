var Fastmate = {

    allMailboxes: {},
    shouldColorizeMessageItems: true,
    
    simulateKeyPress: function(key) {
        var e = new Event("keydown");
        e.key = key;
        e.keyCode = e.key.charCodeAt(0);
        e.which = e.keyCode;
        e.altKey = false;
        e.ctrlKey = false;
        e.shiftKey = false;
        e.metaKey = false;
        e.bubbles = true;
        document.dispatchEvent(e);
    },

    compose: function() {
        Fastmate.simulateKeyPress("c");
    },

    focusSearch: function() {
        Fastmate.simulateKeyPress("/");
    },

    getToolbarColor: function() {
        var toolbar = document.getElementsByClassName("v-PageHeader")[0];
        var style = window.getComputedStyle(toolbar);
        var color = style.getPropertyValue('background-color');
        return color;
    },

    getMailboxUnreadCounts: function() {
        var mailboxes = document.getElementsByClassName("v-MailboxSource");
        var result = {};
        for (var i = 0; i < mailboxes.length; ++i) {
            var mailbox = mailboxes[i];
            var labelElement = mailbox.getElementsByClassName("app-source-name")[0];
            var badgeElement = mailbox.getElementsByClassName("v-MailboxSource-badge")[0];
            var name = labelElement.innerHTML;
            var count = 0;
            if (badgeElement) {
                var c = parseInt(badgeElement.innerHTML);
                count = isNaN(c) ? 0 : c;
            }
            result[name] = count;
        }
        return result;
    },

    updateStylesheet: function() {
        if (Fastmate.shouldColorizeMessageItems) {
            document.styleSheets[0].insertRule(".v-MailboxItem .is-focused { background-color: #ebebeb !important; }");
        }
    },
    
    colorizeMessageItems: function() {
        if (Fastmate.shouldColorizeMessageItems) {
            mailboxName = FastMail.mail.getFromPath("mailbox").displayName();
            if (mailboxName != "Inbox") {
                mailboxBackgroundColor = document.querySelector('a.app-source.app-source--depth0[href*="/mail/'+mailboxName+'"]').childNodes[0].childNodes[0].style.fill;
            } else {
                mailboxBackgroundColor = null;
            }

            document.querySelectorAll('.v-MailboxItem').forEach((item) => {
                firstLabel = item.querySelector('.v-MailboxItem-mailboxes .v-MailboxItem-label');
                if(firstLabel && firstLabel.title != "Inbox") {
                    if (firstLabel.style.backgroundColor != "rgb(255, 255, 255)") {
                        firstLabel.style.originalBackgroundColor = firstLabel.style.backgroundColor
                    }
                    item.style.backgroundColor = firstLabel.style.originalBackgroundColor;
                    firstLabel.style.backgroundColor = "rgb(255, 255, 255)";
                } else if (mailboxName != "Inbox" && mailboxBackgroundColor) {
                    item.style.backgroundColor = mailboxBackgroundColor;
                } else {
                    item.style.backgroundColor = null;
                }
            })
        }
    },
    
    setColorizeMessageItems: function(colorize) {
        Fastmate.shouldColorizeMessageItems = colorize;
        if(colorize) {
            Fastmate.colorizeMessageItems();
        } else {
            document.querySelectorAll('.v-MailboxItem').forEach((item) => {
                item.style.backgroundColor = "rgb(255, 255, 255)";
                firstLabel = item.querySelector('.v-MailboxItem-mailboxes .v-MailboxItem-label');
                if(firstLabel) {
                    firstLabel.style.backgroundColor = firstLabel.style.originalBackgroundColor;
                }
            })
        }
        FastMail.views.mailbox.redraw();
    },
    
    toggleLabel: function(mailboxName) {
        mailboxes = FastMail.mail.message.get("mailboxes").map(function(key) { return key.displayName() });
        if (mailboxes.contains(mailboxName)) {
            FastMail.mail.actions.remove(null, Fastmate.allMailboxes[mailboxName]);
        } else {
            FastMail.mail.actions.add(null, Fastmate.allMailboxes[mailboxName]);
        }
        Fastmate.allMailboxes[mailboxName].propertyDidChange("tristate");
        O.RunLoop.flushAllQueues();
    },
    
    addLabelShortcuts: function() {
        JMAP.mail.get("store").getQuery('rootMailboxes', O.LocalQuery, { Type: JMAP.Mailbox }).get('[]').map(function(key) { Fastmate.allMailboxes[key.displayName()] = key; });

        // Example - add a Label named "Personal" (labels must have unique names)
        FastMail.mail.actions.toggleLabelPersonal = function(){Fastmate.toggleLabel("Personal")}
        FastMail.keyboardShortcuts.register('Shift-P', FastMail.mail.actions, 'toggleLabelPersonal');
    },
    
    hideSidebar: function() {
        document.querySelector(".v-Split--left").style.display = "none";
        document.querySelector(".v-Split--right").style.left = "0";
        
    },
        
    notificationClickHandlers: {}, // notificationID -> function

    handleNotificationClick: function(id) {
        var handler = Fastmate.notificationClickHandlers[id]();
        if (handler) handler();
    },
    
    adjustV67Width: function() {
        document.getElementById("v67").style.maxWidth = "100%";
    },
};

// Catch the print function so we can forward it to PrintManager
print = function() { window.webkit.messageHandlers.Fastmate.postMessage("print"); };

/**
 Web Notification observering

 Since Web Notifications are not natively supported by WKWebView, we hook into the
 notification function and post a webkit message handler instead.

 We also set the notification permission to 'granted' since WKWebView doesn't
 have a built in way to ask for permission.
*/
var originalNotification = Notification;
var notificationID = 0;
Notification = function(title, options) {
    ++notificationID;
    var n = new originalNotification(title, options);
    Object.defineProperty(n, "onclick", { set: function(value) { Fastmate.notificationClickHandlers[notificationID.toString()] = value; }});
    window.webkit.messageHandlers.Fastmate.postMessage('{"title": "' + title + '", "options": ' + JSON.stringify(options) + ', "notificationID": ' + notificationID + '}');
    return n;
}

Object.defineProperty(Notification, 'permission', { value: 'granted', writable: false });


/**
 Observe changes to the DOM
 */
var DOMObserver = new MutationObserver(function(mutation) { window.webkit.messageHandlers.Fastmate.postMessage('documentDidChange'); });
var config = {
    attributes: true,
    characterData: true,
    childList: true,
    subtree: true,
};
DOMObserver.observe(document, config);
