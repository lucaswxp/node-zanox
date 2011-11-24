Zanox Api written in CoffeeScript
=================================

This is an Api to access [Zanox](http://www.zanox.com/) with nodejs.

Installation
------------

    npm install zanox

Usage
-----

    Zanox = require 'Zanox'
    zanox = new Zanox connectId, secretKey
    zanox.getProgramsOfAdspace id, {items: 50}, (err, data) =>
        if err? then console.log 'error', err else
            console.log '%j', data
