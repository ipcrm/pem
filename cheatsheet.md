## List All deployed Envs and their modules
curl localhost:4567/envs

## Deploy Mod
curl -H "Content-Type: application/json" -X POST -d "{\"myorg-ntp\":{\"version\":\"e93a55d\",\"type\":\"git\",\"source\":\"https://github.com/ipcrm/ipcrm-ntp.git\"}}" localhost:4567/deploy_mod
curl -H "Content-Type: application/json" -X POST -d "{\"myorg-teamx\":{\"version\":\"ced1b64\",\"type\":\"git\",\"source\":\"https://github.com/ipcrm/teamx_hieradata.git\"}}" localhost:4567/deploy_mod
curl -H "Content-Type: application/json" -X POST -d "{\"puppetlabs-concat\":{\"version\":\"4.1.1\",\"type\":\"forge\"}}" localhost:4567/deploy_mod
curl -H "Content-Type: application/json" -X POST -d "{\"puppetlabs-concat\":{\"version\":\"4.0.0\",\"type\":\"forge\"}}" localhost:4567/deploy_mod
curl -H "Content-Type: application/json" -X POST -d "{\"puppetlabs-ntp\":{\"version\":\"7.0.0\",\"type\":\"forge\"}}" localhost:4567/deploy_mod
curl -H "Content-Type: application/json" -X POST -d "{\"puppetlabs-ntp\":{\"version\":\"6.4.1\",\"type\":\"forge\"}}" localhost:4567/deploy_mod

## Deploy an env
curl -sH "Content-Type: application/json" -X POST -d "{\"myorg-teamx\":\"ced1b64\",\"puppetlabs-ntp\":\"7.0.0\"}" localhost:4567/envs/test/create
curl -sH "Content-Type: application/json" -X POST -d "{\"myorg-teamx\":\"ced1b64\",\"puppetlabs-ntp\":\"6.4.1\",\"puppetlabs-concat\":\"4.1.1\"}" localhost:4567/envs/test1/create


## Get modules for a given deployed env
curl localhost:4567/envs/test/modules

### Compare 2 envs
curl -sH "Content-Type: application/json" -X POST -d "[\"test\",\"test1\"]" localhost:4567/envs/compare

