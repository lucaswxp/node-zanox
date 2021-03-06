var FetchLoop, Requester, _, async, createRequestOptions, crypto, extract, getAuthorization, hat, hatLength, http, latest, nextExtract, nonce, querystring, secureJsonParse, timestamp, versions;

crypto = require('crypto');

http = require('http');

querystring = require('querystring');

hat = require('hat');

_ = require('underscore');

async = require('async');

versions = ['2009-07-01', '2011-03-01'];

latest = _.last(versions);

hatLength = function(length) {
  return hat(4 * length);
};

nonce = function() {
  return hatLength(20);
};

timestamp = function() {
  return new Date().toUTCString();
};

getAuthorization = function(secret) {
  return function(verb, uri, timestamp, nonce) {
    var hmac, signature;
    signature = verb + uri + timestamp + nonce;
    hmac = crypto.createHmac('sha1', secret);
    hmac.update(signature);
    return hmac.digest('base64');
  };
};

createRequestOptions = function(connectId, secret, version) {
  var getAuth;
  if (version == null) {
    version = latest;
  }
  getAuth = getAuthorization(secret);
  return function(verb, uri, timestamp, nonce, options) {
    var header, query, signature;
    signature = getAuth(verb, uri, timestamp, nonce);
    header = "ZXWS " + connectId + ":" + signature;
    query = querystring.stringify(options);
    return options = {
      host: 'api.zanox.com',
      path: "/json/" + version + uri + "?" + query,
      method: verb,
      headers: {
        'Date': timestamp,
        'Nonce': nonce,
        'Authorization': header
      }
    };
  };
};

secureJsonParse = function(text, next) {
  var e;
  try {
    return next(null, JSON.parse(text));
  } catch (_error) {
    e = _error;
    return next(e);
  }
};

Requester = (function(_this) {
  return function(http) {
    return function(options, next) {
      var raw, req;
      if (!_.isFunction(next)) {
        throw new Error('missing next in requester');
      }
      raw = '';
      req = http.request(options, function(res) {
        res.setEncoding('utf8');
        if (res.statusCode >= 400) {
          return next("received status code " + res.statusCode + " from " + options.host);
        }
        res.on('data', function(chunk) {
          return raw += chunk;
        });
        return res.once('end', function() {
          return secureJsonParse(raw, next);
        });
      });
      req.once('error', function(e) {
        return next(e);
      });
      return req.end();
    };
  };
})(this);

FetchLoop = (function(_this) {
  return function(fetchMethod, next) {
    var fetchLoop, items, results;
    items = 50;
    results = [];
    fetchLoop = function(page) {
      return fetchMethod(page, items, function(err, result) {
        var enough;
        if (page == null) {
          throw new Error('missing page in fetchMethod');
        }
        if (err != null) {
          return next(err);
        }
        results.push(result);
        enough = items * (page + 1) >= result.total;
        if (enough) {
          return next(null, results);
        } else {
          return fetchLoop(page + 1);
        }
      });
    };
    return fetchLoop(0);
  };
})(this);

extract = function(type, json) {
  var hasAdmedia, hasContent, item, items, noAdmedia;
  json = _.flatten(json);
  hasContent = function(e) {
    return e[type + "Items"] != null;
  };
  noAdmedia = _.reject(json, hasContent);
  hasAdmedia = _.filter(json, hasContent);
  items = _.pluck(hasAdmedia, type + "Items");
  item = _.pluck(items, type + "Item");
  return _.flatten(item);
};

nextExtract = function(type, next) {
  return function(err, json) {
    if (err != null) {
      return next(err);
    }
    return next(null, extract(type, json));
  };
};

module.exports = function(connectId, secretKey, client) {
  var api, createRequests, requester;
  if (client == null) {
    client = http;
  }
  createRequests = createRequestOptions(connectId, secretKey);
  requester = Requester(client);
  return api = {
    sendRequest: (function(_this) {
      return function(verb, uri, params, next) {
        var options;
        if (!_.isFunction(next)) {
          throw new Error('missing next in sendRequest');
        }
        options = createRequests(verb, uri, timestamp(), nonce(), params);
        return requester(options, next);
      };
    })(this),
    getAdspaces: function(next) {
      return api.sendRequest('GET', '/adspaces', {}, next);
    },
    getPrograms: function(params, next) {
      return api.sendRequest('GET', '/programs', params, next);
    },
    getAdmedia: function(params, next) {
      return api.sendRequest('GET', '/admedia', params, next);
    },
    getProgram: function(id, next) {
      return api.sendRequest('GET', "/programs/program/" + id, {}, next);
    },
    getSalesOfDate: function(date, params, next) {
      return api.sendRequest('GET', "/reports/sales/date/" + date, params, next);
    },
    getProgramApplications: function(params, next) {
      return api.sendRequest('GET', "/programapplications", params, next);
    },
    getTrackingCategories: function(programId, adspaceId, params, next) {
      return api.sendRequest('GET', "/programapplications/program/" + programId + "/adspace/" + adspaceId + "/trackingcategories", params, next);
    },
    getLeadsOfDate: function(date, params, next) {
      return api.sendRequest('GET', "/reports/leads/date/" + date, params, next);
    },
    getAllSalesOfDate: function(date, params, next) {
      var fetch, method;
      method = api.getSalesOfDate;
      fetch = function(page, items, next) {
        var fetchParams = _.extend({}, params, {
          items: items,
          page: page
        });
        return method(date, fetchParams, next);
      };
      return FetchLoop(fetch, next);
    },
    getAllAdmedia: function(params, next) {
      var fetch, method;
      method = api.getAdmedia;
      fetch = function(page, items, next) {
        return method(_.extend({}, params, {
          items: items,
          page: page
        }), next);
      };
      return FetchLoop(fetch, next);
    },
    getAllProgramApplications: function(params, next) {
      var fetch, method;
      method = api.getProgramApplications;
      fetch = function(page, items, next) {
        return method(_.extend({}, params, {
          items: items,
          page: page
        }), next);
      };
      return FetchLoop(fetch, nextExtract('programApplication', next));
    },
    getAdmediaOfPrograms: function(programs, params, next) {
      var fetchProgram;
      fetchProgram = function(program, next) {
        return api.getAllAdmedia(_.extend({}, params, {
          program: program
        }), next);
      };
      return async.map(programs, fetchProgram, nextExtract('admedium', next));
    },
    getTrackingLinksForAdspace: function(adspace, next) {
      var admediaParams, appParams, extractProgramIds, formatAdmedia;
      appParams = {
        adspace: adspace,
        status: 'confirmed'
      };
      admediaParams = {
        purpose: 'startpage',
        admediumtype: 'text',
        partnership: 'direct',
        items: 50
      };
      extractProgramIds = function(applications) {
        var programIds, programs;
        programs = _.pluck(applications, 'program');
        return programIds = _.pluck(programs, '@id');
      };
      formatAdmedia = function(admedia) {
        return {
          id: admedia.program['@id'],
          name: admedia.program['$'],
          link: _.first(admedia.trackingLinks.trackingLink).ppc
        };
      };
      return api.getAllProgramApplications(appParams, function(err, applications) {
        var programIds;
        if (err != null) {
          return next(err);
        }
        programIds = extractProgramIds(applications);
        return api.getAdmediaOfPrograms(programIds, admediaParams, function(err, admedias) {
          var result;
          if (err != null) {
            return console.log(err);
          }
          admedias = _.filter(admedias, function(e) {
            var ref;
            if ((e != null ? (ref = e.trackingLinks) != null ? ref.trackingLink : void 0 : void 0) != null) {
              return e;
            }
          });
          result = _.map(admedias, formatAdmedia);
          return next(null, result);
        });
      });
    }
  };
};

// ---
// generated by coffee-script 1.9.2
