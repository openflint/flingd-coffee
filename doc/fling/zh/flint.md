# Flint Protocol Docs

---
## Overview
Flint Service包含Discovery Service, Rest Service和WebSocket Service。Flint实现了DIAL协议，支持2nd screen application（也叫做sender application）发现、启动 1st screen application（也叫做receiver application）。sender application是DIAL client，Discovery Service和Rest Service是DIAL server。

---
## Flint Discovery Service
Flint Discovery Service支持DIAL协议中定义的SSDP发现协议，也支持mDNS发现协议。
* SSDP：请参考References [1](Section 5)。 
* mDNS：mDNS会响应search name为`'openflint'`的请求，并把DIAL server的URL地址与端口号返回。请参考References [2]。

---
## Flint Rest Service
Flint Rest Service提供DIAL协议中定义的`query`、`launch`和`stop`接口，sender application可以通过这些接口来控制receiver application。除此之外，Flint Rest Service在DIAL协议之上扩展了更多更灵活的接口给sender application和receiver application使用。
![Flint Architecture Chart](http://openflint.github.io/assets/images/flint-protocol-overview.png)

### API
* `/apps/<appid>`: 标准的DIAL HTTP接口；由sender application请求
* `/apps/<appid>/dial_data`: 标准的DIAL HTTP接口，接收receiver application发送给DIAL server的附加数据；由receiver application请求
* `/apps/~<appid>`: 扩展的HTTP接口；由sender application请求
* `/system/control`: 为系统控制提供的扩展的HTTP接口，目前只支持音量控制；由sender application请求
* `/receiver/~<appid>`: 为receiver application与DIAL server建立消息通道提供的扩展的WebSocket接口；由receiver application请求
> Flint Rest Service会提取URL中的`appid`并进行不同的处理：
    - `~<appid>`：按照FLint Rest Service中对于DIAL协议的扩展进行处理实现，下文所有的 **extension**小结，都是针对`~<appid>`的定义。
    - `<appid>`: 遵循标准的DIAL协议，并且需要在DIAL server中注册和配置receiver application。
    - 请参考[Annex A]

### 获取Receiver Application状态
* HTTP `GET` Request
    * sender application向`/apps/<appid>`或者`/apps/~<appid>`发送`GET`请求
    * 细节请参考References [1] Section 6.1
* HTTP Response
    * Flint Reset service向sender application返回receiver application的状态
    * 细节请参考 References [1] Section 6.1
* Extension
    * 目前Flint Reset Service不支持installable状态
    * Flint Reset Service增加了一种`starting`状态，HTTP状态码为200，表示receiver application正在启动。
    > sender application应该轮训等待receiver application的状态由`starting`变为`running`状态，并且限制轮训次数和间隔来判断receiver application是否启动成功。
    * 如果sender application在receiver application启动后，想继续通过DIAL server控制receiver application，那么sender application必须与DIAL server通过`心跳`来保持连接。`心跳`的方式是sedner application定期（1-5秒）向DIAL server发送`GET`请求，并且在`GET`请求的HTTP headers中`Authorization`填充有效的值（这个值从下文的描述的POST请求的返回结果中获得）

### 启动Receiver Application
* HTTP `POST` request
    * sender application向`/apps/<appid>`或者`/apps/~<appid>`发送`POST`请求来启动receiver application
    * 细节请参考References [1] Section 6.2
* HTTP response
    * 细节请参考References [1] Section 6.2
* Extension
    * `POST`请求可以发送3中命令：`launch`、`relaunch`和 `join`
        * `launch`：可以启动状态为`stopped`的receiver application，并且`POST`请求的message body中需要包含关于receiver application的启动信息
        * `relaunch`：可以启动状态为`running`或`starting`的receiver application，并且`POST`请求的message body中需要包含关于receiver application的启动信息。是否能够relaunch成功，取决于receiver application的实现和配置
        * `join`：可以加入状态为`running`或`starting`的receiver application，DIAL server会通知receiver application新的sender application已经加入，并且对新加入的sender application纳入session管理列表中
    * `POST`响应中会包含session管理的信息。
        * `token`：DIAL server会为发送合法POST请求的sender application创建一个session。sender application向DIAL server的后续请求，都需要在HTTP headers的`Authorization`字段中填充这个`token`，以便于DIAL server进行操作的合法性校验，而且sender application必须通过上文提到过的`心跳`来保持这个token有效。
        * `interval`：sender application与DIAL server之间的`心跳`间隔
    * 消息格式定义请参考[Annex B]

### 停止Receiver Application
* HTTP `POST` request：细节请参考References [1] Section 6.4
* HTTP response：细节请参考References [1] Section 6.4
* extension：DIAL server提供2个接口处理`DELETE`请求：
    * `/apps/~<appId>`：断开与DIAL server的session连接
    > 这是sender application主动断开session的方式，也可以停止发送`心跳`被动的断开session
    * `/apps/~<appId>/<instance>`：停止receiver application
    * 消息格式定义请参考[Annex C]

### 系统控制接口
    * 为sender application提供系统控制的接口，目前只支持音量控制
    * 消息格式定义请参考[Annex D]

### 处理receiver application的POST请求
细节请参考References [1] Section 6.3.1

### Extension: DIAL server与receiver application通信
DIAL server与receiver application通过WebSocket进行通信。DIAL server作为WebSocket server，receiver application作为WebSocket client。消息格式定义请参考[Annex E]

* `register`: 当receiver application启动并成功连接到DIAL server中的WebSocket server后，需要发送`register`消息表明receiver application已经启动成功。
* `registerok`: DIAL server返回`registerok`确认收到receiver application启动成功，并附带返回一些DIAL server的信息，比如DIAL server的实际IP地址等。
* `startHeartbeat`: 在register流程之后，DIAL server会发送`startHeartbeat`告诉reciever application开始心跳。之后reciever application可以被动的返回`pong`消息，也可以主动的发起`ping`消息。
* `senderconnected`: 如果DIAL server创建了一个新的sender application session，就会发送`senderconnected`来通知receiver application，消息中包含新建session的token信息。
* `senderdisconnected`: 如果DIAL server断开了一个sender application session，就会发送`senderdisconnected`来通知receiver application，消息中包含断开session的token信息。
* `additionaldata`: receiver application可以向DIAL server发送`additionaldata`消息，DIAL server会保存`additionaldata`中的数据。当sender application通过`GET`请求获取receiver application状态时，DIAL server会把additionaldata一并返回。
* `unregister`: receiver application可以通过`unregister`消息告诉DIAL server自己即将停止。

---
## Build-in WebSocket通信设施
DIAL server为sender application和receiver application提供了几种通信设置，方便它们进行数据交换。

* WebSocket Server
    * receiver application可以通过DIAL server中提供的WebSocket Server创建一条或多条数据链路
    * 当receiver application创建好通信链路，可以通过`additionaldata`消息将通信链路的地址告诉DIAL server，当sender application向DIAL server发送`GET`请求获取reciever application状态时，就可以得到通信链路的地址，这样sender application去连接这个通信链路，就可以与reciever application进行直接的数据通信了。
    * 多个sender application可以连接同一个通信链路，这样sender application与receiver application就可以进行N对1的通信。
    * Websocket Server API定义请参考[Annex F]

## Reference
1. DIAL: (http://www.dial-multiscreen.org/dial-protocol-specification/DIAL-2ndScreenProtocol-1.7.pdf)  
2. MDNS: (http://www.multicastdns.org)  
3. DIAL Registry: (http://www.dial-multiscreen.org/dial-registry/namespace-database)

## Annex
### **A. appid**
* `~<appid>`：如果sender application和receiver application实现了Flint对于DIAL协议的扩展部分，那么开发者就需要以`~`为前缀定义他们的application ID
* `<appid>`：请参考References [3] 

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

if `GET_XXX`

```
200 OK
Content-Type: application/json

{
    "success": true, # boolean
     "type":"GET_VOLUME | GET_MUTED",
     "level": 0.5, #float, Available if if type is GET_VOLUME
     "muted": false or true #boolean, Available if type is GET_MUTED
}
```
if `SET_XXX`

```
200 OK
or
400 BAD REQUEST
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
