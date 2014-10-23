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

os      = require "os"
events  = require "events"

class NetworkChecker extends events.EventEmitter

    @NETWORK_CHECK_INTERVAL = 5 * 1000

    @EVENT_ADDRESS_ADDED = "addressAdded"
    @EVENT_ADDRESS_REMOVED = "addressRemoved"

    constructor: ->
        @knownAddresses = []

    knowAddresses: ->
        resultAddress = []
        for address in @knownAddresses
            resultAddress.push address
        return resultAddress

    start: ->
        onTimeout = =>
            currentAddresses = []

            networkInterfaces = os.networkInterfaces()
            for iface of networkInterfaces
                for addressInfo in networkInterfaces[iface]
                    if not addressInfo.internal and addressInfo.family is "IPv4"
                        currentAddresses.push addressInfo.address

            contain = (addressArray, address) =>
                for arrayAddress in addressArray
                    if arrayAddress is address
                        return true
                return false

            lastAddresses = @knownAddresses
            @knownAddresses = currentAddresses

            for address in lastAddresses
                if not contain currentAddresses, address
                    @emit NetworkChecker.EVENT_ADDRESS_REMOVED,
                        sender: this
                        address: address

            for address in currentAddresses
                if not contain lastAddresses, address
                    @emit NetworkChecker.EVENT_ADDRESS_ADDED,
                        sender: this
                        address: address

        process.nextTick onTimeout
        setInterval onTimeout, NetworkChecker.NETWORK_CHECK_INTERVAL

module.exports.NetworkChecker = NetworkChecker