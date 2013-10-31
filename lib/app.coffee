db = require('db').current()
replication = require 'replication'
Base64 = require 'base64'

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
        sendRequestRemote name, password, cozyUrl, folder, 0, (err, devicePwd, deviceId) =>
            if err
                alert err
            else
                callReplications cozyUrl, name, devicePwd, deviceId, (err, res)=>
                    alert err if err
                    alert 'Your remote is well configured'


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
                "        emit(doc.path + '/' + doc.name, doc) \n" +
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
                    "        emit(doc.path + '/' + doc.name, doc) \n" +
                    "    }\n" + 
                    "}"
        db.saveDoc docFolder, callback

sendRequestRemote = (name, password, url, folder, test, cb) =>
    urlReq = '/cozy/_test/?name=' + name + '&password=' + password + 
        "&url=" + url 
    if test is 2
        cb "Error: check your cozy url"
    else
        req =
            url: urlReq
        db.request req, (err, body) =>
            if err?.status is 400
                alert "Wrong password or a device has already this name" +
                    " exists"
            else if err?
                sendRequestRemote name, password, url, folder, test + 1, cb
            else
                data = JSON.parse body
                #storeRemote url, name, data.password, data.id, folder, (err, res) =>
                #    cb(err) if err
                cb null, data.password, data.id

storeRemote = (url, name, password, id, folder, callback) =>
    doc =
        id: id
        name: name
        password: password
        url: url
        folder: folder
        docType: 'Device'
    db.saveDoc doc, callback


secondReplication = (data, id, callback) =>
    db.getDoc id, (err, res) =>
        if not res
            setTimeout ()->
                secondReplication data, id, callback
            , 500
        else
            filter = "    if(doc._deleted) {\n" +
                "        return true; \n" +
                "    }\n" +
                "    if ("
            db.getDoc id, (err, doc) =>
                for docType, path of doc.configuration
                    filter = filter + "(doc.docType && doc.docType === \"#{docType}\") ||"
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
                    replication.start data, callback 

callReplications = (url, name, password, id, callback) =>
    credentials = name + ":" + password
    basicCredentials = Base64.encode(credentials);
    authSource = "Basic " + basicCredentials
    basicCredentials = Base64.encode("test:secret");
    authTarget = "Basic " + basicCredentials
    data = 
        "source": 
            "url" : url + '/cozy'
            "headers": 
                "Authorization": authSource
        "target": 
            "url" : "http://localhost:5984/cozy"
            "headers": 
                "Authorization": authTarget
        "continuous": true
        "filter": "#{id}/filter"
    replication.start data, (err, res) =>
        callback err if err?
        data = 
            "target": 
                "url" : url + '/cozy'
                "headers": 
                    "Authorization": authSource
            "source":  
                "url" : "http://localhost:5984/cozy"
                "headers": 
                    "Authorization": authTarget
            "continuous": true
            "filter": "#{id}/filter"
        secondReplication data, id, callback