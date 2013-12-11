# Copied from https://github.com/pithu/ibrik/blob/master/src/instrument.coffee

Module = require 'module'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
existsSync = fs.existsSync or path.existsSync

async = require 'async'

ibrik = require './ibrik'
istanbulFileMatcher = require 'istanbul/lib/util/file-matcher'


processFiles = (instrumenter, inputDir, outputDir, relativeNames, cb) ->
    processor = (name, callback) ->
        inputFile = path.resolve(inputDir, name)
        inputFileExtenstion = path.extname(inputFile)
        isCoffeeScriptFile = (inputFileExtenstion is '.coffee')
        if isCoffeeScriptFile
            outputFile = path.resolve(outputDir, name.replace('.coffee', '.js'))
        else
            outputFile = path.resolve(outputDir, name)
        oDir = path.dirname(outputFile)
        mkdirp.sync(oDir);

        if fs.statSync(inputFile).isDirectory()
            return callback(null, name)


        if isCoffeeScriptFile
            fs.readFile inputFile, 'utf8', (err, data) ->
                if err?
                    return callback(err, name)

                instrumenter.instrument data, inputFile, (iErr, instrumented) ->
                    if iErr?
                        return callback(iErr, name)

                    fs.writeFile outputFile, instrumented, 'utf8', (err) ->
                        return callback(err, name)
        else
            # non JavaScript file, copy it as is
            readStream = fs.createReadStream(inputFile, {'bufferSize': READ_FILE_CHUNK_SIZE})
            writeStream = fs.createWriteStream(outputFile);

            readStream.on('error', callback);
            writeStream.on('error', callback);

            readStream.pipe(writeStream);
            readStream.on 'end', ->
                callback(null, name)

    q = async.queue(processor, 10)
    errors = []
    count = 0
    startTime = new Date().getTime()

    q.push relativeNames, (err, name) ->
        count++
        if count % 100 is 0
            process.stdout.write('.')
        if err?
            console.dir err
            errors.push({ file: name, error: err.message || err.toString() })

    q.drain = ->
        endTime = new Date().getTime();
        console.log("\nProcessed [#{count}] files in #{Math.floor((endTime - startTime) / 1000)} secs")
        if errors.length
            console.log("The following #{errors.length} file(s) had errors")
            console.log(errors)
            return cb("Processed [#{count}] files with #{errors.length} errors")
        else
            cb(null)


module.exports = (opts, callback) ->

    [cmd, fileArg, args...] = opts._

    instrumenter = new ibrik.Instrumenter
        coverageVariable: opts.variable or '__coverage__'
        embedSource: opts['embed-source']
        noCompact: !opts.compact

    includes = ['**/*.coffee']

    file = path.resolve(fileArg)
    stats = fs.statSync(file)
    if stats.isDirectory()
        if not opts.output
            opts.output = file

        mkdirp.sync(opts.output)
        istanbulFileMatcher.filesFor {
            root: file
            includes: includes
            excludes: opts.x || ['**/node_modules/**']
            relative: true
        }, (err, files) ->
            if err?
                return callback(err)
            processFiles(instrumenter, file, opts.output, files, callback)

    else
        if opts.output
            stream = fs.createWriteStream(opts.output)
        else
            stream = process.stdout

        stream.write(instrumenter.instrumentSync(fs.readFileSync(file, 'utf8'), file))
        if stream is not process.stdout
            stream.end()

        return callback(null)