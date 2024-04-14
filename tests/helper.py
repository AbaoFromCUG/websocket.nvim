#!/usr/bin/env python3
from time import sleep
import sys
import base64
from typing import Dict, Callable

#
from websockets import ConnectionClosed
from websockets.sync.client import connect
import argparse
from enum import Enum


test_mode: Dict[str, Callable] = dict()


def sync_client_connect(address: str):
    return connect(address, open_timeout=200)


def register(func: Callable):
    test_mode[func.__name__] = func
    return func


if True:

    @register
    def connection_establish():
        client = sync_client_connect(opts.address)
        sleep(2)
        client.close()

    @register
    def connection_client_disconnect():
        with sync_client_connect(opts.address) as client:
            sleep(0.5)

    @register
    def connection_server_disconnect():
        client = sync_client_connect(opts.address)
        sleep(0.5)
        try:
            client.send("foo")
            pass
        except ConnectionClosed:
            client.close()
            return 0
        sleep(10000)
        client.close()

    @register
    def server2client():
        client = sync_client_connect(opts.address)
        result = client.recv()
        print(result, end="")
        sleep(0.5)
        client.close()

    @register
    def client2server():
        client = sync_client_connect(opts.address)
        client.send("bar")
        sleep(0.5)
        client.close()

    @register
    def client2server_big():
        with open("tests/websocket/shared.lua", "r", encoding="utf-8") as file:
            data = file.read()
            data = data * 1024
            client = sync_client_connect(opts.address)
            client.send(data)
            sleep(0.5)
            client.close()

    @register
    def server2client2server():
        client = sync_client_connect(opts.address)
        result = client.recv()
        print(result, end="")
        client.send(result)
        sleep(0.5)
        client.close()

    @register
    def client2server2client():
        client = sync_client_connect(opts.address)
        client.send("bar")
        result = client.recv()
        print(result, end="")
        sleep(0.5)
        client.close()

    @register
    def pulse_server():
        client = sync_client_connect(opts.address)
        for _ in range(0, 10000):
            result = client.recv()
            print(result, end="", flush=True)
        sleep(0.5)
        client.close()

    @register
    def pulse_client():
        client = sync_client_connect(opts.address)
        for i in range(0, 10000):
            client.send(f"bar:{i}")
        sleep(0.5)
        client.close()

    @register
    def reflex_server():
        client = sync_client_connect(opts.address)
        for i in range(0, 10000):
            result = client.recv()
            [prefix, num] = result.split(":")
            assert prefix == "foo"
            client.send(f"bar:{int(num)+1}")
        sleep(0.5)
        client.close()

    @register
    def reflex_server_big():
        client = sync_client_connect(opts.address)
        for i in range(0, 8):
            data: str = client.recv()
            data = data + data
            client.send(data)
        sleep(0.5)
        client.close()

    @register
    def reflex_client():
        client = sync_client_connect(opts.address)
        for i in range(0, 10000):
            client.send(f"bar:{i}")
            result = client.recv()
            assert result == f"foo:{i+1}"
            print(result, end="", flush=True)
        sleep(0.5)
        client.close()


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
    type=str,
    required=False,
    choices=list(test_mode.keys()),
    help="wrok mode",
)

opts = parser.parse_args()


if __name__ == "__main__":
    # print(opts, test_mode)
    if test_mode[opts.mode] != None:
        test_mode[opts.mode]()
    else:
        print("error")
        assert False
