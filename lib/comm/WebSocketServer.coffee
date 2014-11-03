#
# Copyright (C) 2013-2014, The OpenFlint Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

{ Log } = rekuire "log/Log"

class Channel

    constructor: (@id) ->
        @txconn = {}

    close: ->
        @rxconn.close() # senders connection close soon

    setReceiverConn: (rxconn) ->
        @rxconn = rxconn
        @rxconn.on 'message', (message) =>
            Log.i 'Receive receiver message : ', message
            messageObj = JSON.parse message
            senderId = messageObj.senderId
            if "*:*" is senderId
                for own _, conn of @txconn
                    conn.send messageObj.data
            else
                txconn = @txconn[senderId]
                if txconn
                    txconn.send messageObj.data
                else
                    @_respReceiverError 'Invalid sender id'

        @rxconn.on 'close', =>
            @rxconn = null
            @_closeSenders()

    addSenderConn: (senderId, senderConn) ->
        if @rxconn
            if @txconn[senderId]
                @txconn[senderId].close()
            @txconn[senderId] = senderConn

            @rxconn.send JSON.stringify
                type: 'senderConnected'
                senderId: senderId

            senderConn.on 'message', (message) =>
                Log.i "Receive from sender ", message;
                @rxconn?.send JSON.stringify
                    type: 'message'
                    senderId: senderId
                    data: message

            senderConn.on 'close', =>
                @rxconn?.send JSON.stringify
                    type: 'senderDisconnected'
                    senderId: senderId
                @_removeSenderConn senderId
        else
            senderConn.close()

    _closeSenders: ->
        for senderId, txconn of @txconn
            Log.i 'closing sender ' + senderId
            txconn.close()
        @txconn = {}

    _removeSenderConn: (senderId) ->
        delete @txconn[senderId]

    _respReceiverError: (message) ->
        @rxconn.send JSON.stringify
            type: 'error'
            message: message

class WebSocketServer

    constructor: (opts) ->
        @channels = {}
        @port = opts.port

    start: ->
        stringrouter = require 'stringrouter'
        router = stringrouter.getInstance()

        router.bindPattern '/channels/{channelId:[a-zA-Z_0-9\-]+}', null
        router.bindPattern '/channels/{channelId:[a-zA-Z_0-9\-]+}/senders/{senderId:[a-zA-Z_0-9\-]+}', null

        @wss = new (require('ws').Server) { port: @port }
        @wss.on 'connection', (ws) =>
            Log.i 'New connection ', ws.upgradeReq.url
            router.dispatch ws.upgradeReq.url, (err, packet) =>
                if not err
                    channelId = packet.params.channelId
                    senderId = packet.params.senderId
                    if senderId
                        @_newSenderConnection channelId, senderId, ws
                    else
                        @_newReceiverConnection channelId, ws
                else
                    ws.send JSON.stringify
                        type: 'error'
                        message: 'Invalid url'
                    ws.close()

    # close channel
    _closeChannel: (channelId) ->
        Log.i "close channel : ", channelId
        @channels[channelId].close()
        delete @channels[channelId]

    # receiver
    _newReceiverConnection: (channelId, ws) ->
        Log.i "New receiver connection ", channelId

        @_closeChannel channelId if @channels[channelId]

        @channels[channelId] = new Channel channelId
        @channels[channelId].setReceiverConn ws

    # sender
    _newSenderConnection: (channelId, senderId, ws) ->
        Log.i "New sender connection ", channelId, senderId
        if @channels[channelId]
            @channels[channelId].addSenderConn senderId, ws
        else
            ws.send JSON.stringify
                type: 'error'
                message: 'Specified channel does not exists'
            ws.close()

module.exports.WebSocketServer = WebSocketServer