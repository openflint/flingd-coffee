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

os              = require "os"
events          = require "events"

{ Log }         = rekuire "log/Log"
{ UUID }        = rekuire "util/UUID"

class Platform extends events.EventEmitter

    constructor: ->
        @deviceUUID = UUID.randomUUID().toString()
        @name = null
        @volumeLevel = 1.0
        @volumeMuted = false

    getDeviceName: ->
        return @name

    getDeviceUUID: ->
        return @deviceUUID

    launchApplication: (app) ->
        throw "Not Implemented"

    stopApplication: (app)->
        throw "Not Implemented"

    getVolume: ->
        Log.i "get volume: #{@volumeLevel}"
        return @volumeLevel

    setVolume: (volumeLevel) ->
        if (volumeLevel < 0) or (volumeLevel > 1)
            Log.e "#{volumeLevel} is out of range[0-1]"
            return
        @volumeLevel = volumeLevel
        if @volumeLevel > 0
            @volumeMuted = false
        else
            @volumeMuted = true
        @_onVolumeSet()
        Log.i "set volume: #{@volumeLevel}"

    getMuted: ->
        Log.i "get muted: #{@volumeMuted}"
        return @volumeMuted

    setMuted: (muted) ->
        @volumeMuted = muted
        @_onVolumeSet()
        Log.i "set muted: #{@volumeMuted}"

    #
    # sub-class maybe implement it
    #
    _onVolumeSet: ->
        null

    @getInstance: ->
        if not @instance
            if os.platform() is "android"
                { PlatformFirefoxOS } = rekuire "platform/PlatformFirefoxOS"
                @instance = new PlatformFirefoxOS
            else if os.platform() is "darwin"
                { PlatformDarwin } = rekuire "platform/PlatformDarwin"
                @instance = new PlatformDarwin
            else if os.platform() is "linux"
                { PlatformLinux } = rekuire "platform/PlatformLinux"
                @instance = new PlatformLinux
            else
                Log.e "unsupport platform: ", os.platform()
                throw new Error "unsupport platform!!!"
        return @instance

module.exports.Platform = Platform