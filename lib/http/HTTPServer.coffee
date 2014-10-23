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

url     = require "url"
http    = require "http"
ws      = require "ws"

{ Log } = rekuire "log/Log"

class HTTPServer

    constructor: (@port) ->
        @routes = []

    getPort: ->
        return @port

    start: ->
        Log.i "Starting HTTP Server ..."

        @server = http.createServer()

        @server.on "request", (req, res) =>
            req.socket.setKeepAlive true
            req.socket.setNoDelay true
            @_onHttpRequest req, res

        @server.on "upgrade", (req, socket, upgradeHead) =>
            req.socket.setKeepAlive true
            req.socket.setNoDelay true
            wss = new ws.Server {noServer: true}
            wss.handleUpgrade req, socket, upgradeHead, (client) =>
                @_onWebSocketRequest req, client

        @server.listen @port

    addRoute: (path, handler) ->
        @routes.push
            path: path
            handler: handler

    _findHandler: (path) ->
        for route in @routes
            if path.match(route.path)
                return new route.handler
        return null

    _onHttpRequest: (req, res) ->
        Log.d "onHttpRequest: #{req.url}"
        segs = url.parse(req.url)
        handler = @_findHandler segs.path
        if handler
            handler.onHttpRequest(req, res)
        else
            res.writeHead 404
            res.end()

    _onWebSocketRequest: (req, client) ->
        Log.d "onWebSocketRequest: #{req.url}"
        segs = url.parse(req.url)
        handler = @_findHandler segs.path
        if handler
            handler.onWebSocketRequest req, client
        else
            client.close()

module.exports.HTTPServer = HTTPServer