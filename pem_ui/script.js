// script.js

var master = 'localhost';
var port   = '9292'
var conn_string = 'http://' + master + ":" + port;

// create the module and name it scotchApp
var pemApp = angular.module("pemApp", ['ngRoute']);

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

//>>$.ajax({
//    dataType: "json",
//    url: pemAPI + "/envs",
//    success: function(response){
//      $.each(response, function( env, modules){
//
//        var newCard = $('<div class="card">');
//
//        newCard
//          .append($('<div class="card-header" role="tab" id="' + env + 'header">')
//          .append($('<h5 class="mb-0">')
//>>        .append('<a data-toggle="collapse" href="#' + env + '" aria-expanded="true" aria-controls="' + env + '"> ' + env + ' </a>'
//        )));
//
//>>      var table = $('<table class="table table-striped">').append('<thead><tr><th>Module</th><th>Version</th></tr></thead>');
//        var tableBody = $('<tbody>');
//        $.each(modules, function(module, version){
//>>         tableBody.append('<tr><td>' + module + '</td><td>' + version +'</td></tr>');
//        });
//        table.append(tableBody);
//
//        newCard.append($('<div id="' + env + '" class="collapse" role="tabpanel" aria-labelledby="' + env +'header" data-parent="#accordion">')
//        .append('<div class="card-body">').append(table));
//
//        $('#environments').append(newCard);
//      });
//    }
//  });
