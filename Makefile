REPORTER ?= spec

all: js

deps:
	npm install

lint:
	coffeelint src

js:
	coffee -c bin/dockerlint.coffee
	coffee -o lib -c src
	# Insert shebang so the resulting script runs standalone
	{ echo '#!/usr/bin/env node '; cat bin/dockerlint.js; } > bin/dockerlint.js.tmp
	mv bin/dockerlint.js.tmp bin/dockerlint.js

clean:
	rm -fr bin/*.js bin/*.tmp lib *.tgz

run: js
	node bin/dockerlint -f Dockerfile

dist: js
	npm pack

tag:
	git tag -a "v`cat package.json| jsawk  'return this.version'`" -m `cat package.json| jsawk  'return this.version'`

test:
	@NODE_ENV=test ./node_modules/.bin/mocha \
		--require coffee-script/register \
		--require chai \
		--reporter ${REPORTER} \
		--compilers coffee:coffee-script/register \
		test/*.coffee

.PHONY: deps lint run tag test
