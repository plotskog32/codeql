(function () {
    var Parser = require("node-expat").Parser
    var parser = new Parser();

    parser.write(source());

    parser.on("text", text => {
        sink(text); // NOT OK
    });

    var parseString = require('xml2js').parseString;
    parseString(source(), function (err, result) {
        sink(result); // NOT OK
    });

    var sax = require("sax");
    var parser = sax.parser(strict);
    
    parser.onattribute = function (attr) {
        sink(attr); // NOT OK
    };
    
    parser.write(source()).close();

})();