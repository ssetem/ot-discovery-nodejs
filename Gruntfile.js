module.exports = function(grunt) {
    'use strict';

    grunt.initConfig({
        jshint: {
            all: [ '*.js' ]
        },
        mochaTest:{
            options: {
                reporter: 'spec'
            },
            tests:{
                src: ['tests/*.js']
            }
        },
    });

    grunt.loadNpmTasks('grunt-contrib-jshint');
    grunt.loadNpmTasks('grunt-mocha-test');
    grunt.registerTask('default', ['jshint', 'start-server', 'mochaTest']);
    grunt.loadTasks('./tests/tasks/');
};
