#!/usr/bin/env coffee
Zanox = require '../lib/Zanox'
{connectId, secretKey, adspace} = config = require './config'

zanox = Zanox connectId, secretKey
params = datetype: 'modifiedDate', state: 'approved'
zanox.getAllSalesOfDate '2012-02-01', params, (err, data) ->
    return console.log 'error', err if err?
    console.log '%j', data
