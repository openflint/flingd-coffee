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

{ Log }                 = rekuire "log/Log"
{ Session }             = rekuire "dial/session/Session"
{ Config }              = rekuire "dial/Config"
{ ApplicationManager }  = rekuire "application/ApplicationManager"

class ReceiverSession extends Session

    constructor: (sessionManager, token, appId, @channel) ->
        if not channel
            Log.e "cannot create a ReceiverSession with a null channel!!!"
            throw new Error "cannot create a ReceiverSession with a null channel!!!"

        super sessionManager, token, appId
        @timeout = Config.RECEIVER_SESSION_TIMEOUT
        @tag = "ReceiverSession"

        @channel.on "message", (message) =>
            Log.d "receiver channel received:\n#{message}"
            # assumed application is alive when receiving message
            @triggerTimer()

            # check alive application
            app = ApplicationManager.getInstance().getAliveApplication()
            if not app
                Log.e "No alive application!!! ReceiverSession need to close!!!"
                @_close false
                return
            if app.getAppId() isnt @appId
                Log.e "app id not matched between Alived application and ReceiverSession!!!"
                @_close false
                return

            #check message
            data = JSON.parse message
            if not data
                Log.w "ReceiverSession received illegal message: #{message}"
                return
            if data.appid isnt @appId
                Log.e "app id not matched between message and ReceiverSession saved!!!"
                @_close false
                return

            # receiver application register itself
            if data.type is "register"
                Log.d "app #{@appId} is registered"
                # application is launched, and start heartbeat
                app.started()
                @_startHeartbeat()
            # receiver application unregister itself, fling-service stop it
            else if data.type is "unregister"
                @sessionManager.clearReceiverSession()
                app.stop()
            # receiver application post additional data to Fling-Service
            else if data.type is "additionaldata"
                Log.d "app #{@appId} set additional data: #{data.additionaldata}"
                app.setAdditionalData data.additionaldata
            # heartbeat message
            else if data.type is "heartbeat"
                Log.d "app #{@appId} ping/pong!!!"
                if data.heartbeat is "ping"
                    @_onHeartbeat "pong"
                else if data.heartbeat is "pong"
                    @_onHeartbeat "ping"
                else
                    Log.e "ping/pong message illegal: #{data.heartbeat}"

        @channel.on "close", =>
            Log.d "#{@tag} closed!!! terminate application!!!"
            app = ApplicationManager.getInstance().getStoppingApplication()
            if app and (app.getAppId() is @appId)
                app.stopped()
            else
                @_close true

    senderConnected: (senderSession) ->
        if senderSession?.getAppId() isnt @appId
            Log.w "illegal appid connected to receiver application"
            return
        @_reply
            type: "senderconnected"
            appid: @appId
            token: senderSession.getToken()

    senderDisconnected: (senderSession) ->
        if senderSession?.getAppId() isnt @appId
            Log.w "illegal appid disconnected to receiver application"
            return
        @_reply
            type: "senderdisconnected"
            appid: @appId
            token: senderSession.getToken()

    _startHeartbeat: ->
        @_reply
            type: "startHeartbeat"
            appid: @app.getAppId()
            interval: Config.RECEIVER_SESSION_PP_INTERVAL
        @_onHeartbeat "ping"
        @triggerTimer()
        setInterval ( =>
                @_ping()
            ), Config.RECEIVER_SESSION_PP_INTERVAL

    #
    # params:
    #   heartbeat - "ping" or "pong"
    #
    _onHeartbeat: (heartbeat) ->
        msg =
            type: "heartbeat"
            appid: @appId
            heartbeat: heartbeat
        @reply msg

    _onTimeout: ->
        super()
        @_close false

    #
    # params:
    #   closeAppFlag - indicates whether stopping application or not
    #
    _close: (closeAppFlag) ->
        Log.d "#{@tag}:#{@token} _close!!!"
        if closeAppFlag
            app = ApplicationManager.getInstance().getCurrentApplication()
            if app and (app.getAppId() is @appId)
                app.terminate()
        @_clearTimer()
        @sessionManager.clearReceiverSession()
        @channel.close()

    _reply: (msg) ->
        try
            @channel.send JSON.stringify(msg)
        catch ex
            Log.e "receiver channel send failed, ws maybe closed，#{ex.toString()}"
            @_close true

module.exports.ReceiverSession = ReceiverSession