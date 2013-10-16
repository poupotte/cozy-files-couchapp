db = require('db').current()
replication = require('replication')
Base64 = require('base64')
dbFiles = null

exports.addRemote =  () =>
    initDb (err, res) =>
        name = $("#name")[0].value
        password = $("#password")[0].value
        url = $("#url")[0].value
        url = url.split('/')
        for partialUrl in url
            if partialUrl.indexOf('cozycloud.cc') isnt -1
                cozyUrl = 'https://' + partialUrl 
        sendRequestRemote name, password, cozyUrl, 0, (err, remotePassword) =>
            if err
                alert err
            else
                callReplications url, name, remotePassword, (err, res)=>
                    alert err if err
                    alert 'Your remote is well configured'


initDb = (callback) =>   
    doc =
        _id: "_design/filter"
        filters:
            filesfilter: "function (doc, req) {\n" +
                "    if(doc._deleted) {\n" +
                "        return true; \n" +
                "    }\n" +
                "    if ((doc.docType && doc.docType === \"File\") ||(doc.docType && doc.docType === \"Folder\"))  {\n" +
                "        return true; \n"+
                "    } else { \n" +
                "        return false; \n" +
                "    }\n" +
                "}"
    db.saveDoc doc, callback

sendRequestRemote = (name, password, url, test, callback) =>
    urlReq = '/cozy/_test/?name=' + name + '&password=' + password + "&url=" + url 
    if test is 2
        callback "Error: check your cozy url"
    else
        req =
            url: urlReq
            method: 'GET'
        db.request req, (err, body) =>
            if err?.status is 400
                alert "Wrong password or your a remote with this name already exists"
            else if err?
                sendRequestRemote name, password, url, test + 1, callback
            else
                data = JSON.parse body
                storeRemote url, name, data.password, (err, res) =>
                    callback(err) if err
                    callback null, data.password

storeRemote = (url, name, password, callback) =>
    doc =
        name: name
        password: password
        url: url
        docType: 'Remote'
    db.saveDoc doc, callback

callReplications = (url, name, password, callback) =>
    credentials = name + ":" + password
    basicCredentials = Base64.encode(credentials);
    authSource = "Basic " + basicCredentials
    data = 
        "source": 
            "url" : url + '/cozy'
            "headers": 
                "Authorization": authSource
        "target": "cozy"
        "continuous": true
        "filter": "filter/filesfilter"
    replication.start data, (err, res) =>
        callback err if err?
        data = 
            "target": 
                "url" : url + '/cozy'
                "headers": 
                    "Authorization": authSource
            "source": "cozy"
            "continuous": true
            "filter": "filter/filesfilter"
        replication.start data, callback