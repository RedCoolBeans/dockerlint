# Dockerlint

Linting tool for Dockerfiles based on recommendations from
[Dockerfile Reference](https://docs.docker.com/reference/builder/) and [Best practices for writing Dockerfiles](https://docs.docker.com/articles/dockerfile_best-practices/) as of Docker 1.5.

## Install

With [npm](https://npmjs.org/) just do:

    npm install -g dockerlint

## License

MIT, please see the LICENSE file.

## ToDo

- Add support for --version which checks against a specific Docker version
- Move the rule specific functions into a Rule class
