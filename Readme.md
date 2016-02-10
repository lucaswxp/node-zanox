Zanox Api
=================================

This is a fork of [this repo](https://github.com/mren/node-zanox) aimed to translate from coffe to pure javascript

This is an Api to access [Zanox](http://www.zanox.com/) with nodejs.

Installation
------------

    npm install zanox

Usage
-----

```javascript
var Zanox = require('Zanox');

var client = Zanox(connectId, secretKey);

client.getProgramsOfAdspace(id, {
  items: 50
}, function(err, data) {
  if (err != null) {
    return console.error(err);
  }
  return console.log('%j', data);
});
```
