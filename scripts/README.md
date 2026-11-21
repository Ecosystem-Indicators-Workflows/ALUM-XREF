# README - `./scripts`

`./scripts` is where all code scripts, regardless of language (e.g. R, python), are to be stored.

## Python environment

In the project root we create and activate the environment:

```sh
python3 -m venv .venv
source .venv/bin/activate
```

We then upgrade the `pip` tool and install the packages required for the scripts

```sh
pip install --upgrade pip
pip install pyprojroot
pip install jupyterlab
```

Once these steps are completed we save the requirements file. This file can be used to replicate the installation of all components.

```sh
pip freeze > requirements.txt
```
