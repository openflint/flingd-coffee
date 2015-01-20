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

dgram   = require "dgram"
events  = require "events"
dns     = require "dns"
os      = require "os"
util    = require "util"

{ Log } = rekuire "log/Log"

class SSDP extends events.EventEmitter

    @signature = "Linux/3.8.13+, UPnP/1.0, Portable SDK for UPnP devices/1.6.18"
    @HttpHeader = /HTTP\/\d{1}\.\d{1} \d+ .*/
    @SsdpHeader = /^([^:]+):\s*(.*)$/

    constructor: (opts) ->
        opts = opts or {}
        @_init(opts)
        @_start()

        process.on "exit", =>
            @stop()

    search: (st) ->
        require("dns").lookup require("os").hostname(), (err, add) =>
            vars =
                "HOST": @_ipPort
                "ST": st
                "MAN": "\"ssdp:discover\""
                "MX": 3
            pkt = @_joinSSDPHeader "M-SEARCH", vars, false
            message = new Buffer pkt
            @sock.send message, 0, message.length, @_ssdpPort, @_ssdpIp, (err, bytes) =>

                #
                # Binds UDP socket to an interface/port
                # and starts advertising.
                #
    start: (ip, portno) ->
        @ip = ip
        @_httphost = "http://" + ip + ":" + portno
        Log.i "Will try to bind to 0.0.0.0:" + @_ssdpPort

        @sock.bind @_ssdpPort, "0.0.0.0", () =>
            Log.i "UDP socket bound to 0.0.0.0:" + @_ssdpPort

            setTimeout (=>
                @_advertise false), 10
            setTimeout (=>
                @_advertise false), 1000

            # Wake up.
            setTimeout (=>
                @_advertise true), 2000
            setTimeout (=>
                @_advertise true), 3000

            # Ad loop.
            setInterval (=>
                @_advertise true), 5000

    #
    # Advertise shutdown and close UDP socket.
    #
    stop: ->
        @_advertise false
        @_advertise false
        @sock.close()
        @sock = null

    #
    # Initializes instance properties.
    #
    _init: (opts) ->
        @_description = opts.description or "upnp/desc.html"
        @_udn = opts.udn or "uuid:f40c2981-7329-40b7-8b04-27f187aecfb5"
        @_target = opts.target or "urn:dial-multiscreen-org:service:dial:1"

        @_ssdpSig = opts.ssdpSig or SSDP.signature
        @_ssdpIp = opts.ssdpIp or "239.255.255.250"
        @_ssdpPort = opts.ssdpPort or 1900
        @_ipPort = @_ssdpIp + ":" + @_ssdpPort
        @_ssdpTtl = opts.ssdpTtl or 10
        @_ttl = opts.ttl or 1800

    #
    # Creates and configures a UDP socket.
    # Binds event listeners.
    #
    _start: () ->
        # Configure socket for either client or server.
        @responses = {};

        @sock = dgram.createSocket "udp4"

        @sock.on "error", (err) ->
            Log.e err, "SSDP socker error"

        @sock.on "message", (msg, rinfo) =>
            @_parseMessage msg, rinfo

        @sock.on "listening", =>
            addr = @sock.address()
            Log.d "SSDP listening on http://#{addr.address}:#{addr.port}"
            Log.i "addMembership #{@_ssdpIp}"
            @sock.addMembership @_ssdpIp, @ip
            Log.i "setMulticastTTL #{@_ssdpTtl}"
            @sock.setMulticastTTL @_ssdpTtl

    #
    # Routes a network message to the appropriate handler.
    #
    _parseMessage: (msg, rinfo) ->
        msg = msg.toString()
        type = msg.split("\r\n").shift()

        if SSDP.HttpHeader.test type
            @_parseResponse msg, rinfo
        else
            @_parseCommand msg, rinfo

    #
    # Parses SSDP response message.
    #
    _parseResponse: (msg, rinfo) ->
        # response like: HTTP/1.1 xxx
        if not @responses[rinfo.address]
            @responses[rinfo.address] = true
        @emit "response", msg, rinfo

    #
    # Parses SSDP command.
    #
    _parseCommand: (msg, rinfo) ->
        lines = msg.toString().split "\r\n"
        # command like: "NOTIFY * HTTP/1.1"
        type = lines.shift().split " "
        method = type[0]

        headers = {}

        lines.forEach (line) =>
            if line.length
                pairs = line.match SSDP.SsdpHeader
                if pairs
                    headers[pairs[1].toUpperCase()] = pairs[2] # e.g. {'HOST': 239.255.255.250:1900}

        switch method
            when "NOTIFY"
                @_notify headers, msg, rinfo
            when "M-SEARCH"
                @_msearch headers, msg, rinfo
            else
            # Log.i message: "\n" + msg, rinfo: rinfo, "Unhandled #{method} event"

    #
    # Handles NOTIFY command
    #
    _notify: (headers, msg, rinfo) ->
        if not headers.NTS then Log.i headers, "Missing NTS header"

        nts = headers.NTS.toLowerCase()
        switch nts
        # Device coming to life.
            when "ssdp:alive"
                @emit "advertise-alive", headers
        # Device shutting down.
            when "ssdp:byebye"
                @emit "advertise-bye", headers
            else
                Log.i message: "\n#{msg}", rinfo: rinfo, "Unhandled #{nts} event"

    #
    # Handles M-SEARCH command.
    #
    _msearch: (headers, msg, rinfo) ->
        if (not headers["MAN"]) or (not headers["MX"]) or (not headers["ST"]) then return
        @_inMSearch headers["ST"], rinfo

    _inMSearch: (st, rinfo) ->
        peer = rinfo.address
        port = rinfo.port

        if (st[0] is "\"") and (st[st.length - 1] is "\"")
            st = st.slice 1, -1 # unwrap quoted string

        if (st is "ssdp:all") or (@_target is st) or (@_udn.indexOf(st) >= 0)
            vars =
                "ST": @_target
                "USN": @_udn
                "LOCATION": "#{@_httphost}/#{@_description}"
                "CACHE-CONTROL": "max-age=#{@_ttl}"
                "DATE": (new Date()).toUTCString()
                "SERVER": @_ssdpSig
                "BOOTID.UPNP.ORG": "9"
                "CONFIGID.UPNP.ORG": "1"
                "OPT": "\"http://schemas.upnp.org/upnp/1/0/\"; ns=01"
                "X-USER-AGENT": "redsonic"
                "EXT": ""

            pkt = @_joinSSDPHeader "200 OK", vars, true
            message = new Buffer pkt
            @sock.send message, 0, message.length, port, peer, (err, bytes) =>

    _advertise: (alive) ->
        if not @sock then return
        if alive is undefined then alive = true

        heads =
            HOST: @_ipPort
            NT: @_target
            NTS: if alive then "ssdp:alive" else "ssdp:byebye"
            USN: @_udn

        if alive
            heads["LOCATION"] = @_httphost + "/" + @_description
            heads["CACHE-CONTROL"] = "max-age=1800"
            heads["SERVER"] = @_ssdpSig
            heads["BOOTID.UPNP.ORG"] = "9"
            heads["CONFIGID.UPNP.ORG"] = "1"
            heads["DATE"] = (new Date).toUTCString()
            heads["OPT"] = "\"http://schemas.upnp.org/upnp/1/0/\"; ns=01"
            heads["X-USER-AGENT"] = "redsonic"
            heads["EXT"] = ""

        pkt = @_joinSSDPHeader "NOTIFY", heads, false
        message = new Buffer pkt
        # Log.d "advertise message: #{message}"
        @sock.send message, 0, message.length, @_ssdpPort, @_ssdpIp, (err, bytes) =>

    _joinSSDPHeader: (head, vars, res) ->
        ret = ""
        if res
            ret = "HTTP/1.1 " + head + "\r\n"
        else
            ret = head + " * HTTP/1.1\r\n"
        Object.keys(vars).forEach (n) =>
            ret += n + ": " + vars[n] + "\r\n"

        return ret + "\r\n"

module.exports.SSDP = SSDP
