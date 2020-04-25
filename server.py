#!/usr/bin/env python3
"""a simple, websocket-based chatroom
This code was adapted in part from the websockets example:
https://websockets.readthedocs.io/en/stable/intro.html
"""

import asyncio
import json
import logging
import websockets
from collections import defaultdict

logging.basicConfig(level=logging.INFO)

# dictionary mapping socket to name
USERS = {} # websocket -> name
USER_ROOMS = {} # websocket -> room name
ROOM_USERS = defaultdict(set) # room -> set of websockets

async def notify_name_change(room, old, new):
    """Notify users that someone in [room] changed their name.
    [room]: list of websockets
    [old]: Old name. May be ""
    [new]: New name.
    """
    if old:
        msg = json.dumps({"content": f"{old} changed their name to {new}."})
    # treat identifying for the first time as "joining the room"
    else:
        msg = json.dumps({"content": f"{new} has entered the room."})
    if room:
        await asyncio.wait([user.send(msg) for user in room])

async def notify_join(room, name):
    """Notify users in [room] that someone [name] left.
    [room]: list of websockets
    [name]: name of the person joining
    """
    # if the user never identified themselves, don't mention
    # anything to anyone
    if name:
        msg = json.dumps({"content": f"{name} has entered the room."})
        if room:
            await asyncio.wait([user.send(msg) for user in room])

async def notify_leave(room, name):
    """Notify users in [room] that someone [name] left.
    [room]: list of websockets
    [name]: name of the person leaving
    """
    # if the user never identified themselves, don't mention
    # anything to anyone
    if name:
        msg = json.dumps({"content": f"{name} left the room."})
        if room:
            await asyncio.wait([user.send(msg) for user in room])

async def send_message(websocket, message):
    """handle [message] sent from [websocket]
    [message] will be forwarded to other people in [websocket]'s room"""
    name = USERS[websocket]
    room = ROOM_USERS[USER_ROOMS[websocket]]
    # we don't allow the user to send a message if they
    # have not yet identified themself
    if name:
        msg = json.dumps({"from": name, "content": message})
        if room:
            await asyncio.wait([user.send(msg) for user in room])

async def register(websocket):
    logging.info(f"Registering: {websocket}")
    USERS[websocket] = ""
    await join_room(websocket, "Honda_Vehicles")

async def join_room(websocket, room_name):
    USER_ROOMS[websocket] = room_name
    ROOM_USERS[room_name].add(websocket)
    await notify_join(ROOM_USERS[room_name], USERS[websocket])

async def leave_room(websocket):
    room_name = USER_ROOMS[websocket]
    ROOM_USERS[room_name].remove(websocket)
    del USER_ROOMS[websocket]
    await notify_leave(ROOM_USERS[room_name], USERS[websocket])

async def change_name(websocket, new_name):
    logging.info(f"Changing name: {websocket}")
    old = USERS[websocket]
    USERS[websocket] = new_name
    room = ROOM_USERS[USER_ROOMS[websocket]]
    await notify_name_change(room, old, new_name)

async def change_room(websocket, new_room):
    logging.info(f"Changing room: {websocket}")
    await leave_room(websocket)
    await websocket.send(
        json.dumps({'content': f"(Moving to new room: {new_room})"})
    )
    await join_room(websocket, new_room)

async def unregister(websocket):
    logging.info(f"Unregistering: {websocket}")
    await leave_room(websocket)
    del USERS[websocket]

async def counter(websocket, path):
    # register(websocket) sends user_event() to websocket
    await register(websocket)
    try:
        async for message in websocket:
            logging.info(message)
            try:
                data = json.loads(message)
            except json.decoder.JSONDecodeError as ex:
                logging.error(ex)
            if data["kind"] == "name":
                name = data["content"]
                await change_name(websocket, name)
            elif data["kind"] == "message":
                msg = data["content"]
                await send_message(websocket, msg)
            elif data["kind"] == "room":
                room = data["content"]
                await change_room(websocket, room)
            else:
                logging.error("unsupported event: {}", data)
    finally:
        await unregister(websocket)

if __name__ == "__main__":
    # note, you might need to change the hostname and port, depending
    # on how you set this server up
    start_server = websockets.serve(counter, "localhost", 6789)
    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()
