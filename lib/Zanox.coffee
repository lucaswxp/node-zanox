# Documentation can be found here
# http://wiki.zanox.com/en/Web_Services
# http://wiki.zanox.com/en/RESTful_API_authentication_with_zanoxConnect

crypto = require 'crypto'
http = require 'http'
querystring = require 'querystring'

hat = require 'hat'
_ = require 'underscore'

versions = ['2009-07-01', '2011-03-01']
latest = _.last versions

hatLength = (length) -> hat(4*length)
nonce = -> hatLength 20
timestamp = -> new Date().toUTCString()

getAuthorization = (secret) -> (verb, uri, timestamp, nonce) ->
    signature = verb + uri + timestamp + nonce
    hmac = crypto.createHmac 'sha1', secret
    hmac.update signature
    hmac.digest 'base64'

createRequestOptions = (connectId, secret, version = latest) ->
    getAuth = getAuthorization secret
    (verb, uri, timestamp, nonce, options) ->
        signature = getAuth verb, uri, timestamp, nonce
        header = "ZXWS #{connectId}:#{signature}"
        query = querystring.stringify(options)
        options =
            host: 'api.zanox.com'
            path: "/json/#{version}#{uri}?#{query}"
            method: verb
            headers:
                'Date': timestamp
                'Nonce': nonce
                'Authorization': header

secureJsonParse = (text, next) ->
    try
        next null, JSON.parse text
    catch e
        next e

requester = (http) => (options, next) =>
    throw new Error 'missing next in requester' unless _.isFunction next
    raw = ''
    req = http.request options, (res) ->
        res.setEncoding 'utf8'
        return next "received status code #{res.statusCode} from #{options.host}" if res.statusCode >= 400
        res.on 'data', (chunk) -> raw += chunk
        res.once 'end', -> secureJsonParse raw, next

    req.once 'error', (e) -> next e
    req.end()

FetchLoop = (fetchMethod, next) =>
    items = 50
    results = []
    fetchLoop = (page) =>
        fetchMethod page, items, (err, result) =>
            throw new Error 'missing page in fetchMethod' unless page?
            return next err if err?
            results.push result
            enough = items * (page+1) >= result.total
            if enough then next null, results else fetchLoop page+1
    fetchLoop 0

module.exports = (connectId, secretKey, client = http) ->
    createRequests = createRequestOptions connectId, secretKey
    requester = requester client

    return api =
    sendRequest: (verb, uri, params, next) =>
        throw new Error 'missing next in sendRequest' unless _.isFunction next
        options = createRequests verb, uri, timestamp(), nonce(), params
        requester options, next
    getAdspaces: (next) -> api.sendRequest 'GET', '/adspaces', {}, next
    getAdmedia: (params, next) -> api.sendRequest 'GET', '/admedia', params, next
    getProgramsOfAdspace: (id, params, next) ->
        api.sendRequest 'GET', "/programs/adspace/#{id}", params, next
    getProgram: (id, next) ->
        api.sendRequest 'GET', "/programs/program/#{id}", {}, next
    getSalesOfDate: (date, params, next) ->
        api.sendRequest 'GET', "/reports/sales/date/#{date}", params, next

    # generic fetch all
    # paramters, conf, callback
    getAllSalesOfDate: (date, params, next) ->
        method = api.getSalesOfDate

        fetch = (page, items, next) ->
            fetchParams = _.extend {}, params, {items: items, page: page},
            method date, fetchParams,  next
        FetchLoop fetch, next

    getAllProgramsOfAdspace: (id, next) ->
        throw new Error 'getAllProgramsOfAdspace: missing id' unless id?
        throw new Error 'getAllProgramsOfAdspace: missing next' unless _.isFunction next
        method = api.getProgramsOfAdspace
        fetch = (page, items, next) ->
            method id, {items: items, page: page}, next
        FetchLoop fetch, next

    getProgramApplications: (params, next) ->
        throw new Error 'getProgramApplications: missing next' unless _.isFunction next
        api.sendRequest 'GET', "/programapplications", params, next

    getAllProgramApplications: (params, next) ->
        method = api.getProgramApplications
        fetch = (page, items, next) ->
            method _.extend({}, params, {items: items, page: page}), next
        FetchLoop fetch, next
