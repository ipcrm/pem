// script.js

var master = 'localhost';
var port   = '9292'
var conn_string = 'http://' + master + ":" + port;

// create the module and name it scotchApp
var pemApp = angular.module("pemApp", ['ngRoute','ui.bootstrap']);

// configure our routes
pemApp.config(function($routeProvider) {
    $routeProvider

        // route for the home page
        .when('/environments', {
            templateUrl : 'pages/environments.html',
            controller  : 'envController'
        })

        // route for the about page
        .when('/modules', {
            templateUrl : 'pages/modules.html',
            controller  : 'moduleController'
        })

});

// create the controller and inject Angular's $scope
pemApp.controller('moduleController', function($scope, $http) {
    $http.get(conn_string + '/modules')
      .then(function(response){
        $scope.modules = response.data
    });
});

pemApp.controller('envController', function($scope, $http) {
    $http.get(conn_string + '/envs')
      .then(function(response){
        $scope.envs = response.data
    });
});
