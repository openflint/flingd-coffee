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

class DialAdditionalDataHandler extends Handler

    onHttpRequest: (req, res) ->
        Log.i "DialAdditionalDataHandler: #{req.method} -> #{req.url}"
        segs = url.parse req.url
        appId = S(segs.path).replaceAll("/apps/", "").s
        appId = S(appId).replaceAll("/dial_data$", "").s
        if not appId
            @respondBadRequest req, res, "missing appId"
            return
        else if not ApplicationConfigs[appId]
            @respondBadRequest req, res, "not support #{appId}"
            return

        switch req.method
            when "POST"
                @_onPost req, res, appId
            when "OPTIONS"
                headers =
                    "Access-Control-Allow-Methods": "POST, OPTIONS"
                @respondOptions req, res, headers
            else
                @respondUnSupport req, res

    _onPost: (req, res, appId) ->
        data = null
        req.on "data", (_data) =>
            if not data then data = ""
            data += _data

        req.on "end", =>
            Log.d "DialAdditionalDataHandler receive post:\n#{data}"
            app = ApplicationManager.getInstance().getAliveApplication()
            if app
                if app.getAppId() is appId
                    app.setAdditionalData data
                    @respond req, res, 200
                    return
            @respondBadRequest req, res, "set #{appId} additional data failed!"

module.exports.DialAdditionalDataHandler = DialAdditionalDataHandler
