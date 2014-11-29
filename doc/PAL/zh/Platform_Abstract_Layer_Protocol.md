# Platform Abstract Layer Protocol
---

## Overview
Platform Abstract Layer简称为PAL，PAL protocol是Flint Server与platform之间的控制协议。Flint Server是控制命令的发起方，platform是控制命令的接收方。

## 消息格式
```
    {
        'type': 'command type',
        'app_id': 'application id',
        'app_info': {
        }
    }
```

## 协议细节

### type
type表示命令的类型，有以下两种：

* `LAUNCH_RECEIVER`：表示启动一个receiver application
* `STOP_RECEIVER`： 表示关闭一个receiver application

### app_id
app_id表示某一个具体的receiver application，由platform使用。

### app_info
app_info里有多个值域，表示receiver application的详细信息，platform根据这些信息来决定receiver application的启动方式。
> PAL协议中只规定url是必选项，platform可以扩展其他域实现一些特殊需求。

* `url`：表示receiver application的地址，有以下几种前缀，platform需要根据不同的前缀，以不同的方式启动receiver application：
    * `http://`：这是一个web url，指向一个web application
    * `https://`：这是一个web url，指向一个web application
    * `app:?`：这是一个native应用，需要platform解析'app:?'后面的值，当做一个package name或者local path来启动receiver application，这个实现由platform来决定。

