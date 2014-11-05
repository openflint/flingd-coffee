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

{ Log }                     = rekuire "log/Log"

class Handler

    respondBadRequest: (req, res, msg) ->
        Log.e "Bad request: #{msg}"
        @respond req, res, 400

    respondUnSupport: (req, res) ->
        Log.e "Unsupport http method: #{req.method}"
        @respond req, res, 400

    respondOptions: (req, res, headers) ->
        if headers
            if not headers["Access-Control-Max-Age"]
                headers["Access-Control-Max-Age"] = 60
        else
            headers =
                "Access-Control-Max-Age": 60
        @respond req, res, 200, headers, null

    #
    # support CORS
    #
    respond: (req, res, statusCode, headers, body) ->
        if headers
            if not headers["Access-Control-Allow-Methods"]
                headers["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS"
            if not headers["Access-Control-Allow-Origin"]
                headers["Access-Control-Allow-Origin"] = "*"
            if not headers["Access-Control-Allow-Headers"]
                headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, Accept*, X-Requested-With"
        else
            headers =
                "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS"
                "Access-Control-Allow-Origin": "*"
                "Access-Control-Allow-Headers": "Content-Type, Authorization, Accept*, X-Requested-With"
        res.writeHead statusCode, headers

        if body
            res.end body
        else
            res.end()

module.exports.Handler = Handler