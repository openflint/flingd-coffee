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

class SystemControlHandler

    constructor: ->

    onHttpRequest: (req, res) ->
        switch req.method
            when "POST"
                @_onPost req, res
            when "OPTIONS"
                headers =
                    "Access-Control-Allow-Method": "GET, POST, OPTIONS"
                    "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept,X-Requested-With, Custom-header"
                    "Cache-Control": "no-cache, must-revalidate, no-store"
                    "Access-Control-Allow-Origin": "*"
                    "Content-Length": "0"
                res.writeHead 200, headers
                res.end()
            else
                Log.e "Unsupport http method: #{method}"
                res.writeHead 400
                res.end()

    _onPost: (req, res) ->
        platform = Platform.getInstance()
        data = null
        req.on "data", (_data) =>
            if not data then data = ""
            data += _data

        req.on "end", =>
            Log.d "SystemControlHandler receive post:\n#{data}"
            message = JSON.parse data
            if message and message.type
                switch message.type
                    when "GET_VOLUME", "GET_MUTED"
                        @_onResponseMessage req, res, message.type
                    when "SET_VOLUME"
                        if message.level
                            platform.setVolume message.level
                            @_onResponseStatusCode req, res, 200
                        else
                            @_onResponseStatusCode req, res, 400
                    when "SET_MUTED"
                        if message.muted
                            platform.setMuted message.muted
                            @_onResponseStatusCode req, res, 200
                        else
                            @_onResponseStatusCode req, res, 400
                    else
                        Log.e "Unhandled system message received: #{data}"
                        res.statusCode = 400
                        res.end()

    _onResponseStatusCode: (req, res, statusCode) ->
        headers =
            "Access-Control-Allow-Method": "POST, OPTIONS"
            "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept,X-Requested-With, Custom-header"
            "Cache-Control": "no-cache, must-revalidate, no-store"
            "Access-Control-Allow-Origin": "*"
            "Content-Length": "0"
        res.writeHead statusCode, headers
        res.end()

    _onResponseMessage: (req, res, type) ->
        platform = Platform.getInstance()
        message =
            success: true
            request_type: type
            level: platform.getVolume()
            muted: platform.getMuted()
        body = JSON.stringify message
        res.writeHead 200,
            "Content-Type": "application/json"
            "Connection": "keep-alive"
            "Access-Control-Allow-Method": "POST, OPTIONS"
            "Access-Control-Allow-Origin": "*"
            "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept,X-Requested-With, Custom-header"
            "Cache-Control": "no-cache, must-revalidate, no-store"
            "Content-Length": body.length
        res.end body

module.exports.SystemControlHandler = SystemControlHandler