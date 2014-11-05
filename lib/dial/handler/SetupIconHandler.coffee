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

{ Log }             = rekuire "log/Log"
{ ResourceManager } = rekuire "res/ResourceManager"
{ Handler }         = rekuire "dial/handler/Handler"

class SetupIconHandler extends Handler

    @img = null

    constructor: ->
        if not SetupIconHandler.img
            SetupIconHandler.img = ResourceManager.getRes "MatchStick.png"

    onHttpRequest: (req, res) ->
        switch req.method
            when "GET", "POST"
                @_onGetOrPost req, res
            when "OPTIONS"
                headers =
                    "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
                @respondOptions req, res, headers
            else
                @respondUnSupport req, res

    _onGetOrPost: (req, res) ->
        headers =
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
            "Access-Control-Allow-Origin": "*"
            "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept*, X-Requested-With"
            "Content-Type": "image/png"
        res.writeHead 200, headers
        res.write SetupIconHandler.img, "binary"
        res.end()

module.exports.SetupIconHandler = SetupIconHandler