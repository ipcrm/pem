# PEM

- Tested with ruby 2.3.1 and 2.4.1
- Copy config.yml.default to config.yml
- Edit config.yml as needed for your environment

For Development, automatic restarts on file changes
```
bundle install
bundle exec guard
```

For running long-term
```
bundle install --without development
bundle exec rackup
```

## Docs (Including API SPEC)
```
bundle exec yardoc
bundle exec yard server
```


## Converting an existing environment (that uses r10k today)

> Note: will not currently work with PE only modules from forge

Start app (see above) and run the helper below.  Zero error handling is done in the helper; you must review the application logs.  Remember - its the PATH to the control repo (or whatever directory you have a Puppetfile sitting in), not the Puppetfile itself.
```
ruby ./utils/convert_puppetfile.rb <control repo path> <new env name>
```


## Using fake file-sync
> NOTE: This 'fake' is really, really bad and needs improvement - but it works

Change directory into the utils dir
```
bundle install
bundle exec ruby ./fake_filesync.rb
```

Update your config.yml
```
master: localhost
verify_ssl: false
```

Now fire up PEM and use normally - albeit 100% local and really fake.

