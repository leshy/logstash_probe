_ = require 'underscore'
async = require 'async'
fs = require 'fs'
helpers = require 'helpers'
backbone = require 'backbone4000'
colors = require 'colors'
os = require 'os'


settings =
    pluginDir : "/node_modules/"
    plugin: {}
    host: 'localhost'
    port: "6000"
    extendPacket:
        type: 'probe',
        host: os.hostname()
        
if fs.existsSync('./settings.coffee') then _.extend settings, require('./settings').settings

UdpGun = require 'udp-client'
gun = new UdpGun settings.port, settings.host

env = { settings: settings }

plugin = backbone.Model.extend4000
    interval: 10000
    
    start: ->
        wrap = => @run (err,data) => @feed(err,data)
        @i = setInterval wrap, @interval
        wrap()
        
    feed: (err,data) ->

        
        packet = _.extend data, { probe: @name }, settings.extendPacket
        console.log  colors.green(@name), packet
        console.log gun.send new Buffer JSON.stringify packet
        
    stop: ->
        if @i
            stopInterval(@i)
            delete @i

loadPlugins = (env,callback) -> 
    fs.readdir helpers.makePath(__dirname + settings.pluginDir), (err, files) ->
        if err then return helpers.cbc err
        async.parallel (helpers.dictFromArray files, (fileName) ->
            [ fileName,
            (callback) ->
                if fileName.indexOf('probe_plugin_') isnt 0 then return callback()
                filePath = helpers.makePath(__dirname + settings.pluginDir + fileName)
                stats = fs.lstatSync filePath

                makePlugin = (callback) ->
                    name = fileName.substr(13)
                    newPlugin = plugin.extend4000 { name: name, env: env }, require(filePath).plugin
                    newPlugin::settings = _.extend  newPlugin::settings or {}, settings.plugin[name]
                    callback(null,newPlugin)
                    
                if stats.isDirectory() or stats.isSymbolicLink() then makePlugin(callback)
                else callback()]),                
                (err,data) ->
                    env.plugins = helpers.dictMap data, (val,key) -> val
                    helpers.cbc callback, err, data

startPlugins = (env,callback) ->
    helpers.dictMap env.plugins, (plugin,name) ->
        instance = new plugin()
        instance.start()        
    helpers.cbc callback

initialize = (env, callback) ->
    async.series [
        (callback) -> loadPlugins(env,callback)
        (callback) -> startPlugins(env,callback)
        ], (err,data) ->
        
        helpers.cbc callback, err, data

initialize env

