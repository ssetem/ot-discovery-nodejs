'use strict';

// Include gulp
var gulp = require('gulp');

var scripts = ['src/**/*.coffee', 'src/**/*.js'];
var tests = ['test/**/*.coffee', 'test/**/*.js'];
var coverage = 'coverage/';
var mochaOpts = {
  require: ['./test/globals.js']
};
var coverageThresholds = {
    statements: 99.9,
    branches: 98.5,
    functions: 99.9,
    lines: 99.9
  };

require('ot-gulp-release-tasks')(gulp, scripts, tests, mochaOpts, coverageThresholds);