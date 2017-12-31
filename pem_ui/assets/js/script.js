// script.js

var conn_string = 'http://' + master + ":" + port;
console.log(conn_string)

// create the module and name it scotchApp
var pemApp = angular.module("pemApp", ['ngRoute','ui.bootstrap']);

// configure our routes
pemApp.config(function($routeProvider) {
    $routeProvider

        // route for the home page
        .when('/environments', {
            templateUrl : 'assets/pages/environments.html',
            controller  : 'envController'
        })

        // route for the modules page
        .when('/modules', {
            templateUrl : 'assets/pages/modules.html',
            controller  : 'moduleController'
        })

        // route for the mod_detail page
        .when('/mod_detail/:name/:version', {
            templateUrl : 'assets/pages/mod_detail.html',
            controller  : 'mod_detailController'
        })

        .otherwise({redirectTo: '/environments'});

});

pemApp.controller('moduleController', function($scope, $http) {
    $http.get(conn_string + '/modules')
      .then(function(response){
        $scope.modules = response.data
    });
});

pemApp.controller('mod_detailController', function($scope, $http, $routeParams) {
    $http.get(conn_string + '/find_mod_envs/' + $routeParams.name + "/" + $routeParams.version)
      .then(function(response){
        $scope.envs = response.data;
        $scope.name = $routeParams.name;
        $scope.version = $routeParams.version;
    });
});

pemApp.controller('envController', function($scope, $http) {
    $http.get(conn_string + '/envs')
      .then(function(response){
        $scope.envs = response.data
    });
});

pemApp.directive('backButton', function(){
    return {
      restrict: 'A',

      link: function(scope, element, attrs) {
        element.bind('click', goBack);

        function goBack() {
          history.back();
          scope.$apply();
        }
      }
    }
});
