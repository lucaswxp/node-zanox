Zanox Api written in CoffeeScript
=================================

This is an Api to access [Zanox](http://www.zanox.com/) with nodejs.

Installation
------------

    npm install zanox

Usage
-----

```coffeescript
Zanox = require 'Zanox'
zanox = Zanox connectId, secretKey
zanox.getProgramsOfAdspace id, {items: 50}, (err, data) ->
    return console.error err if err?
    console.log '%j', data
```
