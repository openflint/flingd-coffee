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

request         = require "request"

URL     = "http://127.0.0.1:9431/apps/"
APP_ID  = "~browser"
APP_URL = URL + APP_ID

# with headers
option =
    url: APP_URL
    method: "GET"
    headers: {
        Authorization: "EE2287DB-D10D-FECD-667B-8342AD095C33"
    }
request option, (error, response, body) =>
    console.log "GET #{APP_URL}"
    if error?
        console.log "error!!! #{error}"
    else
        console.log body

# without headers
request.get APP_URL, (error, response, body) =>
    console.log "GET #{APP_URL}"
    if error?
        console.log "error!!! #{error}"
    else
        console.log body