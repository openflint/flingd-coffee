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

{ Singleton }       = rekuire "util/Singleton"
{ UUID }            = rekuire "util/UUID"
{ Session }         = rekuire "dial/session/Session"
{ SenderSession }   = rekuire "dial/session/SenderSession"
{ ReceiverSession } = rekuire "dial/session/ReceiverSession"
{ Log }             = rekuire "log/Log"
{ HashSet }         = rekuire "util/HashSet"
{ HashTable }       = rekuire "util/HashTable"

class SessionManager extends Singleton

    @init: ->
        super()
        @instance = new SessionManager

    constructor: ->
        Log.d "SessionManager is ready!!!"
        @senderSessions = new HashTable
        @receiverSession = null
        @pendingConnectedSession = new HashTable

    clearReceiverSession: ->
        @receiverSession = null
        @pendingConnectedSession.clear()

    setReceiverSession: (appId, channel) ->
        if (not appId) or (not channel)
            Log.e "appId: #{appId} or channel:#{channel} is illegal!!!"
            return
        token = @_generateSessionToken()
        @receiverSession = new ReceiverSession this, token, appId, channel
        keys = @pendingConnectedSession.keys()
        for key in keys
            session = @pendingConnectedSession.get key
            @receiverSession.senderConnected session
        @pendingConnectedSession.clear()

    sessionConnected: (session) ->
        # filter exist session
        token = session.getToken()
        if @senderSessions.containsKey token
            Log.w "session #{token} is already connected!"
            return
        Log.d "session #{token} connected!"
        @_addSession token, session
        session.triggerTimer()
        if @receiverSession
            @receiverSession.senderConnected session
        else
            @pendingConnectedSession.put session.getToken(), session

    sessionDisconnectedByToken: (token) ->
        session = @_getSession token
        @sessionDisconnected session

    sessionDisconnected: (session) ->
        if session
            sesson.clearTimer()
            @_removeSession session.getToken()
            @receiverSession?.senderDisconnected session

    createSenderSession: (appId) ->
        token = @_generateSessionToken()
        Log.d "create new sender session: #{token}"
        session = new SenderSession this, token, appId
        return session

    touchSession: (token) ->
        session = @_getSession token
        session?.triggerTimer()

    checkSession: (token) ->
        session = @_getSession token
        return session?

    _addSession:(token, session) ->
        @senderSessions.put token, session
        size = @senderSessions.size()
        Log.d "Add session #{token}, size = #{size}"

    _removeSession: (token, session) ->
        @senderSessions.remove token
        size = @senderSessions.size()
        Log.d "Remove session #{token}, size = #{size}"

    _getSession: (token) ->
        _session = null
        keys = @senderSessions.keys()
        for key in keys
            session = @senderSessions.get key
            if session?.getToken() is token
                _session = session
                break
        return _session

    _generateSessionToken: ->
        return UUID.randomUUID().toString()

module.exports.SessionManager = SessionManager