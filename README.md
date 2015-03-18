# Dockerlint

Linting tool for Dockerfiles based on recommendations from
[Dockerfile Reference](https://docs.docker.com/reference/builder/) and [Best practices for writing Dockerfiles](https://docs.docker.com/articles/dockerfile_best-practices/) as of Docker 1.5.

## Install

With [npm](https://npmjs.org/) just do:

    $ [sudo] npm install -g dockerlint

## Usage

Once installed it's as easy as:

    dockerlint -f Dockerfile

Which will parse the file and notify you about any actual errors (such an
omitted tag when `:` is set), and warn you about common pitfalls or bad idiom
such as the common use case of `ADD`.

In order to treat warnings as errors, use the `-p` flag.

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
