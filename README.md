[![NPM](https://nodei.co/npm/dockerlint.png?downloads=true&downloadRank=true&stars=true)](https://nodei.co/npm/dockerlint/)
[![Build Status](https://travis-ci.org/RedCoolBeans/dockerlint.svg?branch=master)](https://travis-ci.org/RedCoolBeans/dockerlint)
[![Build status](https://ci.appveyor.com/api/projects/status/bwvl5wexs90wspyg?svg=true)](https://ci.appveyor.com/project/jasperla/dockerlint)

# Dockerlint

Linting tool for Dockerfiles based on recommendations from
[Dockerfile Reference](https://docs.docker.com/reference/builder/) and [Best practices for writing Dockerfiles](https://docs.docker.com/articles/dockerfile_best-practices/) as of Docker 1.6.

## Install

With [npm](https://npmjs.org/) just do:

    $ [sudo] npm install -g dockerlint

## Usage

Once installed it's as easy as:

    dockerlint Dockerfile

Which will parse the file and notify you about any actual errors (such an
omitted tag when `:` is set), and warn you about common pitfalls or bad idiom
such as the common use case of `ADD`.

In order to treat warnings as errors, use the `-p` flag.

## Docker image

Alternatively there is a [Docker image](https://hub.docker.com/r/redcoolbeans/dockerlint) available.

This image provides a quick and easy way to validate your Dockerfiles, without
having to install Node.JS and the dockerlint dependencies on your system.

First fetch the image from the [Docker Hub](https://hub.docker.com/):

    docker pull redcoolbeans/dockerlint

You can either run it directly, or use [docker-compose](https://www.docker.com/docker-compose).

### docker run

For a quick one-off validation:

    docker run -it --rm -v "$PWD/Dockerfile":/Dockerfile:ro redcoolbeans/dockerlint

### docker-compose

For docker-compose use a `docker-compose.yml` such as the following:

    ---
      dockerlint:
        image: redcoolbeans/dockerlint
        volumes:
          - ./Dockerfile:/Dockerfile

Then simply run:

    docker-compose up dockerlint

This will validate the `Dockerfile` in your current directory.


### Running from a git clone

If you've cloned this repository, you can run `dockerlint` with:

    make deps # runs npm install
    make js && coffee bin/dockerlint.coffee

If you're building on Windows, you'll have to set the path to your `make`:

    npm config set dockerlint:winmake "mingw32-make.exe"

or pass it to every invocation:

    npm run build:win --dockerlint:winmake=mingw32-make.exe

## Roadmap

- Add support for --version which checks against a specific Docker version
- Refactor code to move the rule specific functions into a Rule class

## License

MIT, please see the LICENSE file.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
