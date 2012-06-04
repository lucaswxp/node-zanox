#!/usr/bin/env coffee

Zanox = require '../lib/Zanox'
{connectId, secretKey, adspace} = config = require './config'

zanox = Zanox connectId, secretKey

params =
    purpose: 'startpage'
    adspace: adspace
    admediumtype: 'text'
    partnership: 'direct'

zanox.getAllAdmedia params, (err, data) ->
    return console.log 'error', err if err?
    console.log '%j', data
