// script.js

var conn_string = location.origin;

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

  .when('/mod_create', {
    templateUrl : 'assets/pages/mod_create.html',
    controller  : 'mod_createController'
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

  .when('/env_addmod/:env', {
    templateUrl : 'assets/pages/env_addmod.html',
    controller  : 'env_addmodController'
  })

  .otherwise({redirectTo: '/environments'});

});

pemApp.controller('moduleController', function($scope, $http) {
  $http.get(conn_string + '/api/modules')
    .then(function(response){
      $scope.modules = response.data
    });
});

pemApp.controller('mod_detailController', function($scope, $http, $routeParams) {
  $http.get(conn_string + '/api/modules')
    .then(function(response){
      $scope.module_metadata = response.data[$routeParams.name][$routeParams.version];
    });

  $http.get(conn_string + '/api/find_mod_envs/' + $routeParams.name + "/" + $routeParams.version)
    .then(function(response){
      $scope.envs = response.data;
      $scope.name = $routeParams.name;
      $scope.version = $routeParams.version;
    });
});

pemApp.controller('mod_createController', function($scope, $http) {

  $scope.selected_versions = [];

  $scope.search_for_mod = function(search_string) {
    $scope.loading = true;

    $http.get(conn_string + '/api/find_forge_mod/' + search_string)
      .then(function(response){
        $scope.mod_list = response.data;
      }).finally(function(){
        $scope.loading = false;
        $scope.forge_mods_found = true;
      });
  }

  $scope.get_versions = function(name) {
    $scope.mod_versions = Object.keys($scope.mod_list[name]);
    $scope.mod_found = true;
    $scope.forge_mods_found = false;
  }

  $scope.add_module = function(name,version) {
    $scope.loading = true;

    var post_data = {};
    post_data[name] = {'type':'forge', 'version': version };
    $http.post(conn_string + '/api/deploy_mod', post_data)
      .then(function(response){
        $scope.result = response.data;
      }).finally(function(){
        $scope.loading = false;
        $scope.loaded = true;
      });
  }

  $scope.add_git_module = function() {
    $scope.mod_found = true;
    $scope.loading = true;
    var post_data = {};
    post_data[$scope.module.name] = {'type':'git', 
      'version': $scope.module.version,
      'source': $scope.module.source,
    };
    $http.post(conn_string + '/api/deploy_mod', post_data)
      .then(function(response){
        $scope.result = response.data;
      }).finally(function(){
        $scope.loading = false;
        $scope.loaded = true;
      });
  }

  $scope.addVersionToDeploy = function(version){
    $scope.selected_versions.push(version);
  }
});

pemApp.controller('envController', function($scope, $http, $location) {
  $scope.alerts = [];
  $scope.moduleAdd = {};
  $scope.versionAdd= {};
  $scope.addmodule = {};
  $scope.modifymod = {};

  $http.get(conn_string + '/api/modules')
    .then(function(response){
      $scope.allmodules = response.data
    });

  $http.get(conn_string + '/api/envs')
    .then(function(response){
      $scope.envs = response.data
    });

  $scope.closeAlert = function(index) {
    $scope.alerts.splice(index, 1);
  };

  $scope.remove_module = function(env,mod) {
    $scope.waiting = true;

    var envmods = Object.assign({}, $scope.envs[env]);
    delete envmods[mod];

    $http.post(conn_string + '/api/envs/' + env + '/create', envmods)
      .then(function successCallback(response){
        $scope.alerts.push({ type: 'success', msg: 'Successfully deleted module \''+mod+'\' from the \''+env+'\' environment!' });
        delete $scope.envs[env][mod];
      }, function errorCallback(response){
        $scope.alerts.push({ type: 'danger', msg: 'Failed to delete module \''+mod+'\' from the \''+env+'\' environment!' });
      }).finally(function(){
        $scope.waiting = false;
      });
  };

  $scope.updateEnvMod = function(env,mod,version){

    $scope.waiting = true;

    var envmods = Object.assign({}, $scope.envs[env]);
    envmods[mod] = version;;

    $http.post(conn_string + '/api/envs/' + env + '/create', envmods)
      .then(function successCallback(response){
        $scope.alerts.push({ type: 'success', msg: 'Successfully module \''+mod+'\' to version \''+version+'\' in the \''+env+'\' environment!' });
        $scope.envs[env][mod] = version;
        $scope.modifymod[env+mod] = false;
      }, function errorCallback(response){
        $scope.alerts.push({ type: 'danger', msg: 'Failed to update module \''+mod+'\' to version \''+version+'\' in the \''+env+'\' environment!' });
      }).finally(function(){
        $scope.waiting = false;
      });

  }

  $scope.acceptableModules = function(env){
    var knownmods = Object.keys($scope.allmodules);
    var envmods   = Object.keys($scope.envs[env]);

    for (i in envmods) {
      var pos = knownmods.indexOf(envmods[i]);
      if (pos != -1) {
        knownmods.splice(pos, 1);
      }
    }
    return knownmods;
  };

  $scope.delete_env = function(env) {
    $scope.waiting = true;
    $scope.deleted_env = env;
    var post_data = {};
    post_data['env'] = env;
    $http.post(conn_string + '/api/envs/delete', post_data)
      .then(function successCallback(response){
        $scope.alerts.push({ type: 'success', msg: 'Successfully deleted \''+env+'\' environment!' });
        delete $scope.envs[env];
      }, function errorCallback(response){
        $scope.alerts.push({ type: 'danger', msg: 'Failed to delete \''+env+'\' environment!' });
      }).finally(function(){
        $scope.waiting = false;
      });
  };


  $scope.addModuleToEnv = function(env) {

    var envmods = Object.assign({}, $scope.envs[env]);
    envmods[$scope.moduleAdd[env]] = $scope.versionAdd[env];

    $scope.waiting = true;

    $http.post(conn_string + '/api/envs/' + env + '/create', envmods)
      .then( function successCallback(response) {
        $scope.alerts.push({ type: 'success', msg: 'Successfully added module \''+$scope.moduleAdd[env]+'\' to the \''+env+'\' environment' });
        $scope.moduleAdd[env] = false;
        $scope.versionAdd[env] = false;
        $scope.addmodule[env] = false;
        $scope.envs[env] = envmods;
      }, function errorCallback(response) {
        $scope.alerts.push({ type: 'danger', msg: 'Failed to add module \''+$scope.moduleAdd[env]+'\' to the \''+env+'\' environment' });
      }).finally(function(){
        $scope.waiting = false;
      });
  };

});

pemApp.controller('env_compareController', function($scope, $http, $routeParams) {
  $http.get(conn_string + '/api/envs/compare/' + $routeParams.env1 + "/" + $routeParams.env2)
    .then(function(response){
      $scope.env1 = $routeParams.env1;
      $scope.env2 = $routeParams.env2;
      $scope.envdata = response.data;
    });
});

pemApp.controller('env_compare_prepController', function($scope, $http, $routeParams, $location) {
  $http.get(conn_string + '/api/envs')
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

pemApp.controller('env_createController', function($scope, $http, $location, $anchorScroll) {
  $scope.mods = {};

  $http.get(conn_string + '/api/envs')
    .then(function(response){
      $scope.envs = response.data
    });

  $http.get(conn_string + '/api/modules')
    .then(function(response){
      $scope.modules = response.data
    });

  $scope.Add = function () {
    var mod = {};
    mod.name    = $scope.Module;
    mod.version = $scope.Version;
    $scope.mods[mod.name] = mod.version;

    $scope.Module  = "";
    $scope.Version = "";
    $scope.versions_found = false;
    $scope.show_create = true;

  };

  $scope.Remove = function (m) {
    delete $scope.mods[m];
    $scope.show_create = $scope.is_mods();
  };

  $scope.is_mods = function() {
    if (Object.keys($scope.mods).length > 0){
      return true;
    } else {
      return false;
    };
  };

  $scope.get_versions = function(name) {
    $scope.mod_versions = Object.keys($scope.modules[name]);
    $scope.versions_found = true;
  };

  $scope.show_copy_env = function() {
    $scope.display_copy_env = true;
    $scope.mods = {};
    $scope.show_create = $scope.is_mods();
  };

  $scope.copy_env = function(name) {
    $scope.mods = $scope.envs[name];
    $scope.display_copy_env = false;
    $scope.show_create = $scope.is_mods();
  };

  $scope.set_name = function(name) {
    if (/^[a-zA-Z0-9_]+$/.test(name)) {
      $scope.name_set = true;
      $scope.name_invalid = false;
    } else {
      $scope.name_invalid = true;
      $scope.name_set = false;
      $scope.error_env_name = name;
    };
  }


  $scope.create_env = function() {
    $scope.loading = true;

    $http.post(conn_string + '/api/envs/' + $scope.env_name + '/create', $scope.mods)
      .then(function(response){
        $scope.create_env_resp = response.data;
      }).finally(function(){
        $scope.loading = false;
        $scope.loaded = true;
      });
  };

});

pemApp.controller('env_updateController', function($scope, $http, $routeParams) {
  $scope.current_version = $routeParams.current_version;
  $scope.module = $routeParams.module; 
  $scope.env = $routeParams.env;

  $http.get(conn_string + '/api/modules')
    .then(function(response){
      var modules = response.data
        $scope.versions = modules[$routeParams.module];
    });

  $http.get(conn_string + '/api/envs/' + $routeParams.env + '/modules')
    .then(function(response){
      $scope.env_modules = response.data
    });

  $scope.update_env = function(selected) {
    $scope.loading = true;

    delete $scope.env_modules[$routeParams.module];
    $scope.env_modules[$routeParams.module] = selected;

    $http.post(conn_string + '/api/envs/' + $routeParams.env + '/create', $scope.env_modules)
      .then(function(response){
        $scope.create_env_resp = response.data;
      }).finally(function(){
        $scope.loading = false;
        $scope.loaded = true;
      });
  }

});

pemApp.controller('env_addmodController', function($scope, $http, $routeParams) {
  $scope.mod_selected = false;
  $scope.env = $routeParams.env;

  $http.get(conn_string + '/api/modules')
    .then(function(response){
      $scope.modules = response.data
    });

  $http.get(conn_string + '/api/envs/' + $routeParams.env + '/modules')
    .then(function(response){
      $scope.env_modules = response.data
    });

  $scope.add_module = function(selected) {
    $scope.versions = $scope.modules[selected];
    $scope.selected_mod = selected;
    $scope.mod_selected = true;
  };

  $scope.deploy_mod_env = function(selectedver) {
    $scope.loading = true;

    $scope.env_modules[$scope.selected_mod] = selectedver;

    $http.post(conn_string + '/api/envs/' + $routeParams.env + '/create', $scope.env_modules)
      .then(function(response){
        $scope.create_env_resp = response.data;
      }).finally(function(){
        $scope.loading = false;
        $scope.loaded = true;
      });
  };
});

pemApp.controller('env_remove_modController', function($scope, $http, $routeParams) {
  $scope.loading = true;
  $scope.module = $routeParams.module; 
  $scope.env = $routeParams.env;

  $http.get(conn_string + '/api/envs/' + $routeParams.env + '/modules')
    .then(function(response){
      $scope.env_modules = response.data;
      delete $scope.env_modules[$routeParams.module];

      $http.post(conn_string + '/api/envs/' + $routeParams.env + '/create', $scope.env_modules)
        .then(function(response){
          $scope.create_env_resp = response.data;
        }).finally(function(){
          $scope.loading = false;
          $scope.loaded = true;
        });
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

pemApp.directive('ngConfirmBoxClick', [
    function () {
      return {
        link: function (scope, element, attr) {
          var msg = attr.ngConfirmBoxClick || "Are you sure want to delete?";
          var clickAction = attr.confirmedClick;
          element.bind('click', function (event) {
            if (window.confirm(msg)) {
              scope.$apply(clickAction);
            }
          });
        }
      };
    }
]);
