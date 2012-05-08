#!/usr/bin/env coffee
Zanox = require '../lib/Zanox'
{connectId, secretKey, adspace} = config = require './config'

zanox = Zanox connectId, secretKey
zanox.getAllProgramsOfAdspace adspace, (err, data) ->
    return console.log 'error', err if err?
    console.log '%j', data
