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
{ SSDP }            = rekuire "upnp/SSDP"
{ Platform }        = rekuire "platform/Platform"
{ HashTable }       = rekuire "util/HashTable"
{ NetworkChecker }  = rekuire "network/NetworkChecker"

class SSDPServer

    constructor: (@networkChecker, @port) ->
        @servers = new HashTable

    start: ->
        removeServer = (ipAddr) =>
            Log.d "Stop SSDP Server for IP: #{ipAddr}"
            ssdp = @servers.remove ipAddr
            ssdp.stop()

        addServer = (ipAddr) =>
            Log.d "Starting SSDP Server for IP: #{ipAddr}"
            uuid = Platform.getInstance().getDeviceUUID()
            ssdp = new SSDP
                description: "ssdp/device-desc.xml"
                udn: "uuid:#{uuid}::urn:dial-multiscreen-org:service:dial:1"
                target: "urn:dial-multiscreen-org:service:dial:1"
            ssdp.start ipAddr, @port
            @servers.put ipAddr, ssdp

        @networkChecker.on NetworkChecker.EVENT_ADDRESS_ADDED, (event) =>
            Log.i "EVENT_ADDRESS_ADDED: #{event.address}"
            addServer event.address

        @networkChecker.on NetworkChecker.EVENT_ADDRESS_REMOVED, (event) =>
            Log.i "EVENT_ADDRESS_REMOVED: #{event.address}"
            removeServer event.address

module.exports.SSDPServer = SSDPServer