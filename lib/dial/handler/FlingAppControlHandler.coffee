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

url                         = require "url"
S                           = require "string"

{ Log }                     = rekuire "log/Log"
{ SessionManager }          = rekuire "dial/session/SessionManager"
{ Config }                  = rekuire "dial/Config"
{ Application }             = rekuire "application/Application"
{ ApplicationManager }      = rekuire "application/ApplicationManager"
{ Handler }                 = rekuire "dial/handler/Handler"

class FlingAppControlHandler extends Handler

    onHttpRequest: (req, res) ->
        Log.i "FlingAppControlHandler: #{req.method} -> #{req.url}"
        segs = url.parse req.url
        appId = S(segs.path).replaceAll("/apps/", "").s
        href = "/" + Config.APPLICATION_INSTANCE
        appId = S(appId).replaceAll(href, "").s
        if not appId
            @respondBadRequest req, res, "missing appId"
            return

        switch req.method
            when "GET"
                @_onGet req, res, appId
            when "POST"
                @_onPost req, res, appId
            when "DELETE"
                @_onDelete req, res, appId
            when "OPTIONS"
                @respondOptions req, res
            else
                @respondUnSupport req, res

    _onGet: (req, res, appId) ->
        # ping/pong
        token = req.headers["authorization"]
        if token
            if not SessionManager.getInstance().checkSession token
                Log.e "GET - SenderSession #{token} maybe timeout!!!"
                @respondBadRequest req, res, "#{token} timeout, GET failed"
                return
            else
                SessionManager.getInstance().touchSession token

        body = []
        body.push "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        body.push "<service xmlns=\"urn:dial-multiscreen-org:schemas:dial\" dialVer=\"1.7\">\n"
        body.push "    <name>#{appId}</name>\n"
        body.push "    <options allowStop='true'/>\n"

        app = ApplicationManager.getInstance().getAliveApplication()
        if app and (app.getAppId() is appId)
            body.push "    <state>#{app.getAppStatus()}</state>\n"
            body.push "    <link rel=\"run\" href=\"#{Config.APPLICATION_INSTANCE}\"/>\n"
            body.push app.getAdditionalData()
        else
            body.push "    <state>stopped</state>\n"

        body.push "</service>\n"
        bodyContent = body.join ""
        Log.d "response body ->\n#{bodyContent}"

        headers =
            "Content-Type": "application/xml"
            "Content-Length": bodyContent.length
        @respond req, res, 200, headers, bodyContent

    _onPost: (req, res, appId) ->
        data = null
        req.on "data", (_data) =>
            if not data then data = ""
            data += _data

        req.on "end", =>
            Log.d "FlingAppControlHandler receive post:\n#{data}"
            if not data
                @respondBadRequest req, res, "missing post data"
                return

            message = JSON.parse data
            type = message?.type
            appInfo = message?.app_info

            if ((type is "launch") or (type is "relaunch") or (type is "join")) and appInfo
                # already has a token
                token = req.headers["authorization"]
                if token
                    SessionManager.getInstance().touchSession token
                else
                    session = SessionManager.getInstance().createSenderSession appId
                    token = session.getToken()

                if appInfo and appInfo.url
                    hostIp = req.connection.remoteAddress or
                        req.socket.remoteAddress or
                        req.connection.socket.remoteAddress
                    appInfo.url = appInfo.url.replace "${REMOTE_ADDRESS}", hostIp

                app = ApplicationManager.getInstance().getAliveApplication()
                switch type
                    when "launch"
                        if app
                            if app.getAppId() isnt appId
                                Log.w "#{app.getAppId()} is interrupted, #{appId} will be launched"
                                app.stop()
                                @_doLaunch appId, appInfo
                                statusCode = 201
                            else
                                Log.w "#{appId} is running, ignore launch"
                                statusCode = 200
                        else
                            @_doLaunch appId, appInfo
                            statusCode = 201
                    when "relaunch"
                        if app
                            if app.getAppId() is appId
                                Log.w "#{appId} is interrupted, it will be relaunched"
                                app.stop()
                                @_doLaunch appId, appInfo
                                statusCode = 201
                            else
                                Log.e "running app is #{app.getAppId()}, request appid is #{appId}, they are not matched!!!"
                                @respondBadRequest req, res, "relaunch failed"
                                return
                        else
                            Log.e "no running app, cannot be relaunched!!!"
                            @respondBadRequest req, res, "relaunch failed"
                            return
                    when "join"
                        if app
                            if app.getAppId() is appId
                                statusCode = 200
                            else
                                Log.e "running app is #{app.getAppId()}, request appid is #{appId}, they are not matched!!!"
                                @respondBadRequest req, res, "join failed"
                                return
                        else
                            Log.e "no running app, cannot join!!!"
                            @respondBadRequest req, res, "join failed"
                            return

                body =
                    token: token
                    interval: Config.SENDER_SESSION_PP_INTERVAL
                bodyContent = JSON.stringify body
                Log.d "response body ->\n#{bodyContent}"
                headers =
                    "Connection": "keep-alive"
                    "Cache-Control": "no-cache, must-revalidate, no-store"
                    "Content-Type": "application/json"
                    "Content-Length": bodyContent.length
                @respond req, res, statusCode, headers, bodyContent
                SessionManager.getInstance().sessionConnected session
            else
                Log.e "bad post request: type is #{type}, appInfo is #{JSON.stringify appInfo}"
                @respondBadRequest req, res, "unsupport control"

    _onDelete: (req, res, appId) ->
        token = req.headers["authorization"]
        if token
            if not SessionManager.getInstance().checkSession token
                Log.e "DELETE - SenderSession #{token} maybe timeout!!!"
                Log.w "invalided token [#{token}], stop #{appId} failed!!!"
                @respondBadRequest req, res, "#{token} timeout, DELETE failed"
                return
        else
            Log.e "DELETE need a token, failed!!!"
            @respondBadRequest req, res, "missing token"
            return

        segs = url.parse req.url
        instance = S(segs.path).replaceAll("/apps/", "").s
        instance = S(instance).replaceAll(appId, "").s
        instance = S(instance).replaceAll("/", "").s

        if instance and (Config.APPLICATION_INSTANCE is instance)
            # stop the application
            app = ApplicationManager.getInstance().getAliveApplication()
            if app
                if appId is app.getAppId()
                    Log.d "DELETE stop app #{appId}!!!"
                    app.stop()
                else
                    Log.e "running app is #{app.getAppId()}, request appid is #{appId}, they are not matched!!!"
                    @respondBadRequest req, res, "stop failed"
                    return
            else
                Log.w "application #{appId} maybe not running, stop it forced!!!"
                ApplicationManager.getInstance().stopApplication()
            @respond req, res, 200
        else
            # disconnect the session
            Log.d "token [#{token}] need disconnect."
            SessionManager.getInstance().sessionDisconnectedByToken token
            @respond req, res, 200

    _doLaunch: (appId, appInfo) ->
        app = new Application appId, appInfo
        app.start()

module.exports.FlingAppControlHandler = FlingAppControlHandler
