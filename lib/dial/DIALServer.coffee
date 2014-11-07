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

events                          = require "events"

{ Log }                         = rekuire "log/Log"
{ FlingAppControlHandler }      = rekuire "dial/handler/FlingAppControlHandler"
{ DialAppControlHandler }       = rekuire "dial/handler/DialAppControlHandler"
{ DialAdditionalDataHandler }   = rekuire "dial/handler/DialAdditionalDataHandler"
{ ReceiverConnectionHandler }   = rekuire "dial/handler/ReceiverConnectionHandler"
{ DeviceDescHandler }           = rekuire "dial/handler/DeviceDescHandler"
{ SetupIconHandler }            = rekuire "dial/handler/SetupIconHandler"
{ SystemControlHandler }        = rekuire "dial/handler/SystemControlHandler"
{ SessionManager }              = rekuire "dial/session/SessionManager"
{ SSDPServer }                  = rekuire "dial/discovery/SSDPServer"
{ MDNSServer }                  = rekuire "dial/discovery/MDNSServer"

class DIALServer extends events.EventEmitter

    constructor: (@httpServer, @networkChecker) ->
        @ssdpServer = new SSDPServer @networkChecker, @httpServer.getPort()
        @mdnsServer = new MDNSServer @networkChecker, @httpServer.getPort()

    start: ->
        SessionManager.init()

        @httpServer.addRoute /\/setup\/icon.png$/, SetupIconHandler
        @httpServer.addRoute /\/ssdp\/device-desc.xml$/, DeviceDescHandler
        @httpServer.addRoute /\/apps\/~[^\/]+$/, FlingAppControlHandler
        @httpServer.addRoute /\/apps\/~[^\/]+\/[a-zA-Z_0-9\-]+$/, FlingAppControlHandler
        @httpServer.addRoute /\/receiver\/[^\/]+$/, ReceiverConnectionHandler
        @httpServer.addRoute /\/system\/control$/, SystemControlHandler

        @httpServer.addRoute /\/apps\/[^~\/]+\/dial_data$/, DialAdditionalDataHandler
        @httpServer.addRoute /\/apps\/[^~\/]+$/, DialAppControlHandler
        @httpServer.addRoute /\/apps\/[^~\/]+\/[a-zA-Z_0-9\-]+$/, DialAppControlHandler

        @ssdpServer.start()
        @mdnsServer.start()

module.exports.DIALServer = DIALServer