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

util                = require "util"
os                  = require "os"
child_process       = require "child_process"

{ Log }             = rekuire "log/Log"
{ Platform }        = rekuire "platform/Platform"
mdns                = rekuire "mdns/mdns"


class MDNSServer

    constructor: (@networkChecker, @port) ->

    startServer: (name) ->
        Log.d "MDNSServer.startServer : #{name}"

        options = {};
        options.name = name;
        options.flags = 2;
        options.txtRecord =
            id: name
            ve: "02"
            md: "MatchStick"
            ic: "/setup/icon.png"
            ca: "5"
            fn: name
            st: "0"

        if @advertisement && @advertisement.status
            Log.d "reset MDNSServer ..."
            @advertisement.set mdns.tcp("openflint"), @port, options
            if @advertisement.status == "stoped"
                @advertisement.start()
        else
            Log.d "create MDNSServer ..."
            @advertisement = mdns.createAdvertisement mdns.tcp("openflint"), @port, options
            @advertisement.start()

    resetServer: (name) ->
        @startServer name

    stopServer: ->
        Log.d "stop MDNSServer ..."
        if @advertisement && @advertisement.status
            Log.d "real stop MDNSServer ..."
            @advertisement.stop()

    start: ->
        Log.d "Starting MDNSServer ..."

        Platform.getInstance().on "device_name_changed", (name) =>
            Log.i "MDNS: deviceNameChanged: #{name}"
            @resetServer name

        Platform.getInstance().on "network_changed", (changed) =>
            Log.i "MDNS: network_changed: #{changed}"
            if "ap" == changed or "station" == changed
                deviceName = Platform.getInstance().getDeviceName()
                if deviceName
                    @stopServer()
                    @resetServer deviceName
            else
                Log.i "MDNS: unknow network_changed"

module.exports.MDNSServer = MDNSServer
