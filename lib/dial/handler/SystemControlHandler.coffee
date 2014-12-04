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

{ Log }         = rekuire "log/Log"
{ Platform }    = rekuire "platform/Platform"
{ Handler }     = rekuire "dial/handler/Handler"

class SystemControlHandler extends Handler

    onHttpRequest: (req, res) ->
        switch req.method
            when "POST"
                @_onPost req, res
            when "OPTIONS"
                headers =
                    "Access-Control-Allow-Methods": "POST, OPTIONS"
                @respondOptions req, res, headers
            else
                @respondUnSupport req, res

    _onPost: (req, res) ->
        platform = Platform.getInstance()
        data = null
        req.on "data", (_data) =>
            if not data then data = ""
            data += _data

        req.on "end", =>
            Log.d "SystemControlHandler receive data:\n#{data}"
            message = JSON.parse data
            if message and message.type
                switch message.type
                    when "GET_VOLUME", "GET_MUTED"
                        @_respondVolume req, res, message.type
                    when "SET_VOLUME"
                        if message.level
                            platform.setVolume message.level
                            @respond req, res, 200
                        else
                            @respondBadRequest req, res, "missing level"
                    when "SET_MUTED"
                        if message.muted isnt undefined
                            platform.setMuted message.muted
                            @respond req, res, 200
                        else
                            @respondBadRequest req, res, "missing muted"
                    else
                        @respondBadRequest req, res, "Unhandled message: #{data}"

    _respondVolume: (req, res, type) ->
        platform = Platform.getInstance()
        message =
            success: true
            request_type: type
        if type is "GET_VOLUME"
            message["level"] = platform.getVolume()
        if type is "GET_MUTED"
            message["muted"] = platform.getMuted()
        body = JSON.stringify message
        headers =
            "Content-Type": "application/json"
            "Content-Length": body.length
        @respond req, res, 200, headers, body

module.exports.SystemControlHandler = SystemControlHandler