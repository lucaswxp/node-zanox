# Documentation can be found here
# http://wiki.zanox.com/en/Web_Services
# http://wiki.zanox.com/en/RESTful_API_authentication_with_zanoxConnect

crypto = require 'crypto'
http = require 'http'
querystring = require 'querystring'
assert = require 'assert'

hat = require 'hat'
_ = require 'underscore'

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
    assert.ok next?, 'missing next in requester'
    raw = ''
    req = http.request options, (res) ->
        res.setEncoding 'utf8'
        res.on 'data', (chunk) ->
            raw += chunk
        res.on 'end', ->
            next null, JSON.parse raw
    req.on 'error', (e) -> next e
    req.end()

FetchLoop = (fetchMethod, next) =>
    items = 50
    results = []
    fetchLoop = (page) =>
        fetchMethod page, items, (err, result) =>
            assert.ok page?, 'missing page in fetchMethod call'
            if err?
                next err
            else
                results.push result
                enough = items * (page+1) >= result.total
                if not enough then fetchLoop page+1 else next null, results
    fetchLoop 0

module.exports = class
    constructor: (connectId, secretKey, client = http) ->
        @createRequests = createRequestOptions connectId, secretKey
        @requester = requester client

    sendRequest: (verb, uri, params, next) =>
        assert.ok next?, 'sendRequest: missing next'
        options = @createRequests verb, uri, timestamp(), nonce(), params
        @requester options, next
    getAdspaces: (next) => @sendRequest 'GET', '/adspaces', {}, next
    getAdmedia: (params, next) => @sendRequest 'GET', '/admedia', params, next
    getProgramsOfAdspace: (id, params, next) =>
        assert.ok next?, 'getProgramsOfAdspace: missing next'
        @sendRequest 'GET', '/programs/adspace/' + id, params, next
    getSalesOfDate: (date, params, next) =>
        assert.ok date?, 'date is required'
        @sendRequest 'GET', '/reports/sales/date/' + date, params, next

    # generic fetch all
    # paramters, conf, callback
    getAllSalesOfDate: (date, params, next) =>
        method = @getSalesOfDate

        fetch = (page, items, next) =>
            fetchParams = _.extend {}, params, {items: items, page: page},
            method date, fetchParams,  next
        FetchLoop fetch, next

    getAllProgramsOfAdspace: (id, next) =>
        assert.ok id?, 'getAllProgramsOfAdsacpe: missing id'
        assert.ok next?, 'getAllProgramsOfAdspace: missing next'
        method = @getProgramsOfAdspace
        fetch = (page, items, next) =>
            method id, {items: items, page: page}, next
        FetchLoop fetch, next
