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
# limitations under the License.
#

class SocketIOServer

    constructor: (opts) ->
        @port = opts.port

    start: ->
        channels = {}

        io = (require 'socket.io') @port;

        onNewNamespace = (channel, rsocket) =>

            # sender connection
            io.of('/' + channel).on 'connection', (socket) =>
                console.log 'sender socket connection'

                senderId = null

                # notify socket connected
                socket.emit 'connect', true

                # receiver to sender
                rsocket.on 'message', (message) =>
                    if message?.senderId == '*:*' or message?.senderId == senderId
                        socket.emit 'message', message.data

                # sender to receiver
                socket.on 'message', (message) =>
                    console.log 'sender message', message

                    if not senderId
                        senderId = message.senderId
                        rsocket.emit 'senderConnected',
                            senderId: senderId

                    rsocket.emit 'message', message

                socket.on 'disconnect', =>
                    if senderId
                        rsocket.emit 'senderDisconnected',
                            senderId: senderId
                        senderId = null

        io.on 'connection', (socket) =>
            initiatorChannel = ''

            # create new channel
            socket.on 'new-channel', (data) =>
                console.log 'new-channel', data
                if data.channel
                    if not channels[data.channel]
                        initiatorChannel = data.channel
                    channels[data.channel] = data.channel
                    onNewNamespace data.channel, socket
                else
                    socket.close()

            socket.on 'presence', (channel) =>
                isChannelPresent = not not channels[channel]
                socket.emit 'presence', isChannelPresent

            socket.on 'disconnect', =>
                console.log 'receiver socket disconnected'
                if initiatorChannel
                    delete channels[initiatorChannel]

module.exports.SocketIOServer = SocketIOServer