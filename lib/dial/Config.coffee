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

class Config

    # timeout between flingd and receiver application
    @SENDER_SESSION_TIMEOUT = 10 * 1000

    # ping/pong interval between flingd and sender
    @SENDER_SESSION_PP_INTERVAL = 3 * 1000

    # ping/pong interval between flingd and receiver application
    @RECEIVER_SESSION_PP_INTERVAL = 3 * 1000

    # timeout between flingd and receiver application
    @RECEIVER_SESSION_TIMEOUT = 10 * 1000

    # HTTP server
    @HTTP_SERVER_PORT = 9431

    # Communication modules' port
    @PEERJS_SERVER_PORT = 9433
    @SOCKET_IO_SERVER_PORT = 9437
    @WEBSOCKET_SERVER_PORT = 9439

    @FFOS_PAL_SERVER_PORT = 9440

    @APPLICATION_INSTANCE = "run"

module.exports.Config = Config