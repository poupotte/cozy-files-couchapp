db = require('db').current()
replication = require 'replication'
Base64 = require 'base64'
database = "cozy-files"

exports.addRemote =  () => 
    initDb (err, res) =>
        name = $("#name")[0].value
        password = $("#password")[0].value
        url = $("#url")[0].value
        folder = $("#folder")[0].value
        url = url.split('/')
        for partialUrl in url
            if partialUrl.indexOf('cozycloud.cc') isnt -1
                cozyUrl = 'https://' + partialUrl 
        checkData name, password, url, folder, (err) =>
            if err
                alert err 
            else  
                sendRequestRemote name, password, cozyUrl, folder, 0, 
                    (err, devicePwd, deviceId) =>
                    if err
                        alert err
                    else
                        callReplications cozyUrl, name, devicePwd, deviceId, 
                            (err, id)=>
                            alert err if err
                            updateDevice cozyUrl, name, password, id, folder, 
                                () =>
                                alert 'Your remote is well configured' if not err


## function initDb (callback)
## @callback{function} Continuation to pass control back to when complete.
## Initialize view in database
initDb = (callback) =>   
    # Init file view
    docFile = 
        _id: "_design/file"
        views:
            "all": 
                "map": "function (doc) {\n" +
                "    if (doc.docType === \"File\") {\n" +
                "        emit(doc.id, doc) \n" +
                "    }\n" + 
                "}"
            "byFolder":
                "map": "function (doc) {\n" +
                "    if (doc.docType === \"File\") {\n" +
                "        emit(doc.path, doc) \n" +
                "    }\n" + 
                "}"
    db.saveDoc docFile, (err, res) =>
        # Init folder view
        docFolder = 
            _id: "_design/folder"
            views:
                "all": 
                    "map": "function (doc) {\n" +
                    "    if (doc.docType === \"Folder\") {\n" +
                    "        emit(doc.id, doc) \n" +
                    "    }\n" + 
                    "}"
                "byFolder":
                    "map": "function (doc) {\n" +
                    "    if (doc.docType === \"Folder\") {\n" +
                    "        emit(doc.path, doc) \n" +
                    "    }\n" + 
                    "}"
        db.saveDoc docFolder, callback


## function checkData (name, password, url folder, cb)
## @name {string} Device name
## @password {string} Cozy password
## @url {string} Cozy url
## @folder {string} Folder path
## @cb {function} Continuation to pass control back to when complete.
## Check if user filled all data
checkData = (name, password, url, folder, cb) =>
    if name is "" or password is "" or url is "" or folder is "" 
        cb "All fields should be filled"
    else


## function sendRequestRemote (name, password, url folder, test, cb)
## @name {string} Device name
## @password {string} Cozy password
## @url {string} Cozy url
## @folder {string} Folder path
## @test {integer} Retry number (retry once in case of error)
## @cb {function} Continuation to pass control back to when complete.
## Add device in cozy
## Return device id and password
sendRequestRemote = (name, password, url, folder, test, cb) =>
    urlReq = "/#{database}/_replication/?name=#{name}&password=#{password}&" + 
        "url=#{url}" 
    if test is 2
        cb "Error: check your cozy url"
    else
        req =
            url: urlReq
        db.request req, (err, body) =>
            if err? and err.status is 401
                cb "Your cozy password is incorrect"
            else if err? and err.status is 400
                cb "This device name is already used"
            else if err?
                sendRequestRemote name, password, url, folder, test + 1, cb
            else
                data = JSON.parse body
                cb null, data.password, data.id


## function updateDevice (url, name, password, id, folder, cb)
## @url {string} Cozy url
## @name {string} Device name
## @password {string} Cozy password
## @id {Number} Device id
## @folder {string} Folder path
## @cb {function} Continuation to pass control back to when complete.
## Update device his cozy url and folder
## Return document
updateDevice = (url, name, password, id, folder, callback) =>
    db.getDoc id, (err, doc) =>
        doc.url = url
        doc.folder = folder
        doc.change = 0
        db.saveDoc doc, callback


## function secondReplication (data, id, callback)
## @data {Object} Replication options
## @id {Number} Device id used to create replication filter
## @callback {function} Continuation to pass control back to when complete.
## Call replication from local to cozy
## Return err and replication id
secondReplication = (data, id, callback) =>
    db.getDoc id, (err, res) =>
        if not res
            setTimeout ()->
                secondReplication data, id, callback
            , 500
        else
            filter = "function(doc, req) {" +
                "    if(doc._deleted) {\n" +
                "        return true; \n" +
                "    }\n" +
                "    if ("
            db.getDoc id, (err, doc) =>
                for docType, path of doc.configuration
                    filter = filter + "(doc.docType && doc.docType === " +
                        "\"#{docType}\") ||"
                filter = filter.substring(0, filter.length-3)
                filter = filter + "){\n" +
                    "        return true; \n"+
                    "    } else { \n" +
                    "        return false; \n" +
                    "    }\n" +
                    "}"
                doc =
                    _id: "_design/#{id}"
                    views: {}
                    filters: 
                        filter: filter
                db.saveDoc doc, (err, res) ->
                    replication.start data, (err, res) =>
                        callback err, id


## function callReplication (url, name, password, id, callback)
## @url {string} Cozy url
## @name {string} Device name
## @password {string} Cozy password
## @id {Number} Device id used to create replication filter
## @callback {function} Continuation to pass control back to when complete.
## Call replication from cozy to local
callReplications = (url, name, password, id, callback) =>
    credentials = name + ":" + password
    basicCredentials = Base64.encode(credentials);
    auth = "Basic " + basicCredentials
    data = 
        "source": 
            "url" : url + '/cozy'
            "headers": 
                "Authorization": auth
        "target": 
            "url" : "http://localhost:5984/#{database}"
        "continuous": true
        "filter": "#{id}/filter"
    replication.start data, (err, res) =>
        callback err if err?
        data = 
            "target": 
                "url" : url + '/cozy'
                "headers": 
                    "Authorization": auth
            "source":  
                "url" : "http://localhost:5984/#{database}"
            "continuous": true
            "filter": "#{id}/filter"
        secondReplication data, id, callback