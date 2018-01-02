// script.js

var conn_string = 'http://' + master + ":" + port;
console.log(conn_string)

// create the module and name it scotchApp
var pemApp = angular.module("pemApp", ['ngRoute','ui.bootstrap']);

// configure our routes
pemApp.config(function($routeProvider) {
    $routeProvider

        .when('/environments', {
            templateUrl : 'assets/pages/environments.html',
            controller  : 'envController'
        })

        .when('/modules', {
            templateUrl : 'assets/pages/modules.html',
            controller  : 'moduleController'
        })

        .when('/mod_detail/:name/:version', {
            templateUrl : 'assets/pages/mod_detail.html',
            controller  : 'mod_detailController'
        })

        .when('/env_compare/:env1/:env2', {
            templateUrl : 'assets/pages/env_compare.html',
            controller  : 'env_compareController'
        })

        .when('/env_compare_prep/:env1', {
            templateUrl : 'assets/pages/env_compare_prep.html',
            controller  : 'env_compare_prepController'
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

pemApp.controller('env_compareController', function($scope, $http, $routeParams) {
    $http.get(conn_string + '/envs/compare/' + $routeParams.env1 + "/" + $routeParams.env2)
      .then(function(response){
        console.log(response.data);
        console.log(response.data[Object.keys(response.data)[0]]);
        $scope.env1 = $routeParams.env1;
        $scope.env2 = $routeParams.env2;
        $scope.envdata = response.data;
    });
});

pemApp.controller('env_compare_prepController', function($scope, $http, $routeParams, $location) {
    $http.get(conn_string + '/envs')
      .then(function(response){
        var envs = response.data;
        delete envs[$routeParams.env1];

        $scope.env1 = $routeParams.env1;
        $scope.envdata = envs;
    });

    $scope.redirect = function() {
        $location.path('/env_compare/' + $scope.env1 + "/" + $scope.selectedItem);
    }

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
