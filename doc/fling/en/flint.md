## Overview
Flint Service includes Discovery Service, Rest Service and WebSocket Service. DIAL protocol is implemented in Flint to provide the 2nd screen application also called sender application to discover and launch the 1st screen application also called receiver application. The sender application is playing the role of DIAL client, and the Discovery Service and Rest Service are playing the role of DIAL server.

## Flint Discovery Service
Flint Discovery Service supports SSDP protocol which is defined in DIAL protocol, and also implements mDNS discovery protocol.
* SSDP: Details for SSDP please refer to Reference [1] Section 5.
* mDNS: mDNS will respond to the request with search name as `openflint` and return the URL address and port of DIAL Server. Details for mDNS please refer to Reference [2].

## Flint Rest Service
Flint Rest Service provide interfaces for a sender application to query, launch and stop a receiver application, which is defined in DIAL protocol spec, and Flint Rest Service provides more and flexible extension interfaces atop the standard DIAL protocol for sender application and receiver application.

![Flint Architecture Chart](http://openflint.github.io/assets/images/flint-protocol-overview.png)

### API
* `/apps/<appid>`: Standard DIAL HTTP interface; requested by the sender application
* `/apps/<appid>/dial_data`: Standard DIAL HTTP Interface for receiver application to send additional data to DIAL server; requested by receiver application
* `/apps/~<appid>`: Extension HTTP interface; requested by the sender application
* `/system/control`: Extension HTTP interface for system control, currently only support volume control; requested the sender application
* `/receiver/~<appid>`: Extension WebSocket interface for receiver application to establish Message Channel to DIAL server; requested by receiver application
> Flint Rest Service will check `appid` from URL and apply different treatment:
    - `~<appid>`: Follow the extension of DIAL protocol in Flint Rest Service, all **extension** related descriptions in following paragraphs are only target to `~<appid>` applications.
    - `<appid>`: Follow the standard DIAL protocol and register application configuration information to DIAL server.

### Get Receiver Application Status
* HTTP `GET` Request
    * Sender application sends `GET` request to `/apps/<appid>` or `/apps/~<appid>`
    * Details for this part please refer to References [1] Section 6.1
* HTTP Response
    * Rest Service sends response to sender application for the status of receiver application
    * Details for this part please refer to References [1] Section 6.1
* Extension
    * Currently Flint Reset service not support receiver application in `installable` status
    * Flint adds a `starting` status. If HTTP status code return is 200, it means that the receiver application is in `starting` phase, then sender application should repeat a query cycle (cycle time is 10 seconds) and wait for the receiver application to launch. Sender application should judge that receiver application launch failed if the status has not been changed to `running` status after several cycles.
    * If sender application wants to keep the connection with Rest Service after application launched, sender application needs to send `ping`/`pong` message. Because Flint Rest Service is based on HTTP stateless connection, sender application needs to send `GET` request to Flint service regularly (1-5 seconds) and fill Authorization field in HTTP request header, the value should be acquired from the Rest Service response to the HTTP 'POST' request of launching receiver application described in next section.

### Launching Receiver Application
* HTTP `POST` request
    * Sender application sends `POST` request to Rest Service to launch receiver application
    * Details for this part please refer to References [1] Section 6.2
* HTTP response
    * Details for this part please refer to References [1] Section 6.2
* Extension
    * POST request will send 3 different commands: launch, relaunch and join.
        * `launch`: If the receiver application status is `stopped`, the receiver application can be launched with this command, and the `POST` message body should contain the information about the receiver application to be launched
        * `relaunch`: If the receiver application status is `running` or `starting`, the receiver application can be stopped and then relaunched with this command, and message body should contain the information of the receiver application to be launched. The result of application relaunch depends on whether the implementation and configuration of each application support to relaunch. 
        * `join`: If the receiver application status is `running` or `starting`, the sender application will send `join` command to add itself to the session management of Rest Service, and will affect the running or starting receiver application.
    * Response will return some information related to session management.
        * token: Flint service creates a session for the sender application who send request, and other request from the sender application needs contain the token. In order to guarantee the token is always valid, the sender application need send `GET` request with the token to Flint Service regularly.
        * interval:  It defines the interval between the `GET` request sent from sender application, unit is millisecond.
    * Please refer to [Annex B] for message format definition.

### Stop Receiver Application
* request: Please refer to References [1] Section 6.4
* response: Please refer to References [1] Section 6.4
* extension: Flint Rest Service provides 2 interfaces to handle DELTE message:
    * `/apps/~<appId>`: http request header need contain token and request to disconnect the session with Flint Service. Since that, Flint service will not manage the session related to this token.
    * `/apps/~<appId>/<instance>`: http request header need contain token and request to stop this application. If the session related to this token is valid, the application can be stopped.
    * Message format can refer to [Annex C]

* System Control Interface
Flint Rest Service provides this interface to support sender application can do system control, now supports volume adjustment. Message format can refer to [Annex D]

## Standard Handle POST request from receiver application
* Details for the `POST` request please refer to Reference [1] Section 6.3.1

### Extension: Communication with receiver application

Flint Service communicates with receiver application via WebSocket. Rest Service provides a WebSocket serve for receiver application to connect this WebSocket server as a client. Please refer to [Annex E] for the specified message format.

* `register`: After receiver application connects to the WebSocket server, it need send `register` message to Flint Service to indicate the receiver application launched successfully.
* `registerok`: After Flint Service gets `register` message, it will return `registerok` to notify receiver application that register is successful and return some information of Flint Service to the receiver application.
* `startHeartbeat`: After register process is completed, Flint Service will notify the receiver application to start heart beat. Then Flint Service will send `ping` message to receiver application regularly and receiver application need send response `pong` message. If receiver application need monitor the heart beat status initiatively, it can send `ping` message to Flint Service and Flint Service will send `pong` message accordingly.
* `senderconnected`: After a sender application creates a session via `POST` request, Flint Service will send a `senderconnected` message to receiver application and transfer the sender application’s token together. Receiver application can manage the sender application session Id through this message.
* `senderdisconnected`: After sender application’s session is disconnected, Flint service will send a `senderdisconnected` message to receiver application and transfer the sender application’s token together. Receiver application can manage the sender application session Id through this message.
* `additionaldata`: 
* `unregister`: When receiver application can send `unregister` message to disconnect the WebSocket connection.

======

## Build-in WebSocket Communication Facility

Flint Service provides WebSocket Server as internal communication facility to sender and receiver. Application developers can use it conveniently to transfer data between the receiver application and sender application.

* WebSocket Server
    * The receiver application can create one or more communication channels via WebSocket Server with Sender application.
    * After all these communication channels are created by the receiver application successfully, these information will be sent to Flint Service via `additionaldata` and Flint service then forwards to sender application. After sender application receives the channel address and add its token, it could communicate with the receiver application.
    * Multiple sender applications can connect to one communication channel in the same time.
    * Please refer to [Annex F] for Websocket Server API. 

## Reference
1. DIAL: (http://www.dial-multiscreen.org/dial-protocol-specification/DIAL-2ndScreenProtocol-1.7.pdf)  
2. MDNS: (http://www.multicastdns.org)  
3. DIAL Registry: (http://www.dial-multiscreen.org/dial-registry/namespace-database)

## Annex
### **A. appid**
* `~<appid>`：Developers need add ~ as prefix for their applicaitons if they need the support from Flint Service
* `<appid>`：Please refer to References [3]

### **B. Launch Receiver Application**
* request

```
POST http://192.168.1.1:9431/apps/~appid
Content-Type: application/json
{
    "type":"launch/relaunch/join",
    "app_info":{
        "url":"http://www.youtube.com",
        "useIpc":true or false, # whether sender and receiver apps use WebSocket Server to communicate
        "maxInactive":n # millisecond, receiver app alive time, only work when useIpc is false,  set -1 if keep receiver app alive
    }
}
```

* response
```
# If Receiver app launched by request, will send: 
201 CREATE
Content-Type: application/json

{
    "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
    "interval":3*1000 #ping/pong interval
}
```

```
# If receiver app already running, will send:
200 OK

Content-Type: application/json
{
    "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
    "interval":3*1000 #ping/pong interval
}
```

### **C. Stop Receiver Application**
* request

```
DELETE http://ip:port/apps/~appid
Authorization: EE2287DB-D10D-FECD-667B-8342AD095C33
```

Or

```
DELETE http://ip:port/apps/~appid/{instance}
Authorization: EE2287DB-D10D-FECD-667B-8342AD095C33
```

* response

```
#If successful, response:
200 OK
```

```
# If failed, If reason is token out of date, response:
400 Bad Request

# If reason is appid invalid, response:
404 Not Found
```

### **D. system control**
* request

```
POST http://ip:port/system/control
Content-Type: application/json

{
    "type":"GET_VOLUME | SET_VOLUME | GET_MUTED | SET_MUTED",
    "level": 0.5, # Available if if type is SET_VOLUME
    "muted": false # Available if type is SET_MUTED
}
```

* response

```
200 OK
Content-Type: application/json

{
    "success": true, # boolean
     "type":"GET_VOLUME | SET_VOLUME | GET_MUTED | SET_MUTED",
     "level": 0.5, #float, volume
     "muted": false #boolean
}
```

### **E. Receiver application register to Flint Service**

* WebSocket URL: **`ws://127.0.0.1:9431/receiver/~<appid>`**

* `register`：Receiver -> Flint service

```
    {
        "type":"register",
        "appid":"~appid"
    }
```

* `unregister`: Receiver -> Flint Service

```
    {
        "type":"unregister",
        "appid":"~appid"
    }
```

* `additionaldata`：Receiver -> Flint Service

```
    {
        "type":"additionaldata",
        "appid":"~appid",
        "additionaldata":{
            "key1":"value1"
        }
    }
```

* `startHeartbeat`：Flint Service -> Receiver

```
    {
        "type":"startHeartbeat",
        "appid":"~appid",
        "interval":3*1000 # ping/pong interval
    }
```

* `senderconnected`：Flit Service -> Receiver

```
    {
        "type":"senderconnected",
        "appid":"~appid",
        "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
    }
```

* `senderdisconnected`：Flint Service -> Receiver

```
    {
        "type":"senderdisconnected",
        "appid":"~appid",
        "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
    }
```

* `ping/pong`：Flint Service <-> Receiver

```
    {
        "type":"heartbeat",
        "appid":"~appid",
        "heartbeat":"ping/pong"
    }
```

### **F. WebSocket Server API**
* Receiver application create WebSocket message channel, URL: `ws://localhost:9439`

```
var ws_A = new WebSocket("ws://127.0.0.1:9439/channels/" + channelNameA);
ws_A.onmessage = function (event) {
    var msg = JSON.parse(event.data);
    // Handle new sender connected event
    if (msg.type === 'senderConnected') {
        console.log('senderId:', msg.senderId);
    // Handle sender lost event
    } else if (msg.type === 'senderDisconnected') {
        console.log('senderId:', msg.senderId);
    // Handle other message
    } else if (msg.type === 'message') {
        console.log('senderId:', msg.senderId);
        console.log('data:', msg.data);
    }
};
ws_A.send(
    {
        "senderId": "xxx", # Indicate which sender to send, if senderId is *:*, mean broadcast to senders
        "data": "string" # string
    }
);

var ws_B = new WebSocket("ws://127.0.0.1:9439/channels/" + channelNameB); # multiple message channel is allowed 
```

* Receiver Application send addtionaldata to Flint Service

```
ws.send(
    {
        "channelNameA": "ws://127.0.0.1:9439/channels/channelNameA",
        "channelNameB": "ws://127.0.0.1:9439/channels/channelNameB"
    }
);
```

* Flint Service send additionaldata to sender application

```
    <additionaldata>
        <channelNameA>ws://127.0.0.1:9439/channels/channelNameA</channelNameA>
        <channelNameB>ws://127.0.0.1:9439/channels/channelNameB</channelNameB>
    </additionaldata>
```

* Sender Connect to Message Channel

When sender application get the URL of Message Channel from additionaldata, should connect them with a unique token:

```
    Receive URL: ws://127.0.0.1:9439/channels/channelName
    Connect URL: ws://127.0.0.1:9439/channels/channelName/senders/senderToken
```

Sender application should connect to the Connect URL to establish connection with Receiver application.
