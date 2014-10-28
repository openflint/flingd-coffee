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
#    limitations under the License.
#

net                     = rekuire "net"
child_process           = rekuire "child_process"

{ Log }                 = rekuire "log/Log"
{ Platform }            = rekuire "platform/Platform"
{ JsonMessageEmitter }  = rekuire "util/JsonMessageEmitter"
{ HashSet }             = rekuire "util/HashSet"
{ Config }              = rekuire "dial/Config"

class PlatformFirefoxOS extends Platform

    constructor: ->
        super
        @pendingMessage = new Array
        @maxPendingMessageNum = 64

        @sockets = new HashSet()
        @_setupPalConnectionServer()

    launchApplication: (app) ->
        @_sendMessage JSON.stringify
            type: "LAUNCH_RECEIVER"
            app_id: app?.getAppId()
            app_info: app?.getAppInfo()

    stopApplication: (app) ->
        @_sendMessage JSON.stringify
            type: "STOP_RECEIVER"
            app_id: app?.getAppId()
            app_info: app?.getAppInfo()

    _setupPalConnectionServer: ->
        @palServer = new net.createServer (socket) =>
            Log.d "PAL create new CONNECTION!"
            @sockets.add socket
            emitter = new JsonMessageEmitter socket, (message) =>
                @_didReceiveSystemMessage message
            socket.on 'end', ->
                Log.d "PAL sock closed!"
                @sockets.remove socket
                emitter = null
            socket.on 'error', (exception) ->
                Log.e "PAL socket error: #{exception}"
            socket.on 'data', (data) ->
                Log.d "pal socket data: #{data}"
        @palServer.listen Config.FFOS_PAL_SERVER_PORT

    _sendMessage: (msg) ->
        Log.d "PlatformFirefoxOS._sendMessage: #{msg}"

        if @sockets.isEmpty()
            if @pendingMessage.length > @maxPendingMessageNum
                Log.e "reach max pending message num[#{@maxPendingMessageNum}]. only remain the tails[32...]!"
                @pendingMessage = @pendingMessage.slice 32
            @pendingMessage.push msg
            return
        for sock in @sockets.values()
            msgBuf = new Buffer msg
            lenBuf = new Buffer msgBuf.length + ":"
            sock.write (Buffer.concat [lenBuf, msgBuf]), =>
                Log.d "sent to pal: #{msg}"
        if @pendingMessage.length > 0
            @_sendMessage @pendingMessage.shift()

        Log.d "Sent all messages! socket total number: #{@sockets.size()}"

    _didReceiveSystemMessage: (msg) ->
        if msg.name and (@name isnt msg.name)
            @name = msg.name;
            Log.d "Name update, dispatch device_name_changed to restart discovery service"
            @emit "device_name_changed", @name

        if msg.network_changed
            Log.d "PlatformFirefox: network_changed: #{msg.network_changed}"
            @emit "network_changed", msg.network_changed

        changed = false
        if msg.volumeLevel and (@volumeLevel isnt msg.volumeLevel)
            changed = true
            @volumeLevel = msg.volumeLevel

        if msg.volumeMuted and (@volumeMuted isnt msg.volumeMuted)
            changed = true
            @volumeMuted = msg.volumeMuted
        else
            if @volumeLevel > 0
                @volumeMuted = false
            else
                @volumeMuted = true

        if @volumeChangedCallback and changed
            Log.d "PlatformFirefox: volume changed"
            @volumeChangedCallback()

    setVolume: (volumeLevel) ->
        super volumeLevel
        @_sendMessage JSON.stringify
            type: "SET_VOLUME"
            level: volumeLevel

    setMuted: (muted) ->
        super muted
        @_sendMessage JSON.stringify
            type: "SET_MUTED"
            muted: muted

    monitorVolumeChanged: (@volumeChangedCallback) ->

module.exports.PlatformFirefoxOS = PlatformFirefoxOS
