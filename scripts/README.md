# README - `./scripts`

`./scripts` is where all code scripts, regardless of language (e.g. R, python), are to be stored.

## Python environment

In the project root:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install pyprojroot
pip install jupyterlab
```

 and more..., then we do

```sh
pip freeze > requirements.txt
```
