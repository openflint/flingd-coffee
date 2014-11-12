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
{ Config }                  = rekuire "dial/Config"
{ Application }             = rekuire "application/Application"
{ ApplicationManager }      = rekuire "application/ApplicationManager"
{ ApplicationConfigs }      = rekuire "application/ApplicationConfigs"
{ Handler }                 = rekuire "dial/handler/Handler"

class DialAppControlHandler extends Handler

    onHttpRequest: (req, res) ->
        Log.i "DialAppControlHandler: #{req.method} -> #{req.url}"
        segs = url.parse req.url
        appId = S(segs.path).replaceAll("/apps/", "").s
        href = "/" + Config.APPLICATION_INSTANCE
        appId = S(appId).replaceAll(href, "").s
        if not appId
            @respondBadRequest req, res, "missing appId"
            return
        else if not ApplicationConfigs[appId]
            @respondBadRequest req, res, "not support #{appId}"
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
        body = []
        body.push "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        body.push "<service xmlns=\"urn:dial-multiscreen-org:schemas:dial\" dialVer=\"1.7\">\n"
        body.push "    <name>#{appId}</name>\n"
        body.push "    <options allowStop='true'/>\n"

        app = ApplicationManager.getInstance().getAliveApplication()
        if app and (app.getAppId() is appId)
            body.push "    <state>running</state>\n"
            body.push "    <link rel=\"run\" href=\"#{Config.APPLICATION_INSTANCE}\"/>\n"
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
            Log.d "DialAppControlHandler receive post:\n#{data}"
            config = ApplicationConfigs[appId]
            if not data
                if not config.allow_empty_post_data
                    @respondBadRequest req, res, "missing post data"
                    return

            app = ApplicationManager.getInstance().getAliveApplication()
            if app
                if app.getAppId() is appId
                    @respond req, res, 200
                else
                    app.stop()
                    @_doLaunch req, res, appId, config, data
            else
                @_doLaunch req, res, appId, config, data

    _onDelete: (req, res, appId) ->
        app = ApplicationManager.getInstance().getAliveApplication()
        if app
            if app.getAppId() is appId
                app.stop()
                @respond req, res, 200
            else
                msg = "request appid is #{appId}, cannot stop #{app.getAppId()}"
                Log.e msg
                @respondBadRequest req, res, msg
        else
            @respondBadRequest req, res, "no running app, cannot stop!!!"

    _doLaunch: (req, res, appId, config, postData) ->
        Log.d "do real launch!!! #{appId}"
        appUrl = config.url
        if appUrl.indexOf "$POST_DATA" >= 0 and postData
            appUrl = appUrl.replace "$POST_DATA", postData
        appInfo = {}
        appInfo["url"] = appUrl
        if config.useIpc isnt undefined
            appInfo["useIpc"] = config.useIpc
        else
            appInfo["useIpc"] = false
        if config.maxInactive isnt undefined
            appInfo["maxInactive"] = config.maxInactive
        else
            appInfo["maxInactive"] = -1
        Log.i "appInfo = #{JSON.stringify appInfo}"
        app = new Application appId, appInfo
        app.start()
        @respond req, res, 201

module.exports.DialAppControlHandler = DialAppControlHandler
