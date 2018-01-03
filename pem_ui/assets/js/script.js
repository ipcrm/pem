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

        .when('/env_create', {
            templateUrl : 'assets/pages/env_create.html',
            controller  : 'env_createController'
        })

        .when('/env_update/:env/:module/:current_version', {
            templateUrl : 'assets/pages/env_update.html',
            controller  : 'env_updateController'
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

pemApp.controller('env_createController', function($scope, $http, $location) {
//    $http.get(conn_string + '/modules')
//      .then(function(response){
//        $scope.modules = response.data
//    });
});

pemApp.controller('env_updateController', function($scope, $http, $location, $routeParams) {
    $scope.current_version = $routeParams.current_version;
    $scope.module = $routeParams.module; 
    $scope.env = $routeParams.env;

    $http.get(conn_string + '/modules')
      .then(function(response){
        var modules = response.data
        $scope.versions = modules[$routeParams.module];
    });

    $http.get(conn_string + '/envs/' + $routeParams.env + '/modules')
      .then(function(response){
        $scope.env_modules = response.data
    });

    $scope.update_env = function(selected) {
        $scope.loading = true;

        delete $scope.env_modules[$routeParams.module];
        $scope.env_modules[$routeParams.module] = selected;

        $http.post(conn_string + '/envs/' + $routeParams.env + '/create', $scope.env_modules)
            .then(function(response){
                console.log($scope.env_modules);
                $scope.create_env_resp = response.data;
            }).finally(function(){
                $scope.loading = false;
                $scope.loaded = true;
            });
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
