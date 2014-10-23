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

request = require "request"

URL     = "http://127.0.0.1:9431/system/control"

#
# GET_VOLUME
#
get_volume = ->
    GET_VOLUME =
        type: "GET_VOLUME"
    option =
        url: URL
        method: "POST"
        json: GET_VOLUME
    request option, (error, response, body) =>
        console.log "get_volume #{URL}"
        if error?
            console.log "error!!! #{error}"
        else
            console.log body

#
# SET_VOLUME
#
set_volume = (volume) ->
    SET_VOLUME =
        type: "SET_VOLUME"
        level: volume
    option =
        url: URL
        method: "POST"
        json: SET_VOLUME
    request option, (error, response, body) =>
        console.log "set_volume #{URL}"
        if error?
            console.log "error!!! #{error}"
        else
            console.log body

#
# GET_MUTED
#
get_muted = ->
    GET_MUTED =
        type: "GET_MUTED"
    option =
        url: URL
        method: "POST"
        json: GET_MUTED
    request option, (error, response, body) =>
        console.log "get_muted #{URL}"
        if error?
            console.log "error!!! #{error}"
        else
            console.log body

#
# SET_MUTED
#
set_muted = (muted) ->
    SET_MUTED =
        type: "SET_MUTED"
        muted: muted
    option =
        url: URL
        method: "POST"
        json: SET_MUTED
    request option, (error, response, body) =>
        console.log "set_muted #{URL}"
        if error?
            console.log "error!!! #{error}"
        else
            console.log body

get_volume()
set_volume 0.1
get_volume()
set_volume 0.5
get_volume()
set_volume 1.5


get_muted()
set_muted false
get_muted()