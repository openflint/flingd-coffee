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

class ApplicationControlHandler

    constructor: ->

    onHttpRequest: (req, res) ->
        segs = url.parse req.url
        appId = S(segs.path).replaceAll("/apps/", "").s
        appId = S(appId).replaceAll("/run", "").s
        host = req.headers.host
        method = req.method
        Log.i "ApplicationControlHandler: #{method} #{host}:#{appId}"

        if appId
            switch method
                when "GET"
                    @_onGet req, res, appId
                when "POST"
                    @_onPost req, res, appId
                when "DELETE"
                    @_onDelete req, res, appId
                else
                    Log.e "Unsupport http method: #{method}"
                    @_onResponse req, res, 400, null, null
        else
            @_onResponse req, res, 404, null, null

    _onGet: (req, res, appId) ->
        # ping/pong
        token = req.headers["authorization"]
        if token
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
            "Connection": "keep-alive"
            "Access-Control-Allow-Method": "GET, POST, DELETE, OPTIONS"
            "Cache-Control": "no-cache, must-revalidate, no-store"
            "Content-Length": bodyContent.length
        @_onResponse req, res, 200, headers, bodyContent

    _onPost: (req, res, appId) ->
        data = null
        req.on "data", (_data) =>
            if not data then data = ""
            data += _data

        req.on "end", =>
            Log.d "ApplicationControlHandler receive post:\n#{data}"
            if data
                contentType = req.headers["content-type"]
                if not S(contentType).contains("application/json")
                    Log.e "content type must be application/json while posting data"
                    @_onResponse req, res, 400, null, null
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

                switch type
                    when "launch"
                        runningApp = ApplicationManager.getInstance().getCurrentApplication()
                        if runningApp
                            statusCode = 200
                        else
                            if @_onLaunch appId, appInfo
                                statusCode = 201
                            else
                                @_onResponse req, res, 400, null, null
                                return
                    when "relaunch"
                        runningApp = ApplicationManager.getInstance().getCurrentApplication()
                        if runningApp and (runningApp.getAppId() is appId)
                            runningApp.stop()
                            if @_onLaunch appId, appInfo
                                statusCode = 201
                            else
                                @_onResponse req, res, 400, null, null
                                return
                        else
                            Log.e "appid not matched, cannot relaunch!!!"
                            @_onResponse req, res, 400, null, null
                            return
                    when "join"
                        statusCode = 200
                body =
                    token: token
                    interval: Config.SENDER_SESSION_PP_INTERVAL
                bodyContent = JSON.stringify body
                Log.d "response body ->\n#{bodyContent}"
                res.writeHead statusCode,
                    "Content-Type": "application/json"
                    "Connection": "keep-alive"
                    "Access-Control-Allow-Method": "GET, POST, DELETE, OPTIONS"
                    "Cache-Control": "no-cache, must-revalidate, no-store"
                    "Content-Length": bodyContent.length
                res.end bodyContent
                SessionManager.getInstance().sessionConnected session
            else
                Log.e "bad post request: type is #{type}, appInfo is #{JSON.stringify appInfo}"
                @_onResponse req, res, 400, null, null

    _onLaunch: (appId, appInfo) ->
        if S(appId).startsWith "~" # build-in application
            app = new Application appId, appInfo
            app.start()
            return true
        else
            # TODO: add your implementation
            null
        return false

    _onDelete: (req, res, appId) ->
        segs = url.parse req.url
        instance = S(segs.path).replaceAll("/apps/", "").s
        instance = S(instance).replaceAll(appId, "").s
        instance = S(instance).replaceAll("/", "").s
        token = req.headers["authorization"]
        if instance
            # stop the application
            app = ApplicationManager.getInstance().getAliveApplication()
            if app
                if appId is app.getAppId()
                    if not SessionManager.getInstance().checkSession token
                        Log.d "invalided token [#{token}], stop #{appId} failed!!!"
                        @_onResponse req, res, 400, null, null
                        return
                    if app.getAppInfo() and app.getAppInfo().useIpc
                        app.stop()
                    else
                        app.terminate()
            else
                Log.d "application #{appId} maybe not running, stop it forced!!!"
                ApplicationManager.getInstance().stopApplicationForce()
            @_onResponse req, res, 200, null, null
        else
            # disconnect the session
            Log.d "token [#{token}] need disconnect."
            SessionManager.getInstance().sessionDisconnectedByToken token
            @_onResponse req, res, 200, null, null

    _onResponse: (req, res, statusCode, headers, body) ->
        if headers
            res.writeHead statusCode, headers
        else
            res.statusCode = statusCode

        if body
            res.end body
        else
            res.end()

module.exports.ApplicationControlHandler = ApplicationControlHandler
