var express = require('express');
var path = require('path');
var favicon = require('serve-favicon');
var logger = require('morgan');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');
var sassMiddleware = require('node-sass-middleware');

var app = express();
var expressWs = require('express-ws')(app);

var index = require('./routes/index');
var echo = require('./routes/echo')(express);

function findIndexInArray(item, arr) {
    return arr.findIndex(function (a) {
        return a === item;
    });
}

Array.prototype.contains = function (obj) {
    return this.find(function (a) {
            return a === obj;
        }) !== undefined;
};

var clients = [];
var channels = [];

function Channel(id) {
    this.id = id;

    this.clients = [];

    this.openClient = function (client) {
        this.clients.push(client);
        console.log(client.id + " opened " + this.id);
        client.channels.push(this.id);
    };

    this.closeClient = function (client) {
        var close = this.clients.splice(findIndexInArray(client, this.clients), 1);
        if (close[0] !== undefined) {
            console.log(client.id + " closed " + this.id);
        }
        client.channels.splice(findIndexInArray(this.id, client.channels), 1);
    };

    this.contains = function (client) {
        return this.clients.contains(client);
    };

    this.transmit = function (from, reply, msg, msg_type) {
        var self = this;
        this.clients.forEach(function (v, i) {
            if (v.id !== from.id && v.readyState === v.OPEN) {
                v.send(JSON.stringify({
                    type: "receive",
                    channel: self.id,
                    reply_channel: reply,
                    id: from.id,
                    message: msg
                }));
            } else if (v.readyState !== v.OPEN) {
                self.clients.splice(i, 1);
            }
        });
    };
}

function getChannel(id) {
    return channels[id - 1];
}

function isValidCCRange(i) {
    return i > 0 && i < 65536;
}

function isCCType(s) {
    return (s == "number" || s == "string" || s == "table");
}

function addClient(v) {
    var index = findIndexInArray(undefined, clients);
    v.id = index + 1;
    v.client_index = index;
    v.channels = [];
    clients[index] = v;

    return index + 1;
}

for (var i = 0; i < 65535; i++) {
    channels.push(new Channel(i + 1));
    clients[i] = undefined;
}

clients[65535] = null;

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'hbs');

// uncomment after placing your favicon in /public
//app.use(favicon(path.join(__dirname, 'public', 'favicon.ico')));
app.use(logger('dev'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended: false}));
app.use(cookieParser());
app.use(sassMiddleware({
    src: path.join(__dirname, 'public'),
    dest: path.join(__dirname, 'public'),
    indentedSyntax: true, // true = .sass and false = .scss
    sourceMap: true
}));
app.use(express.static(path.join(__dirname, 'public')));

app.use('/', index);
app.use('/echo', echo);

app.ws('/', function (ws, req) {
    addClient(ws);
    setTimeout(function () {
        ws.send(JSON.stringify({
            type: "id",
            value: ws.id
        }));
    }, 100);

    console.log("ID " + ws.id + " connected");

    ws.on('message', function (message) {

        //console.log(message);

        if (message.length > 65535) {
            return ws.send(JSON.stringify({
                type: "error",
                message: "message_too_long"
            }), function () {
                setTimeout(function(){
                    ws.close();
                }, 100);
            });
        }

        var msg;

        try {
            msg = JSON.parse(message);
        } catch (e) {
            return ws.send(JSON.stringify({
                type: "error",
                message: "syntax_error"
            }), function () {
                ws.close();
            });
        }

        if (!msg.type) {
            return ws.send(JSON.stringify({
                type: "error",
                message: "invalid_type"
            }));
        }

        if (msg.type == "open") {

            if (!msg.channel || typeof(msg.channel) !== "number") {

                return ws.send(JSON.stringify({
                    type: "error",
                    message: "invalid_arguments"
                }));

            } else if (!isValidCCRange(msg.channel)) {

                return ws.send(JSON.stringify({
                    type: "error",
                    message: "invalid_id"
                }));

            } else if (getChannel(msg.channel).contains(ws)) {

                return ws.send(JSON.stringify({
                    type: "error",
                    message: "already_opened"
                }));

            } else {

                return getChannel(msg.channel).openClient(ws);

            }

        } else if (msg.type == "close") {

            if (!msg.channel || typeof(msg.channel) !== "number") {

                return ws.send(JSON.stringify({
                    type: "error",
                    message: "invalid_arguments"
                }));

            } else if (!isValidCCRange(msg.channel)) {

                return ws.send(JSON.stringify({
                    type: "error",
                    message: "invalid_id"
                }));

            } else if (!getChannel(msg.channel).contains(ws)) {

                return ws.send(JSON.stringify({
                    type: "error",
                    message: "already_closed"
                }));

            } else {

                return getChannel(msg.channel).closeClient(ws);

            }

        } else if (msg.type == "close_all") {

            return ws.channels.forEach(function (i) {
                getChannel(i).closeClient(ws);
            });

        } else if (msg.type == "transmit") {

            if (!msg.channel || !msg.reply_channel || !msg.message || typeof(msg.channel) !== "number" || typeof(msg.reply_channel) !== "number") {

                return ws.send(JSON.stringify({
                    type: "error",
                    message: "invalid_arguments"
                }));

            } else if (!isValidCCRange(msg.channel) || !isValidCCRange(msg.reply_channel)) {

                return ws.send(JSON.stringify({
                    type: "error",
                    message: "invalid_id"
                }));

            } else {

                return getChannel(msg.channel).transmit(ws, msg.reply_channel, msg.message);

            }

        }

    });

    ws.on('close', function () {
        console.log("ID " + ws.id + " disconnected");
        ws.channels.forEach(function (i) {
            getChannel(i).closeClient(ws);
        });
        clients[ws.client_index] = undefined;
    });
});

// catch 404 and forward to error handler
app.use(function (req, res, next) {
    var err = new Error('Not Found');
    err.status = 404;
    next(err);
});

// error handler
app.use(function (err, req, res, next) {
    // set locals, only providing error in development
    res.locals.message = err.message;
    res.locals.error = req.app.get('env') === 'development' ? err : {};

    // render the error page
    res.status(err.status || 500);
    res.render('error');
});

module.exports = app;
