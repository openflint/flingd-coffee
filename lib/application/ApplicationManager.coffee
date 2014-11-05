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

events              = require "events"

{ Log }             = rekuire "log/Log"
{ Platform }        = rekuire "platform/Platform"

class ApplicationManager extends events.EventEmitter

    @instance = null

    @getInstance: ->
        if not @instance
            @instance = new ApplicationManager
        return @instance

    constructor: ->
        @topApplication = null # running application
        @penddingApplication = [] # waiting for launching
        @launchingApplication = null # launching the application
        @stoppingApplication = null # stopping the application

        @.on "appstopped", (stoppedApplication)=>
            Log.i "[ApplicationManager] on [appstopped]"
            stoppedApplication.onStopped()
            @stoppingApplication = null
            if @penddingApplication.length > 0
                app = @penddingApplication.shift()
                ApplicationManager.instance.launchApplication app

        @.on "appstarted", (startedApplication) =>
            Log.i "[ApplicationManager] on [appstarted]"
            startedApplication.onStarted()
            @topApplication = startedApplication
            @launchingApplication = null
            if @penddingApplication.length > 0
                ApplicationManager.instance.stopApplication()

    stopApplicationById: (appId) ->
        app = @getAliveApplication()
        if app and appId and (appId is app.getAppId())
            @stopApplication()
        else
            Log.e "appid #{appId} not matched!!! cannot stop!!!"

    stopApplication: ->
        Log.i "stop application request!!!"
        if @stoppingApplication
            Log.e "#{@stoppingApplication.getAppId()} is stopping!!! cannot stop it twice!!! STH wrong!!!".bgRed
            return
        else if @topApplication
            Log.i "try to stop top application: #{@topApplication.getAppId()}"
            @_stopApplication @topApplication
            @topApplication = null
        else if @launchingApplication
            Log.i "try to stop launching application: #{@launchingApplication.getAppId()}"
            @_stopApplication @launchingApplication
            @launchingApplication = null
        else
            Log.e "no running or launching application, cannot stop!!!"

    _stopApplication: (app) ->
        Log.i "do real stop #{app.getAppId()}"
        @stoppingApplication = app
        Platform.getInstance().stopApplication app
        app.onStopping()

    launchApplication: (app) ->
        if not app
            Log.e "null app cannot be launched!!!"
            return

        app.setAppStatus "starting"
        if @launchingApplication
            Log.i "#{@launchingApplication.getAppId()} is launching"
            if @launchingApplication.getAppId() is app.getAppId()
                Log.w "#{app.getAppId()} is launching, ignore request"
            else
                Log.i "#{app.getAppId()} push into pendding queue!!!"
                @penddingApplication.push app
        else if @topApplication
            if @topApplication.getAppId() isnt app.getAppId()
                Log.i "#{@topApplication.getAppId()} is running, stop it first!!!"
                Log.i "#{app.getAppId()} is pendding top application!!!"
                @penddingApplication.push app
                @stopApplication()
            else
                Log.w "#{app.getAppId()} is already running, ignore request"
        else if @stoppingApplication
            Log.i "#{@stoppingApplication.getAppId()} is stopping, wait for it!!!"
            Log.i "#{app.getAppId()} is pendding stopping application!!!"
            @penddingApplication.push app
        else #launch
            @_launchApplication app

    _launchApplication: (app) ->
        Log.i "do real launch #{app.getAppId()}"
        @launchingApplication = app
        Platform.getInstance().launchApplication app
        app.onStarting()

    getCurrentApplication: ->
        return @topApplication

    getLaunchingApplication: ->
        return @launchingApplication

    getStoppingApplication: ->
        return @stoppingApplication

    getAliveApplication: ->
        if @topApplication
            return @topApplication
        else if @launchingApplication
            return @launchingApplication
        else if @penddingApplication.length > 0
            return @penddingApplication[0]
        else
            return null

module.exports.ApplicationManager = ApplicationManager