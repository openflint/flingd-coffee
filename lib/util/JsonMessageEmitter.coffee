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

fs      = require "fs"
net     = require "net"
util    = require "util"

{ Log } = rekuire "log/Log"

class JsonMessageEmitter

    constructor: (socket, callback) ->
        @callback = callback
        @messageSize = -1
        @buffer = new Buffer 0

        socket.on "readable", =>
            null

        socket.on "end", =>
            null

        socket.on "error", (err) ->
            Log.e "JsonMessageEmitter Error: ", err.toString()

        socket.on "data", (data) =>
            @_didReceiveNetworkData(data)

    _didReceiveNetworkData: (data) ->
        @buffer = Buffer.concat [@buffer, data]
        while (true)
            if @messageSize < 0
                colonIndex = @_findColon @buffer
                if colonIndex > 0
                    @messageSize = parseInt @buffer.slice(0, colonIndex).toString()
                    @buffer = @buffer.slice colonIndex + 1
                else
                    break

            if @messageSize > 0
                if @buffer.length >= @messageSize
                    msgBuffer = @buffer.slice 0, @messageSize
                    msg = JSON.parse msgBuffer.toString()
                    if @callback
                        @callback msg
                    if @buffer.length > @messageSize
                        @buffer = @buffer.slice @messageSize
                    else
                        @buffer = new Buffer 0
                    @messageSize = -1
                else
                    break

    _findColon: (buffer) ->
        colonCode = ':'.charCodeAt(0)
        for i in [0 .. buffer.length]
            if buffer[i] is colonCode
                return i;
        return -1

module.exports.JsonMessageEmitter = JsonMessageEmitter