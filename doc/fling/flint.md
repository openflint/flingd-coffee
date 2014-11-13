# OpenFlint

`DIAL`  `Flint`

---

# Overview

#### Fling Service Discovery
Fling Service支持DIAL协议中规定的`SSDP`发现协议，也可以使用`mDNS`发现协议。

#### Fling Rest Service
Fling Service支持DIAL协议中的`query`，`launch`和`stop`接口，并且进行了扩展，为基于DIAL的application提供更多、更灵活的接口。

---

# Fling Service Discovery

#### SSDP
请参考References[1](Section 6.1)。

#### mDNS
mDNS会响应search name为`'openflint'`的请求，并把Fling Service的url地址与端口号返回。请参考References[2]。

---

# Fling Rest Service
* API:
    * `/apps/<appid>`：DIAL协议接口(DIAL client访问)
    * `/apps/~<appid>`：DIAL协议接口扩展(DIAL client访问)
    * `/system/control`：系统控制接口，目前支持volume控制(DIAL client访问)
    * `/apps/<appid>/dial_data`：接收First-Screen application的数据接口(First-Screen application访问)
    * `/receiver/~<appid>`：DIAL协议接口扩展(First-Screen application访问)

    > Fling Rest Service会截取url中得appId，进行不同处理。
    - `~<appid>`：需要遵守Fling Rest Service中对DIAL协议的扩展，**下文所有的`extension`小结都只针对`~<appid>`进行处理**。
    - `<appid>`：需要遵守标准的DIAL协议，并且需要将应用本身的配置信息，注册到Fling Rest Service中[参考Annex A]。

#### **获取应用状态**
* request
    请参考References[1](Section 6.1)。
* response
    请参考References[1](Section 6.1)。
* extension
    * Fling不支持installable状态的应用。
    * Fling增加了一个`starting`的状态，返回的http status code是200，表示应用正在启动中。
    > 如果查询到`starting`状态，可以继续轮训一段时间(比如10s)等待应用启动完毕，如果在一段时间内轮训结果一直没有变为`running`状态，则可以认为应用启动失败。
    * 如果DIAL client启动了一个应用以后，想与Fling Server的保持连接，需要发送`ping/pong`消息。但是Fling Rest Service是基于HTTP的无状态连接，所以需要DIAL client定期(maybe 1-5s)向Fling Server发送GET请求，并且在http request header中填充`Authorization`字段，它的值从下文的`POST`请求的返回结果中获得。

#### **启动应用**
* request
    请参考References[1](Section 6.2)。
* response
    请参考References[1](Section 6.2)。
* extension
    * `POST`请求，可以发送3种不同的命令，分别是`launch`,`relaunch`和`join`。
        * `launch`: 当通过GET获取的应用状态为`stopped`时，可以通过这个命令启动一个应用，同时message body中需要包含要启动应用的相关信息。
        * `relaunch`: 当通过GET获取的应用状态为`running`  或者`starting`时，可以通过这个命令停止并重新启动这个应用，同时message body中需要包含要启动应用的相关信息。但是是否能relaunch成功，还需要看每个应用的实现和配置是否允许重新启动。
        * `join`：当通过GET获取的应用状态为`running`  或者`starting`时，发送`join`命令，使DIAL client只是将自己加入Fling Rest  Service的session管理中，不对已经启动的应用做任何操作。
    * response中会返回一些session管理的信息。
        * `token`：表示Fling Server为发送请求的DIAL client创建了一个session，如果这个DIAL client再发送其他请求，都需要在发送请求时附带这个token。而且为了保证这个token一直有效，需要定期的向Fling Server发送带有`token`的GET请求(前文的GET请求)。
        * `interval`：建议DIAL client发送GET请求的间隔，毫秒zhi。
    * 消息格式请参考[Annex B]

#### **停止应用**
* request
    请参考References[1](Section 6.4)。
* response
    请参考References[1](Section 6.4)。
* extension
    Fling Rest Service提供2个接口来处理`DELETE`消息：
         `/apps/~<appId>`: http request header中需要带有`token`，请求断开与Fling Server的session，之后Fling Server将不再管理这个token对应的session。
        * `/apps/~<appId>/<instance>`: http request header中需要带有`token`，请求stop这个应用。如果`token`对应的session还有效，就可以stop应用。
        * 消息格式请参考[Annex C]

#### **系统控制接口**
Fling Rest Service提供这个接口使得DIAL client可以对集成Fling Rest Service的系统进行一些控制，目前只支持volume调节。消息格式参考[Annex D]

#### **处理First-Screen application POST请求**
请参考References[1](Section 6.3.1)。

#### **与First-Screen application通信**
这个接口是Fling对DIAL协议的扩展。
Fling Server与First-Screen application通过websocket进行通信。Fling Server会创建一个websocket server，First-Screen application会作为一个client去连接这个websocket server。
具体消息格式请参考[Annex E]。

* `register`
    当First-Screen application连接到websocket server后，需要向Fling Server发送register消息，表示First-Screen application已经启动成功。
* `registerok`
    当Fling Server收到`register`消息后，会返回`registerok`告诉First-Screen application确认regiser成功，并将Fling Server的一些信息返回给First-Screen application。
* `startHeartbeat`
    register结束后，Fling Server会通知First-Screen application可以开始心跳。之后Fling Server会定期向First-Screen application发送ping消息，First-Screen application需要响应pong消息。如果First-Screen application需要主动监控心跳状态，那么First-Screen application可以主动向Fling Server发送ping消息，Fling Server会返回pong消息。
* `senderconnected`
    当某一个DIAL client通过POST请求创建了一个session以后，Fling Server会向
First-Screen application发送一个`senderconnected`消息，并把这个DIAL client的token一起传递过去。First-Screen application可以通过这个消息进行DIAL client的管理。
* `senderdisconnected`
    当某一个DIAL client的session断开以后，Fling Server会向
First-Screen application发送一个`senderdisconnected`消息，并把这个DIAL client的token一起传递过去。First-Screen application可以通过这个消息进行DIAL client的管理。
* `additionaldata`
    当First-Screen application可以通过Fling Server向所有处于连接状态的DIAL client发送数据，这些数据会保存在Fling Server中，当有DIAL client向Fling Server发送GET请求时，Fling Server会把数据转发出去。
* `unregister`
    当First-Screen application想要主动断开这条websocket链接时，可以发送`unregister`消息。

---

# build-in通信基础模块
Fling Server为应用提供了几种常用的内建通信设施，比如websocket和socket.io。应用开发者可以很方便的使用这些通信设施进行First-Screen Application与sender应用数据交换。

* **WebSocket Server**
    * First-Screen Application与sender应用之间可以通过WebSocket Server创建一条或多条通信链路。
    * 通信链路由First-Screen Application创建，创建完成后，将所有的链路信息通过additionaldata发送给Fling Server，再由Fling Server转发给sender应用。sender应用接收到链路地址并将自己的token拼接到链路地址后面，就可以与First-Screen Application进行通信了。
    * 每一条通信链路中，sender应用与First-Screen Application是多对一的关系，也就是说多个sender应用可以同时连接同一条通信链路。
    * Websocket Server API请参考[Annex F]。

* **Socket.io Server**
* **Peerjs Server**

---

# References
[1] DIAL (http://www.dial-multiscreen.org/dial-protocol-specification/DIAL-2ndScreenProtocol-1.7.pdf)
[2] MDNS (http://www.multicastdns.org)
[3] DIAL Registry (http://www.dial-multiscreen.org/dial-registry/namespace-database)

---

# Annex

#### **A. appid**
* `~<appid>`：如果开发者的应用需要fling service的支持，就需要将自己的appid定义为以~为前缀。建议避免使用重复概率大的appid，如果没有特殊需求，也可以使用uuid生成一个全球唯一的appid。
* `<appid>`：参考References[3]。

#### **B. launch application**
* request

    <pre><code>
    POST http://192.168.1.1:9431/apps/~appid
    Content-Type: application/json

    {
        "type":"launch/relaunch/join",
        "app_info":{
            "url":"http://www.youtube.com",
            "useIpc":true or false, #是否需要First-Screen Application去连接Fling Server的websocket。
            "maxInactive":n #依赖于useIpc，如果useIpc为false，需要maxInactive为First-Screen Application设定一个存活时间，毫秒值。可以设置为负数，表示一直运行。
        }
    }
    </code></pre>

* response
    * 启动了一个新应用

    <pre><code>
    201 CREATE
    Content-Type: application/json

    {
        "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
        "interval":3 #ping/pong interval
    }
    </code></pre>

    * 已经有同一个应用在运行

    <pre><code>
    200 OK

    Content-Type: application/json
    {
        "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
        "interval":3 #ping/pong interval
    }
    </code></pre>

#### **C. stop application**
* request
    <pre><code>
    DELETE http://ip:port/apps/~appid
    Authorization: EE2287DB-D10D-FECD-667B-8342AD095C33
    </code></pre>
    <pre><code>
    DELETE http://ip:port/apps/~appid/{instance}
    Authorization: EE2287DB-D10D-FECD-667B-8342AD095C33
    </code></pre>

* response
    * 成功
    <pre><code>
    200 OK
    </code></pre>

    * 失败
        * token失效
        <pre><code>
        400 Bad Request
        </code></pre>
        * appid非法
        <pre><code>
        404 Not Found
        </code></pre>

#### **D. system control**
* request
    `level`依赖于`SET_VOLUME`，`muted`依赖于`SET_MUTED`。
    `GET_VOLUME`与`GET_MUTED`不需要参数`level`和`muted`。

    <pre><code>
    POST http://ip:port/system/control
    Content-Type: application/json

    {
        "type":"GET_VOLUME | SET_VOLUME | GET_MUTED | SET_MUTED",
        "level": 0.5,
        "muted": false
    }
    </code></pre>
* response

    <pre>
    200 OK
    Content-Type: application/json

    {
        "success": true, #bool，表示结果
        "type":"GET_VOLUME | SET_VOLUME | GET_MUTED | SET_MUTED", #与之前request中的type相同
        "level": 0.5, #float，音量
        "muted": false #boolean，是否静音
    }
    </pre>

#### **E. 与First-Screen application通信**
First-Screen application连接Fling Server的websocket地址为：
> **`ws:127.0.0.1:9431/receiver/~<appid>`**

* `register`：App -> Fling Server
<pre>
    {
        "type":"register",
        "appid":"~appid"
    }
</pre>
* `unregister`：App -> Fling Server
<pre>
    {
        "type":"unregister",
        "appid":"~appid"
    }
</pre>
* `additionaldata`：App -> Fling Server
<pre>
    {
        "type":"additionaldata",
        "appid":"~browser",
        "additionaldata":{
            "key1":"value1"
        }
    }
</pre>
* `startheartbeat`：Fling Server -> App
<pre>
    {
        "type":"startheartbeat",
        "appid":"~appid",
        "interval":3*1000 # ping/pong间隔
    }
</pre>
* `senderconnected`：FlingService -> App
<pre>
    {
        "type":"senderconnected",
        "appid":"~appid",
        "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
    }
</pre>
* `senderdisconnected`：FlingService -> App
<pre>
    {
        "type":"senderdisconnected",
        "appid":"~appid",
        "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
    }
</pre>
* `ping/pong`：FlingService <-> App
<pre>
    {
        "type":"heartbeat",
        "appid":"~appid",
        "heartbeat":"ping/pong"
    }
</pre>

#### **F. WebSocket Server API**
* First-Screen Application创建channel。WebSocket Server地址为：`ws://localhost:9439`。
<pre><code>
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
        "senderId": "xxx", #如果senderId为*:*，表示广播给所有sender，否则要填充为具体的senderId
        "data": "string" # string
    }
);

var ws_B = new WebSocket("ws://127.0.0.1:9439/channels/" + channelNameB);
...(同ws_A)
</code></pre>
* First-Screen Application向Fling Server发送additionaldata
<pre><code>
ws.send(
    {
        "channelNameA": "ws://127.0.0.1:9439/channels/channelNameA",
        "channelNameB": "ws://127.0.0.1:9439/channels/channelNameB"
    }
);
</code></pre>
* Fling Server向sender应用发送additionaldata
<pre><code>
    &lt;additionaldata>
        &lt;channelNameA>ws://127.0.0.1:9439/channels/channelNameA&lt;/>
        &lt;channelNameB>ws://127.0.0.1:9439/channels/channelNameB&lt;/>
    &lt;/additionaldata>
</code></pre>
* sender连接channel
    sender应用拿到每条链路的地址，访问这个地址前首先要拼接为一个带有某个sender自己唯一标示的地址。比如：
<pre><code>
接收到：ws://127.0.0.1:9439/channels/channelName
拼接为：ws://127.0.0.1:9439/channels/channelName/senders/senderToken
</code></pre>
    sender就可以连接`ws://127.0.0.1:9439/channels/channelName/senders/senderToken`进行数据收发了。