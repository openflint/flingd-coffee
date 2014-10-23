# Sender api

### get state

* request

        GET http://192.168.1.1:9973/apps/appid
        Accept: application/xml; charset=utf8
        Authorization: EE2287DB-D10D-FECD-667B-8342AD095C33 # if present

* response

        # if stopped
        <?xml version="1.0" encoding="utf-8"?>
        <service xmlns="urn:dial-multiscreen-org:schemas:dial" dialVer="1.7">  
          <name>AppName</name>  
          <options allowStop="true"/>  
          <state>stopped</state> 
        </service>

        # if starting
        <?xml version="1.0" encoding="utf-8"?>
        <service xmlns="urn:dial-multiscreen-org:schemas:dial" dialVer="1.7">  
          <name>AppName</name>  
          <options allowStop="true"/>  
          <state>running</state>
          <link rel="run" href="run"/>
        </service>

        # if running
        <?xml version="1.0" encoding="utf-8"?>
        <service xmlns="urn:dial-multiscreen-org:schemas:dial" dialVer="1.7">  
          <name>AppName</name>  
          <options allowStop="true"/>  
          <state>running</state>
          <link rel="run" href="run"/>
          <additionalData> # application specific data
            <key1>value1</key1>  
            <key2>value1</key2>  
            <key3>value1</key3> 
            ......
          </additionalData> 
        </service>

### launch application
* request

        POST http://192.168.1.1:9973/apps/appid
        Content-Type: application/json
        
        {
            "type":"launch/relaunch/join",
            "app_info":{
                "url":"www.youtube.com",
                "useIpc":true, # true means receive need connet to FlingService
                "maxInactive":1 # -1 means forever
        }

* response

        #if not running
        201 CREATE
        Content-Type: application/json
        {
            "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
            "interval":3 #ping/pong interval
        }

        # if starting or running
        200 OK
        Content-Type: application/json
        {
            "token":"EE2287DB-D10D-FECD-667B-8342AD095C33"
            "interval":3 #ping/pong interval
        }

        #if appid invalid
        404 NOT FOUND

### stop application
* request

        DELETE http://192.168.1.1:9973/apps/appid
        DELETE http://192.168.1.1:9973/apps/appid/run

* response

        200 OK
        404 NOT FOUND

### system control

* request

        POST http://192.168.1.1:9973/system/control
        Content-Type: application/json
        
        {
            "type":"GET_VOLUME | SET_VOLUME | GET_MUTED | SET_MUTED", # customed
            "level": 0.5
            "muted": false
        }

* response

        200 OK
        Content-Type: application/json
        
        {
            "success": true or false # request result
            "type":"GET_VOLUME | SET_VOLUME | GET_MUTED | SET_MUTED", #same as in request
            "level": 0.5
            "muted": false
        }