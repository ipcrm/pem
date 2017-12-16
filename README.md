# PEM

- Expects your using rbenv, with 2.3.1 installed

```
bundle install
be rerun ./pem_app.rb
```

See cheatsheet.md


Converting an existing environment (that uses r10k today) can be done:
```
ruby ./utils/convert_puppetfile.rb <control repo path> <new env name>
```


