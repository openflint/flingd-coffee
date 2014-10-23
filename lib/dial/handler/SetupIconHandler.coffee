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

events              = require "events"

{ ResourceManager } = rekuire "res/ResourceManager"

class SetupIconHandler extends events.EventEmitter

    @img = null

    constructor: ->
        SetupIconHandler.img = ResourceManager.getRes "MatchStick.png"

    onHttpRequest: (req, res) ->
        res.writeHead 200,
            "Content-Type": "image/png"
        res.write SetupIconHandler.img, "binary"
        res.end()

module.exports.SetupIconHandler = SetupIconHandler