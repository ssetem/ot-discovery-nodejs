module.exports = function(grunt) {
    'use strict';

    grunt.initConfig({
        jshint: {
            all: [ '*.js' ]
        },
        coffeelint: {
            options:{
                'max_line_length':{level:"ignore"}
            },
            all: ['src/*.coffee']
        },
        mochaTest:{
            options: {
                reporter: 'spec',
                require: [
                    'coffee-script/register',
                    './test/globals.js'
                ]
            },
            tests:{
                src: ['test/unit/*.coffee', 'test/unit/original/*.js']
            }
        },
    });

    grunt.loadNpmTasks('grunt-contrib-jshint');
    grunt.loadNpmTasks('grunt-mocha-test');
    grunt.loadNpmTasks('grunt-coffeelint');
    grunt.registerTask('default', ['jshint','coffeelint','start-server', 'mochaTest']);
    grunt.loadTasks('./test/tasks/');
};
