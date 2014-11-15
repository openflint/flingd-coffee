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

fs              = rekuire "fs"
child_process   = rekuire "child_process"

{ Log }         = rekuire "log/Log"
{ Platform }    = rekuire "platform/Platform"

class PlatformDarwin extends Platform

    constructor: ->
        super
        @receiver_container = process.env.RECEIVER_CONTAINER
        if @receiver_container == 'firefox'
            @chrome_path = "/Applications/Firefox.app/Contents/MacOS/firefox"
        else
            @chrome_path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

        @name = "MatchStick_MAC_" + String(@deviceUUID).replace(/-/g, '').substr(-4)
        Log.d "PlatformDarwin: #{@name}"
        setTimeout ( => @emit "device_name_changed", @name)
            , 2000

    launchApplication: (app) ->
        if (not app) or (not app.getAppInfo()) or (not app.getAppInfo().url)
            Log.e "PlatformDarwin.launchApplication: bad parameter!!!"
            return
        appUrl = app.getAppInfo().url
        Log.d "PlatformDarwin.launchApplication: #{appUrl}"
        if @receiver_container == "firefox"
            @chromeProcess = child_process.spawn @chrome_path, [
                appUrl
            ]
        else
            @chromeProcess = child_process.spawn @chrome_path, [
                "--no-default-browser-check",
                "--enable-logging",
                "--no-first-run",
                "--disable-application-cache",
                "--disable-cache",
                "--enable-kiosk-mode",
                "--kiosk",
                "--start-maximized",
                "--window-size=1280,720",
                "--single-process",
                "--allow-insecure-websocket-from-https-origin",
                "--allow-running-insecure-content",
                "--app=" + appUrl,
                "--user-data-dir=/tmp/" + @deviceUUID
            ]

        @chromeProcess.stdout.on 'data', (chunk) =>
#            Log.d "darwin stdout: #{chunk}"
        @chromeProcess.stderr.on 'data', (chunk) =>
#            Log.e "darwin stderr: #{chunk}"
        @chromeProcess.on 'exit', () =>
            Log.i "darwin chrome exit!!!"

    stopApplication: (app) ->
        Log.d "PlatformDarwin.stopApplication"
        if @chromeProcess
            @chromeProcess.kill('SIGTERM')

module.exports.PlatformDarwin = PlatformDarwin
