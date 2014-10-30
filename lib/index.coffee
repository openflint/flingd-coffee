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

global.rekuire      = require "rekuire"

{ Log }             = rekuire "log/Log"
{ DIALServer }      = rekuire "dial/DIALServer"
{ HTTPServer }      = rekuire "http/HTTPServer"
{ NetworkChecker }  = rekuire "network/NetworkChecker"
{ Config }          = rekuire "dial/Config"
{ PeerServer }      = rekuire "peer"
{ WebSocketServer } = rekuire "comm/WebSocketServer"

run = ->
    Log.i "flingd is running!!!"
    Log.d "flingd is running!!!"
    Log.w "flingd is running!!!"
    Log.e "flingd is running!!!"

    networkChecker = new NetworkChecker
    networkChecker.start()

    httpServer = new HTTPServer Config.HTTP_SERVER_PORT

    dialServer = new DIALServer httpServer, networkChecker
    dialServer.start()

    httpServer.start()

    peerServer = new PeerServer { port: Config.PEERJS_SERVER_PORT }

    websocketServer = new WebSocketServer { port: Config.WEBSOCKET_SERVER_PORT }
    websocketServer.start()

module.exports.run = run
