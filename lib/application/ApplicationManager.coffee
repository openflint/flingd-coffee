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
            Log.i "ApplicationManager on appstopped"
            stoppedApplication.onStopped()
            @stoppingApplication = null
            if @launchingApplication
                ApplicationManager.instance.launchApplication @launchingApplication
        @.on "appstarted", (startedApplication) =>
            Log.i "ApplicationManager on appstarted"
            startedApplication.onStarted()
            @topApplication = startedApplication
            @launchingApplication = null
            if @penddingApplication.length > 0
                @launchingApplication = @penddingApplication.shift()
                ApplicationManager.instance.stopApplication()

    stopTopApplication: ->
        app = @getCurrentApplication()
        if app
            @stopApplication app
        else
            Log.w "No top application, cannot stop!!!"

    stopApplication: (app) ->
        # is stopping!!!
        if @stoppingApplication
            Log.w "Previous stopping is not finished!!!"
            return
        if not app
            Log.w "cannot stop a null application!!!"
            return

        if @topApplication
            if @topApplication.getAppId() isnt app.getAppId()
                Log.w "running Application id not match, cannot stop!!!"
            else
                Log.w "stop running application: #{@topApplication?.getAppId()}!!!"
                @stoppingApplication = @topApplication
                @topApplication = null
                @stoppingApplication.onStopping()
                Platform.getInstance().stopApplication @stoppingApplication
        else if @launchingApplication
            if @launchingApplication.getAppId() isnt app.getAppId()
                Log.w "launching Application id not match, cannot stop!!!"
            else
                Log.w "stop launching application: #{@launchingApplication.getAppId()}!!!"
                @stoppingApplication = @launchingApplication
                @launchingApplication = null
                @stoppingApplication.onStopping()
                Platform.getInstance().stopApplication @stoppingApplication
        else
            Log.e "no running or launching application, cannot stop!!!"

    launchApplication: (app) ->
        # no application is running
        if not @topApplication
            if app
                @launchingApplication = app
            else
                if not @launchingApplication
                    if @penddingApplication.length > 0
                        @launchingApplication = @penddingApplication.shift()
                    else
                        Log.w "No application need to launch!!!"
                        return
            if @launchingApplication
                Platform.getInstance().launchApplication @launchingApplication
                @launchingApplication.onStarting()
            else
                Log.w "launchingApplication is null, No application need to launch!!!"
        else
            if app
                if app.getAppId() is @topApplication.getAppId()
                    Log.w "the application #{@topApplication.getAppId()} is already launched!!!"
                else
                    if not @launchingApplication
                        _app = @launchingApplication
                        @launchingApplication = app
                        ApplicationManager.instance.stopApplication _app
                    else
                        @penddingApplication.push app
            else
                Log.w "application should not be null, cannot be launched!!!".red

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
        else
            return null

module.exports.ApplicationManager = ApplicationManager