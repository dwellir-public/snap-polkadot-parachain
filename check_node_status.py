#!/usr/bin/env python3

import pathlib
import runpy


if __name__ == "__main__":
    runpy.run_path(str(pathlib.Path(__file__).with_name("tests").joinpath("check_node_status.py")), run_name="__main__")
