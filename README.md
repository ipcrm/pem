# PEM

- Expects your using rbenv, with 2.3.1 installed

```
bundle install
be rerun ./pem_app.rb
```

See cheatsheet.md


Converting an existing environment (that uses r10k today) can be done:

> Note: will not currently work with PE only modules from forge

Start app (see above) and run the helper below.  Zero error handling is done in the helper; you must review the application logs
```
ruby ./utils/convert_puppetfile.rb <control repo path> <new env name>
```



