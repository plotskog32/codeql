var express = require('express');

var app = express();

app.get('/user/:id', function(req, res) {
  if (!isValidUserId(req.params.id)) {
    // BAD: a request parameter is incorporated without validation into the response
    res.send("Unknown user: " + req.params.id);
    moreBadStuff(req.params, res);
  } else {
    // TODO: do something exciting
    ;
  }
});

function moreBadStuff(params, res) {
  res.send("Unknown user: " + params.id); // NOT OK
}

var marked = require("marked");
app.get('/user/:id', function(req, res) {
  res.send(req.body); // NOT OK
  res.send(marked(req.body)); // NOT OK
});


var table = require('markdown-table')
app.get('/user/:id', function(req, res) {
  res.send(req.body); // NOT OK
  var mytable = table([
    ['Name', 'Content'],
    ['body', req.body]
  ]);
  res.send(mytable); // NOT OK
});
