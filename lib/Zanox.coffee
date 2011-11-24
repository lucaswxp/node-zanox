# Documentation can be found here
# http://wiki.zanox.com/en/Web_Services
# http://wiki.zanox.com/en/RESTful_API_authentication_with_zanoxConnect

crypto = require 'crypto'
http = require 'http'
querystring = require 'querystring'

hat = require 'hat'

hatLength = (length) -> hat(4*length)
nonce = -> hatLength 20
timestamp = -> new Date().toUTCString()

getAuthorization = (secret) => (verb, uri, timestamp, nonce) =>
    signature = verb + uri + timestamp + nonce
    hmac = crypto.createHmac 'sha1', secret
    hmac.update signature
    hmac.digest 'base64'

createRequestOptions = (connectId, secret) =>
    getAuth = getAuthorization secret
    (verb, uri, timestamp, nonce, options) =>
        signature = getAuth verb, uri, timestamp, nonce
        header = 'ZXWS' + ' ' + connectId + ':' + signature
        query = querystring.stringify(options)
        options =
            host: 'api.zanox.com'
            path: "/json#{uri}?#{query}"
            method: verb
            headers:
                'Date': timestamp
                'Nonce': nonce
                'Authorization': header

requester = (http) => (options, next) =>
    raw = ''
    req = http.request options, (res) ->
        res.setEncoding 'utf8'
        res.on 'data', (chunk) ->
            raw += chunk
        res.on 'end', ->
            next null, JSON.parse raw
    req.on 'error', (e) -> next e
    req.end()

module.exports = class
    constructor: (connectId, secretKey, client = http) ->
        @createRequests = createRequestOptions connectId, secretKey
        @requester = requester client

    sendRequest: (verb, uri, params, next) =>
        options = @createRequests verb, uri, timestamp(), nonce(), params
        @requester options, next
    getAdspaces: (next) => @sendRequest 'GET', '/adspaces', next
    getProgramsOfAdspace: (id, params, next) => @sendRequest 'GET', '/programs/adspace/' + id, params, next
