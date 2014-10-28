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

class MDNS
    @MDNS_ADDRESS = "224.0.0.251"  #default ip
    @MDNS_PORT = 5353    #default port
    @MDNS_TTL = 20
    @MDNS_LOOPBACK_MODE = true

    @OPCODE_QUERY = 0
    @OPCODE_INVERSE_QUERY = 1
    @OPCODE_STATUS = 2

    @RESPONSE_CODE_OK = 0
    @RESPONSE_CODE_FORMAT_ERROR = 1
    @RESPONSE_CODE_SERVER_ERROR = 2
    @RESPONSE_CODE_NAME_ERROR = 3
    @RESPONSE_CODE_NOT_IMPLEMENTED = 4
    @RESPONSE_CODE_REFUSED = 5

    @MAX_MSG_TYPICAL = 1460 # unused
    @MAX_MSG_ABSOLUTE = 8972

    @FLAGS_QR_MASK = 0x8000 # query response mask
    @FLAGS_QR_QUERY = 0x0000 # query
    @FLAGS_QR_RESPONSE = 0x8000 # response

    @FLAGS_AA = 0x0400 # Authorative answer
    @FLAGS_TC = 0x0200 # Truncated
    @FLAGS_RD = 0x0100 # Recursion desired
    @FLAGS_RA = 0x8000 # Recursion available

    @FLAGS_Z = 0x0040 # Zero
    @FLAGS_AD = 0x0020 # Authentic data
    @FLAGS_CD = 0x0010 # Checking disabled

    @CLASS_IN = 1
    @CLASS_CS = 2
    @CLASS_CH = 3
    @CLASS_HS = 4
    @CLASS_NONE = 254
    @CLASS_ANY = 255
    @CLASS_MASK = 0x7FFF
    @CLASS_UNIQUE = 0x8000

    @TYPE_A = 1 # host address
    @TYPE_NS = 2
    @TYPE_MD = 3
    @TYPE_MF = 4
    @TYPE_CNAME = 5
    @TYPE_SOA = 6
    @TYPE_MB = 7
    @TYPE_MG = 8
    @TYPE_MR = 9
    @TYPE_NULL = 10
    @TYPE_WKS = 11
    @TYPE_PTR = 12
    @TYPE_HINFO = 13
    @TYPE_MINFO = 14
    @TYPE_MX = 15
    @TYPE_TXT = 16
    @TYPE_AAAA = 28
    @TYPE_SRV = 0x0021 # service location
    @TYPE_NSEC = 0x002F # next secured
    @TYPE_ANY = 255

    @protocolHelperTcp: (string) ->
        return "_"+string+"._tcp.local"

    @protocolHelperUdp: (string) ->
        return "_"+string+"._udp.local"

    @stringToUtf8ByteArray: (string) ->
        byteArray = []
        for i in [0..string.length-1]
            code = string.charCodeAt(i)
            if code < 0x80          
                byteArray.push code
            else if code < 0x800
                byteArray.push 0xC0|((code >> 6) & 0x1F)
                byteArray.push 0x80|(code & 0x3F)
            else if code < 0x00010000
                byteArray.push 0xE0|((code >> 12) & 0x0F)
                byteArray.push 0x80|((code >> 6) & 0x3F)
                byteArray.push 0x80|(code & 0x3F)
            else
                byteArray.push 0xF0|(code >> 18)
                byteArray.push 0x80|((code >> 12) & 0x3F)
                byteArray.push 0x80|((code >> 6) & 0x3F)
                byteArray.push 0x80|(code & 0x3F)
        return byteArray

    @utf8ByteArrayToString: (byteArray) ->
        bstr = ""
        nOffset = 0
        nRemainingBytes = byteArray.length
        nTotalChars = byteArray.length
        iCode = 0
        iCode1 = 0
        iCode2 = 0
        iCode3 = 0
        while nTotalChars > nOffset
            iCode = byteArray[nOffset]
            if (iCode & 0x80) == 0 # 1 byte
                if nRemainingBytes < 1 # not enough data  
                    break 
                bstr += String.fromCharCode iCode & 0x7F
                nOffset++
                nRemainingBytes -= 1
            else if (iCode & 0xE0) == 0xC0 # 2 bytes  
                iCode1 = byteArray[nOffset + 1]
                if nRemainingBytes < 2 || (iCode1 & 0xC0) != 0x80
                    break
                bstr += String.fromCharCode ((iCode & 0x3F) << 6) | (iCode1 & 0x3F)
                nOffset += 2
                nRemainingBytes -= 2
            else if (iCode & 0xF0) == 0xE0 # 3 bytes  
                iCode1 = byteArray[nOffset + 1]
                iCode2 = byteArray[nOffset + 2]
                if nRemainingBytes < 3 || (iCode1 & 0xC0) != 0x80 || (iCode2 & 0xC0) != 0x80
                    break
                bstr += String.fromCharCode (iCode & 0x0F) << 12 | ((iCode1 & 0x3F) << 6) | (iCode2 & 0x3F) 
                nOffset += 3
                nRemainingBytes -= 3
            else # 4 bytes
                iCode1 = byteArray[nOffset + 1]
                iCode2 = byteArray[nOffset + 2]
                iCode3 = byteArray[nOffset + 3]
                if nRemainingBytes < 4 || (iCode1 & 0xC0) != 0x80 || (iCode2 & 0xC0) != 0x80 || (iCode3 & 0xC0) != 0x80
                    break
                bstr += String.fromCharCode (iCode & 0x0F) << 18 | ((iCode1 & 0x0F) << 12) | ((iCode3 & 0x3F) << 6) | (iCode3 & 0x3F)
                nOffset += 4
                nRemainingBytes -= 4
        return bstr

    @pad: (num, n, base=10) ->
        numStr = num.toString(base)
        len = numStr.length
        while(len < n) 
            numStr = "0" + numStr
            len++
        return numStr

    @ipReverse: (ipStr) ->
        ipArray = ipStr.split "."
        ipArray.reverse()
        return ipArray.join "."

    @encodeMessage: (message) ->
        data = []
        textMapping = {}

        writeByte = (b, pos = null) ->
            if pos != null
                data[pos] = b
            else
                data.push b
            return 1

        writeWord = (w, pos = null) ->
            if pos != null
                return writeByte(w >> 8, pos) + writeByte(w & 0xFF, pos + 1)
            else
                return writeByte(w >> 8) + writeByte(w & 0xFF)

        writeDWord = (d) ->
            return  writeWord(d >> 16) + writeWord(d & 0xFFFF)

        writeByteArray = (b) ->
            bytesWritten = 0
            if b.length > 0
                for i in [0 .. b.length - 1]
                    bytesWritten += writeByte b[i]
            return bytesWritten

        writeIPAddress = (a) ->
            parts = a.split(".")
            bytesWritten = 0
            if parts.length > 0
                for i in [0 .. parts.length - 1]
                    bytesWritten += writeByte parseInt parts[i]
            return bytesWritten

        writeIP6Address = (a) ->
            parts = a.split(":")
            zeroCount = 8 - parts.length
            for i in [0 .. parts.length - 1]
                if parts[i]
                    writeWord parseInt parts[i], 16
                else
                    while zeroCount >= 0
                        writeWord 0
                        zeroCount -= 1
            return 16

        writeStringArray = (parts, includeLastTerminator) ->
            brokeEarly = false
            bytesWritten = 0
            if parts.length > 0
                for i in [0 .. parts.length - 1]
                    remainingString = parts.slice(i).join("._-_.")
                    location = textMapping[remainingString]
                    if location
                        brokeEarly = true
                        bytesWritten += writeByte 0xC0
                        bytesWritten += writeByte location
                        break
                    if data.length < 256 # we can't ever shortcut to a position after the first 256 bytes
                        textMapping[remainingString] = data.length
                    part = parts[i]
                    # utf-8 byte array
                    part = MDNS.stringToUtf8ByteArray part
                    bytesWritten += writeByte part.length
                    if part.length > 0
                        for j in [0 .. part.length - 1]
                            bytesWritten += writeByte part[j]
            if not brokeEarly and includeLastTerminator
                bytesWritten += writeByte 0
            return bytesWritten

        writeDNSName = (n) ->
            parts = n.split(".")
            return writeStringArray(parts, true)

        writeQuestion = (q) ->
            writeDNSName q.name
            writeWord q.type
            if q.unicast
                q.class |= MDNS.CLASS_UNIQUE 
            writeWord q.class

        writeRecord = (r) ->
            writeDNSName r.name
            writeWord r.type
            writeWord r.class #| if r.flushCache then 0x8000 else 0
            writeDWord r.timeToLive

            switch r.type
                when MDNS.TYPE_NSEC
                    lengthPos = data.length
                    writeWord 0
                    length = writeDNSName r.nsec_domainName
                    length += writeByte 0 # offset (always 0)
                    r.nsec_types.sort()
                    bytesNeeded = Math.ceil r.nsec_types[r.nsec_types.length - 1] / 8
                    length += writeByte bytesNeeded
                    bitMapArray = new Uint8Array bytesNeeded
                    #bitMapArray block 0, bit 1 corresponds to RR type 1 (A), bit 2 corresponds to RR type 2 (NS), and so forth.
                    # look rfc4034
                    if r.nsec_types.length > 0
                        for i in [0 .. r.nsec_types.length - 1]
                            type = r.nsec_types[i]
                            byteNum = Math.floor type / 8
                            bitNum = type % 8
                            bitMapArray[byteNum] |= 1 << (7 - bitNum)
                    length += writeByteArray bitMapArray
                    writeWord length, lengthPos

                when MDNS.TYPE_TXT
                    lengthPos = data.length
                    writeWord 0
                    length = writeStringArray r.txt_texts, false
                    writeWord length, lengthPos

                when MDNS.TYPE_A
                    lengthPos = data.length
                    writeWord 0
                    length = writeIPAddress r.a_address
                    writeWord length, lengthPos

                when MDNS.TYPE_AAAA
                    lengthPos = data.length
                    writeWord 0
                    length = writeIP6Address r.a_address
                    writeWord length, lengthPos

                when MDNS.TYPE_SRV
                    lengthPos = data.length
                    writeWord 0
                    length = writeWord r.srv_priority
                    length += writeWord r.srv_weight
                    length += writeWord r.srv_port
                    length += writeDNSName r.srv_target
                    writeWord length, lengthPos

                when MDNS.TYPE_PTR
                    lengthPos = data.length
                    writeWord 0
                    length = writeDNSName r.ptr_domainName
                    writeWord length, lengthPos

                else
                    writeWord r.resourceData.length
                    writeByteArray r.resourceData

        writeWord message.transactionID

        flags = 0
        if not message.isQuery then flags |= 0x8000
        flags |= (message.opCode & 0xFF) << 11
        if message.authoritativeAnswer then flags |= 0x400
        if message.truncated then flags |= 0x200
        if message.recursionDesired then flags |= 0x100
        if message.recursionAvailable then flags |= 0x80
        flags |= message.responseCode & 0xF
        writeWord flags

        writeWord message.questions.length
        writeWord message.answers.length
        writeWord message.autorityRecords.length
        writeWord message.additionalRecords.length

        if message.questions.length > 0
            for i in [0 .. message.questions.length-1]
                writeQuestion message.questions[i]

        if message.answers.length > 0
            for i in [0 .. message.answers.length-1]
                writeRecord message.answers[i]

        if message.autorityRecords.length > 0
            for i in [0 .. message.autorityRecords.length-1]
                writeRecord message.autorityRecords[i]

        if message.additionalRecords.length > 0
            for i in [0 .. message.additionalRecords.length-1]
                writeRecord message.additionalRecords[i]

        return data

    @decodeMessage: (rawData) ->
        position = 0
        errored = false

        consumeByte = ->
            if position + 1 > rawData.length
                if not errored
                    errored = true
            return rawData[position++]

        consumeWord = ->
            return (consumeByte() << 8) | consumeByte()

        consumeDWord = ->
            return (consumeWord() << 16) | consumeWord()

        consumeDNSName = ->
            parts = []
            while true
                if position >= rawData.length then break
                partLength = consumeByte()
                if partLength == 0 then break
                if partLength == 0xC0
                    bytePosition = consumeByte()
                    oldPosition = position
                    position = bytePosition
                    parts = parts.concat consumeDNSName().split(".")
                    position = oldPosition
                    break
                if position + partLength > rawData.length
                    if not errored
                        errored = true
                    partLength = rawData.length - position
                stringArray = []
                while partLength-- > 0
                    stringArray.push consumeByte()
                part = MDNS.utf8ByteArrayToString stringArray
                parts.push part
            return parts.join "."

        consumeQuestion = ->
            question = {}
            question.name = consumeDNSName()
            question.type = consumeWord()
            question.class = consumeWord()
            question.unicast = (question.class & 0x8000) != 0
            question.class &= 0x7FFF
            return question

        consumeByteArray = (length) ->
            length = Math.min length, rawData.length - position
            if length <= 0
                return ""
            data = new Array length
            for i in [0 .. length-1]
                data[i] = consumeByte()            
            return MDNS.utf8ByteArrayToString data

        consumeIPAddress = (length) ->
            ipArr = []
            for i in [0..length-1]
                ipArr.push consumeByte()
            return ipArr.join "."

        consumeIP6Address = () ->
            ipArr = []
            for i in [0..7]
                ipArr.push consumeWord()
            return ipArr.join ":"

        consumeResourceRecord = ->
            resource = {}
            resource.name = consumeDNSName()
            resource.type = consumeWord()
            resource.class = consumeWord()
            resource.flushCache = (resource.class & 0x8000) != 0
            resource.class &= 0x7FFF
            resource.timeToLive = consumeDWord()
            extraDataLength = consumeWord()

            switch resource.type
                when MDNS.TYPE_NSEC
                    resourceData = {}
                    resourceData.nsec_domainName = consumeDNSName()
                    consumeByte()
                    subLength = consumeByte()
                    bitString = ""
                    for i in [0..subLength-1]
                        bitString += MDNS.pad(consumeByte(),8,2)
                    nsec_types = []
                    for i in [0..bitString.length-1]
                        if bitString[i] == "1"
                            nsec_types.push i
                    resourceData.nsec_types = nsec_types
                    resource.resourceData = resourceData

                when MDNS.TYPE_TXT
                    resourceData = []
                    totalLength = 0
                    while extraDataLength > totalLength
                        subLength = consumeByte()
                        totalLength += subLength + 1
                        tempStr = consumeByteArray subLength
                        resourceData.push tempStr 
                    resource.resourceData = resourceData

                when MDNS.TYPE_A
                    resource.resourceData = consumeIPAddress extraDataLength

                when MDNS.TYPE_AAAA
                    resource.resourceData = consumeIP6Address()

                when MDNS.TYPE_SRV
                    resourceData = {}
                    resourceData.srv_priority = consumeWord()
                    resourceData.srv_weight = consumeWord()
                    resourceData.srv_port = consumeWord()
                    resourceData.srv_target = consumeDNSName()
                    resource.resourceData = resourceData

                when MDNS.TYPE_PTR
                    resource.resourceData = consumeDNSName()

                else
                    if extraDataLength > 0
                        resource.resourceData = consumeByteArray extraDataLength

            return resource

        result = {}
        
        result.transactionID = consumeWord()

        flags = consumeWord()
        result.isQuery = (flags & 0x8000) == 0
        result.opCode = (flags >> 11) & 0xF
        result.authoritativeAnswer = (flags & 0x400) != 0
        result.truncated = (flags & 0x200) != 0
        result.recursionDesired = (flags & 0x100) != 0
        result.recursionAvailable = (flags & 0x80) != 0
        result.responseCode = flags & 0xF

        questionCount = consumeWord()
        answerCount = consumeWord()
        authorityRecordsCount = consumeWord()
        additionalRecordsCount = consumeWord()

        result.questions = []
        result.answers = []
        result.autorityRecords = []
        result.additionalRecords = []

        if questionCount > 0
            for [1 .. questionCount]
                result.questions.push consumeQuestion()

        if answerCount > 0
            for [1 .. answerCount]
                result.answers.push consumeResourceRecord()

        if authorityRecordsCount > 0
            for [1 .. authorityRecordsCount]
                result.autorityRecords.push consumeResourceRecord()

        if additionalRecordsCount > 0
            for [1 .. additionalRecordsCount]
                result.additionalRecords.push consumeResourceRecord()

        return result

    @map2txt: (txtRecord) ->
        txt_texts = []
        for k,v of txtRecord
            txt_texts.push k + "=" + v

        return txt_texts

    @creatDnsSdRequest: (transactionID, fullProtocol) ->
        response =
            transactionID: transactionID, # max 65535
            isQuery: false,
            opCode: 0,
            authoritativeAnswer: true,
            truncated: false,
            recursionDesired: false,
            recursionAvailable: false,
            responseCode: MDNS.RESPONSE_CODE_OK,
            questions: [],
            answers: [],
            additionalRecords: [],
            autorityRecords: []

        response.questions.push
            name: fullProtocol,
            type: MDNS.TYPE_PTR,
            class: MDNS.CLASS_IN,
            unicast: false
        return response 

    @creatDnsSdKeepResponse: (transactionID, fullProtocol, serverName, port, txtRecord, address, localName) ->
        response =
            transactionID: transactionID, # max 65535
            isQuery: false,
            opCode: 0,
            authoritativeAnswer: true,
            truncated: false,
            recursionDesired: false,
            recursionAvailable: false,
            responseCode: MDNS.RESPONSE_CODE_OK,
            questions: [],
            answers: [],
            additionalRecords: [],
            autorityRecords: []

        response.answers.push
            name: fullProtocol,
            type: MDNS.TYPE_PTR,
            class: MDNS.CLASS_IN,
            flushCache: false,
            timeToLive: 10,
            ptr_domainName: serverName + "."+fullProtocol

        response.answers.push
            name: serverName + "." + fullProtocol,
            type: MDNS.TYPE_SRV,
            class: MDNS.CLASS_IN,
            flushCache: false,
            timeToLive: 10,
            srv_priority: 0,
            srv_weight: 0,
            srv_port: port,
            srv_target: localName + ".local"

        response.answers.push
            name: serverName + "." + fullProtocol,
            type: MDNS.TYPE_TXT,
            class: MDNS.CLASS_IN,
            flushCache: false,
            timeToLive: 10,
            txt_texts: MDNS.map2txt txtRecord

        response.answers.push
            name: localName + ".local",
            type: MDNS.TYPE_A,
            class: MDNS.CLASS_IN,
            flushCache: false,
            timeToLive: 10,
            a_address: address.ipv4

        response.answers.push
            name: "_services._dns-sd._udp.local",
            type: MDNS.TYPE_PTR,
            class: MDNS.CLASS_IN,
            flushCache: false,
            timeToLive: 4500,
            ptr_domainName: fullProtocol

        return response

    @creatDnsSdResponse: (transactionID, fullProtocol, serverName, port, txtRecord, address, localName) ->
        response =
            transactionID: transactionID, # max 65535
            isQuery: false,
            opCode: 0,
            authoritativeAnswer: true,
            truncated: false,
            recursionDesired: false,
            recursionAvailable: false,
            responseCode: MDNS.RESPONSE_CODE_OK,
            questions: [],
            answers: [],
            additionalRecords: [],
            autorityRecords: []

        """
        response.questions.push
            name: fullProtocol,
            type: MDNS.TYPE_PTR,
            class: MDNS.CLASS_IN,
            unicast: true
        """

        response.answers.push
            name: fullProtocol,
            type: MDNS.TYPE_PTR,
            class: MDNS.CLASS_IN,
            flushCache: false,
            timeToLive: 10,
            ptr_domainName: serverName + "."+fullProtocol

        response.additionalRecords.push
            name: serverName + "." + fullProtocol,
            type: MDNS.TYPE_SRV,
            class: MDNS.CLASS_IN,
            flushCache: false,
            timeToLive: 10,
            srv_priority: 0,
            srv_weight: 0,
            srv_port: port,
            srv_target: localName + ".local"
       
        if txtRecord
            response.additionalRecords.push
                name: serverName + "." + fullProtocol,
                type: MDNS.TYPE_TXT,
                class: MDNS.CLASS_IN,
                flushCache: false,
                timeToLive: 10,
                txt_texts: MDNS.map2txt txtRecord

        if address.ipv6
            response.additionalRecords.push
                name: localName + ".local",
                type: MDNS.TYPE_AAAA,
                class: MDNS.CLASS_IN,
                flushCache: false,
                timeToLive: 10,
                a_address: address.ipv6

        response.additionalRecords.push
            name: localName + ".local",
            type: MDNS.TYPE_A,
            class: MDNS.CLASS_IN,
            flushCache: false,
            timeToLive: 10,
            a_address: address.ipv4

        return response

    @parseDnsSdResponse : (response) ->
        serverInfo = {}

        for i of response.additionalRecords
            tempRecode = response.additionalRecords[i]
            if tempRecode.type == MDNS.TYPE_SRV
                protocolArray = tempRecode.name.split "."
                serverInfo.name = protocolArray[0]
                serverInfo.protocol = protocolArray[1]
                serverInfo.protocol_type = protocolArray[2]
                serverInfo.srv_priority = tempRecode.resourceData.srv_priority
                serverInfo.srv_weight = tempRecode.resourceData.srv_weight
                serverInfo.srv_port = tempRecode.resourceData.srv_port
                serverInfo.srv_target = tempRecode.resourceData.srv_target
            else if tempRecode.type == MDNS.TYPE_TXT
                tempMap = {}
                for j of tempRecode.resourceData
                    tempArr = tempRecode.resourceData[j].split "="
                    tempMap[tempArr[0]] = tempArr[1]
                serverInfo.txt_texts = tempMap
            else if tempRecode.type == MDNS.TYPE_AAAA
                serverInfo.ipv6 = tempRecode.resourceData
            else if tempRecode.type == MDNS.TYPE_A
                serverInfo.ipv4 = tempRecode.resourceData

        return serverInfo
    
module.exports.MDNSHelper = MDNS
