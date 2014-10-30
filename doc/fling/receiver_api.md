# Receiver api

### open communication
issue a websocket connection when the application launched

    ws.open("localhost:9431/receiver")

### reciever register
receiver should register itself immediately once websocket connected.

    receiver -> FlingService
    {
        "type":"register",
        "appid":"~browser"
    }

    {
        "type":"service_info",
        "appid":"~browser",
        "detail": {
            "ip": "10.0.0.1"
        }
    }

### reciever unregister
receiver should unregister itself immediately once application finished.

    receiver -> FlingService
    {
        "type":"unregister",
        "appid":"~browser"
    }

### start heartbeat
FlingService would tell receiver to start heartbeat after it registed.

    FlingService -> receiver
    {
        "type":"startheartbeat",
        "appid":"~browser",
        "interval":3*1000 #ping/pong interval in millisecond
    }

### heartbeat
receiver should sent ping timed(according interval above) and response FlingService's ping/pong.

    FlingService <-> receiver
    {
        "type":"heartbeat",
        "appid":"~browser",
        "heartbeat":"ping/pong"
    }

### receiver upload additional data
receiver upload application specific data to FlingService. And FlingService will store and forward the data to all senders which request receiver state from FlingService. FlingService should replace all stored additional data if receiver re-upload data. The additional data must structured as key-value pairs.

    receiver -> FlingService
    {
        "type":"additionaldata",
        "appid":"~browser",
        "additionaldata":{
            "key1":"value1",
            "key2":"value2",
            "key3":"value3"
        }
    }

### sender connect
FlingService notify receiver that a certain sender is connected.

    FlingService -> receiver
    {
        "type":"senderconnected",
        "appid":"~browser",
        "token":"EE2287DB-D10D-FECD-667B-8342AD095C33" #sender's token
    }

### sender disconnect
FlingService notify receiver that a certain sender is disconnected.

    FlingService -> receiver
    {
        "type":"senderdisconnected",
        "appid":"~browser",
        "token":"EE2287DB-D10D-FECD-667B-8342AD095C33" #sender's token
    }