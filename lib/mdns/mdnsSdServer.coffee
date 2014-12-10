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

events          = require "events"
os              = require "os"

{ Log }         = rekuire "log/Log"
{ MDNSHelper }  = rekuire "mdns/MDNSHelper"
{ Platform }    = rekuire "platform/Platform"

class mdnsSdServer extends events.EventEmitter

    @MDNS_ADDRESS = "224.0.0.251"
    @MDNS_PORT = 5353
    @MDNS_TTL = 1
    @MDNS_LOOPBACK_MODE = true

    constructor: ->
        events.EventEmitter.call(this)
        @on "ready", =>
            Log.d "MDNSServer is ready !"

        @fullProtocol
        @serverName 
        @txtRecord
        @serverPort
        @flags  
        @address = @getAddress()
        @localName 
        @dnsSdResponse
        @dnsSdKeepResponse

    getAddress: ->
        address = {} 
        ifaces = os.networkInterfaces()
        for k,v of ifaces
            if (k.toLowerCase().indexOf "lo") < 0
                ipadd = {}
                for i in v
                    if i.family == "IPv4"
                        ipadd.ipv4 = i.address
                    if i.family == "IPv6"
                        ipadd.ipv6 = i.address
                # castd node ipv6 not found
                if ipadd.ipv4 #&& ipadd.ipv6
                    address = ipadd
                    break
        return address

    set: (fullProtocol, port, options) ->
        @fullProtocol = fullProtocol
        @serverPort = port
        @serverName = options.name
        @txtRecord = options.txtRecord
        @flags = options.flags
        @resetDnsSdResponse()

    resetDnsSdResponse: ->
        @address = @getAddress()
        @localName = @serverName + @address.ipv4 
        if @address.ipv4
            @dnsSdResponse = MDNSHelper.creatDnsSdResponse 0, @fullProtocol, @serverName, @serverPort, @txtRecord, @address, @localName
            @dnsSdKeepResponse = MDNSHelper.creatDnsSdKeepResponse 0, @fullProtocol, @serverName, @serverPort, @txtRecord, @address, @localName

    _start: ->
        if !@running 
            @address = @getAddress()
            @resetDnsSdResponse()
            if @address.ipv4 && @dnsSdResponse
                Log.d "Starting MDNSServer ..."

                dgram = require "dgram"
                @socket = dgram.createSocket "udp4"

                @socket.on "error", (err) =>
                    Log.e err

                @socket.on "message", (data, rinfo) =>
                    @onReceive data, rinfo.address, rinfo.port

                @socket.on "listening", =>
                    Log.d "MDNS socket is listened"
                    @socket.setMulticastTTL mdnsSdServer.MDNS_TTL
                    @socket.setMulticastLoopback mdnsSdServer.MDNS_LOOPBACK_MODE

                @socket.bind mdnsSdServer.MDNS_PORT, "0.0.0.0", =>
                    Log.d "MDNS socket is binded"
                    @socket.addMembership mdnsSdServer.MDNS_ADDRESS, @address.ipv4
                    @running = true
                    @emit "ready"
                @status = "running"
                @keepActive()

            else
                Log.d "MDNSServer start fail"
                if not @dnsSdResponse
                    Log.d "MDNSServer dont config , please config"
                if not @address.ipv4
                    Log.d "MDNSServer dont ipv4, please check network"

    start: ->
        @status = "strating"
        @_start()
        @startLoop = setInterval (=>
            @_start() ), 5000
#        @keepActiveLoop = setInterval (=>
#            @keepActive() ), 8000

    stop: ->
        if @status == "running"
            clearInterval @startLoop
            clearInterval @keepActiveLoop
            @socket.close()
            @status = "stoped"
            Log.d "MDNSServer stop"

    keepActive: ->
        if @dnsSdKeepResponse
            @dnsSdKeepResponse.transactionID = 0
            buff = new Buffer MDNSHelper.encodeMessage @dnsSdKeepResponse
            if @status and @status == "running"
                @socket.send buff, 0, buff.length, mdnsSdServer.MDNS_PORT, mdnsSdServer.MDNS_ADDRESS, =>
                    Log.i "mdnsResponse to #{mdnsSdServer.MDNS_ADDRESS}:#{mdnsSdServer.MDNS_PORT} done".red

    onReceive: (data, address, port) ->
        try
            message = MDNSHelper.decodeMessage data
        catch error
            Log.d  "error: #{error}"
            Log.d "#{address}: data #{data}"
        if message && message.isQuery
            for question in message.questions
                if question.name.toLowerCase() is @fullProtocol.toLowerCase()
                    if question.type is MDNSHelper.TYPE_PTR
                        @dnsSdResponse.transactionID = message.transactionID
                        buff = new Buffer MDNSHelper.encodeMessage @dnsSdResponse
                        Log.i "mdns receive message: #{message}".red
                        @socket.send buff, 0, buff.length, port, address, =>
                            Log.i "mdnsResponse to #{address}:#{port} done".red

module.exports.mdnsSdServer = mdnsSdServer
