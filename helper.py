#!/usr/bin/env python3
import websocket
import argparse
from enum import Enum


class WorkMode(Enum):
    printer = "printer"
    echo = "echo"
    dual = "dual"

    def __str__(self) -> str:
        return self.value


parser = argparse.ArgumentParser()

parser.add_argument(
    "--address",
    type=str,
    required=False,
    default="ws://127.0.0.1:9003/",
    help="websocket address",
)
parser.add_argument(
    "--mode",
    type=WorkMode,
    required=False,
    default=WorkMode.echo,
    choices=list(WorkMode),
    help="wrok mode",
)
parser.add_argument(
    "--content",
    type=str,
    required=False,
    help="content to send",
)

opts = parser.parse_args()


def printer():
    client = websocket.create_connection(opts.address)
    result = client.recv()
    print(result, end="")
    client.close()


def echo():
    client = websocket.create_connection(opts.address)
    client.send(opts.content)
    result = client.recv()
    print(result, end="")
    client.close()


def dual():
    first_client = websocket.create_connection(opts.address)
    second_client = websocket.create_connection(opts.address)
    first_client.send(opts.content)
    result = second_client.recv()
    print(result, end="")
    first_client.close()
    second_client.close()


if __name__ == "__main__":
    if opts.mode == WorkMode.printer:
        printer()
    elif opts.mode == WorkMode.echo:
        echo()
    elif opts.mode == WorkMode.dual:
        dual()
    else:
        print("error")
