# build-in application
each platform implements the launching and stopping

### build-in application id
    ~browser:    to open a url
    ~native:     to launch a native application
    ~[uuid]:     custom build-in application

### FirefoxOS
pal message format

        # ~browser
        {
            "type":"LAUNCH_RECEIVER | STOP_RECEIVER",
            "app_id": "~browser"
            "app_info": {
                "url": "http://www.matchstick.tv"
            }
        }

        # ~native
        {
            "type":"LAUNCH_RECEIVER | STOP_RECEIVER",
            "app_id": "~native"
            "app_info": {
                "pakcage_name": "com.matchstick.ffos.settings"
            }
        }

        # ~[uuid]
        {
            "type":"LAUNCH_RECEIVER | STOP_RECEIVER",
            "app_id": "~[uuid]"
            "app_info": {
            }
        }