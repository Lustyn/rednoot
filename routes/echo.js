module.exports = function(express) {
    var router = express.Router();

    router.ws('/', function(ws, req) {
        console.log("connected");

        ws.on('message', function(msg) {
            console.log(msg);
            ws.send(msg, {}, function(){
                console.log("echoed");
                //ws.close();
            });
        });

        ws.on('close', function() {
            console.log("closed");
        });
    });

    return router;
}
