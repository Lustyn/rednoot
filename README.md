# rednoot
A global rednet/modem bridge for computercraft.

# Downloading the client

    > wget https://raw.githubusercontent.com/justync7/rednoot/master/client.lua rednoot

# Using the client
    
Typically this will work out of the box:
    
    > rednoot
    
But if it does not, you may supply these arguments (parentheses are defaults):
    
    > rednoot [endpoint (ws://rednoot.krist.club)] [mountPoint (front)]
    
# Public Instance
A public instance is hosted at `ws://rednoot.krist.club`.

# Running your own instance
You will need to already have [node.js](https://nodejs.org/en/) installed on your system.

    $ npm install
    $ npm start

# Specification
If you want to implement the protocol yourself or make something out of game that uses it, the specification can be found [here](SPECIFICATION.md)
