# [Clear](//clearlinux.org/) [Distroless](//github.com/GoogleContainerTools/distroless)

Custom distroless images based on [Clear Linux OS](//clearlinux.org/) for my personal use

## Differences from [GoogleContainerTools/distroless](//github.com/GoogleContainerTools/distroless)

-   `cc` variant does not ship `openssl`.
-   `python` varient...
    -   does not contain a shell, and thus [`os.system()` won't work](//github.com/GoogleContainerTools/distroless/issues/601).
    -   is built without terminal (`ncurses`, `readline`) and embedded db (`gdbm`, `sqlite`) support.
    -   is built with `libressl`, and thus [lacks some hash algorithms](//peps.python.org/pep-0644/#libressl-support).
    -   supports only one major version of Python, chosen at my discretion.

## Available Images

`debug` images contain utilities (e.g. a shell) imported from the official [`busybox`](//hub.docker.com/_/busybox) image.

| Image                                                                                                 |                     Tags                      |   Platform    |
| ----------------------------------------------------------------------------------------------------- | :-------------------------------------------: | :-----------: |
| [`ghcr.io/cueaz/distroless/cc`](//github.com/cueaz/distroless/pkgs/container/distroless%2Fcc)         | `latest`, `nonroot`, `debug`, `debug-nonroot` | `linux/amd64` |
| [`ghcr.io/cueaz/distroless/python`](//github.com/cueaz/distroless/pkgs/container/distroless%2Fpython) | `latest`, `nonroot`, `debug`, `debug-nonroot` | `linux/amd64` |
