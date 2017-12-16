# PEM

- Expects your using rbenv, tested with 2.3.1 and 2.4.1
- Copy config.yml.default to config.yml
- Edit config.yml as needed for your environment

```
bundle install
bundle exec rerun ./pem_app.rb
```

## Deploy Global Module

Forge Based  
```
curl -H "Content-Type: application/json" -X POST -d "{\"puppetlabs-concat\":{\"version\":\"4.1.1\",\"type\":\"forge\"}}" localhost:4567/deploy_mod  
```

Git Based  
```
curl -H "Content-Type: application/json" -X POST -d "{\"myorg-ntp\":{\"version\":\"e93a55d\",\"type\":\"git\",\"source\":\"https://github.com/ipcrm/ipcrm-ntp.git\"}}" localhost:4567/deploy_mod
```


## List all deployed global modules (and their versions)
```
curl localhost:4567/modules  
```

## Deploy an env
```
curl -sH "Content-Type: application/json" -X POST -d "{\"myorg-teamx\":\"ced1b64\",\"puppetlabs-ntp\":\"7.0.0\"}" localhost:4567/envs/test/create  
```

## Get modules for a given deployed env
```
curl localhost:4567/envs/test/modules  
```

### Compare 2 envs
```
curl -sH "Content-Type: application/json" -X POST -d "[\"test\",\"test1\"]" localhost:4567/envs/compare  
```

## List All deployed Envs and their modules
```
curl localhost:4567/envs  
```

## Converting an existing environment (that uses r10k today) can be done:

> Note: will not currently work with PE only modules from forge

Start app (see above) and run the helper below.  Zero error handling is done in the helper; you must review the application logs
```
ruby ./utils/convert_puppetfile.rb <control repo path> <new env name>
```



