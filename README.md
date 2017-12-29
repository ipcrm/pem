# PEM

- Tested with both ruby 2.3.1 and 2.4.1
- Copy config.yml.default to config.yml
- Edit config.yml as needed for your environment

For Development, automatic restarts on file changes
```
bundle install
bundle exec guard
```

For running long-term
```
bundle install
bundle exec rackup
```

## YARD Docs (Including API SPEC)
```
bundle exec yardoc
bundle exec yard server
```

## Deploy Global Module

Forge Based  
```
curl -H "Content-Type: application/json" -X POST -d "{\"puppetlabs-concat\":{\"version\":\"4.1.1\",\"type\":\"forge\"}}" localhost:9292/deploy_mod  
```

Git Based  
```
curl -H "Content-Type: application/json" -X POST -d "{\"myorg-ntp\":{\"version\":\"e93a55d\",\"type\":\"git\",\"source\":\"https://github.com/ipcrm/ipcrm-ntp.git\"}}" localhost:9292/deploy_mod
```


## List all deployed global modules (and their versions)
```
curl localhost:9292/modules  
```

## Deploy an env
```
curl -sH "Content-Type: application/json" -X POST -d "{\"myorg-teamx\":\"ced1b64\",\"puppetlabs-ntp\":\"7.0.0\"}" localhost:9292/envs/test/create  
```

## Get modules for a given deployed env
```
curl localhost:9292/envs/test/modules  
```

### Compare 2 envs
```
curl -sH "Content-Type: application/json" -X POST -d "[\"test\",\"test1\"]" localhost:9292/envs/compare  
```

## List All deployed Envs and their modules
```
curl localhost:9292/envs  
```

## Converting an existing environment (that uses r10k today)

> Note: will not currently work with PE only modules from forge

Start app (see above) and run the helper below.  Zero error handling is done in the helper; you must review the application logs
```
ruby ./utils/convert_puppetfile.rb <control repo path> <new env name>
```



