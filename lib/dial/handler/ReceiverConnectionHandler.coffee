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

S                       = require "string"
url                     = require "url"

{ Log }                 = rekuire "log/Log"
{ ApplicationManager }  = rekuire "application/ApplicationManager"
{ SessionManager }      = rekuire "dial/session/SessionManager"

class ReceiverConnectionHandler

    constructor: ->

    onWebSocketRequest: (req, client) ->
        checked = true
        segs = url.parse req.url
        appId = S(segs.path).replaceAll("/receiver", "").s
        app = ApplicationManager.getInstance().getAliveApplication()

        # check appId and application
        if appId
            appId = S(appId).replaceAll("/", "").s
            if (not app) or (appId isnt app?.getAppId())
                checked = false
        else
            if not app
                checked = false
            else
                appId = app.getAppId()

        if checked
            SessionManager.getInstance().setReceiverSession appId, client
        else
            Log.e "receiver channel checked failed, close websocket!!!"
            client.close()

module.exports.ReceiverConnectionHandler = ReceiverConnectionHandler
