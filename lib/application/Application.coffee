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

events                  = require "events"
jsontoxml               = require "jsontoxml"

{ Log }                 = rekuire "log/Log"
{ ApplicationManager }  = rekuire "application/ApplicationManager"

class Application extends events.EventEmitter

    constructor: (@appId, @appInfo) ->
        @state = "stopped"
        @timerId = null
        @additionalData = ""

    getAppId: ->
        return @appId

    getAppStatus: ->
        return @state

    setAppStatus: (appStatus) ->
        @state = appStatus
        Log.d "Application #{@appId} is #{@state}"

    setAdditionalDataWithJson: (data) ->
        if not data
            return
        @additionalData = ""
        @additionalData += "<additionalData>\n"
        @additionalData += jsontoxml(data)
        @additionalData += "\n"
        @additionalData += "</additionalData>\n"

    setAdditionalData: (data) ->
        if not data
            return
        @additionalData = ""
        @additionalData += "<additionalData>\n"
        @additionalData += data
        @additionalData += "\n"
        @additionalData += "</additionalData>\n"

    getAdditionalData: ->
        @additionalData

    getAppInfo: ->
        return @appInfo

    start: ->
        ApplicationManager.getInstance().launchApplication this

    #
    # launch ready, notify ApplicationManager
    #
    started: ->
        ApplicationManager.getInstance().emit "appstarted", this

    onStarting: ->
        @setAppStatus "starting"
        @emit "onstarting", this
        if not @appInfo.useIpc
            @started()
            if @appInfo.maxInactive > 0
                callback = =>
                    Log.d "maxInactive timeout, terminate application"
                    @stop()
                @timerId = setTimeout callback, @appInfo.maxInactive
            else
                Log.i "maxInactive is #{@appInfo.maxInactive}, alive forever"
        else
            callback = =>
                Log.d "starting timeout, terminate application"
                @stop()
            @timerId = setTimeout callback, 30 * 1000 #starting should be done in 30s

    onStarted: ->
        @setAppStatus "running"
        @emit "onstarted", this
        @clearTimer()

    stop: ->
        @clearTimer()
        ApplicationManager.getInstance().stopApplication()

    #
    # stop finished, notify ApplicationManager
    #
    stopped: ->
        ApplicationManager.getInstance().emit "appstopped", this

    onStopping: ->
        @setAppStatus "stopping"
        @emit "onstopping", this
        if @appInfo.useIpc
            callback = =>
                Log.d "stopping timeout, terminate application"
                @stopped()
            @timerId = setTimeout callback, 3 * 1000 #stopping should be done in 10s
        else
            @stopped()

    onStopped: ->
        @setAppStatus "stopped"
        @emit "onstopped", this
        @clearTimer()

    clearTimer: ->
        if @timerId
            clearTimeout @timerId

module.exports.Application = Application