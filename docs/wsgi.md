# WSGI

This project adopts the Web Server Gateway Interface from Python
to behave as the interface layer between the Nibiru server and applications.
The Nibiru framework side will implement the `application` interface.
By using the interface,
Nibiru keeps open the possibility of being used as a server for a different
web framework or library in the future.

This page documents deviations from the Python specification listed in
[PEP-3333](https://peps.python.org/pep-3333/).
Unless stated explicitly here,
Nibiru will attempt to adhere to PEP-3333.

## Why not ASGI?

My biggest motivation for this project is
to produce a simple web dev experience for Lua.
I find async programming to be a pain for what I want to do.
My Atlas project relied on libuv
and I was ultimately disappointed with the experience of working
with an event loop.
A big tradeoff with this decision is a limitation around performance.
I'm ok with that.

## Deviations

### No `write` callable

The `start_response` callable in WSGI is supposed to return a `write` callable
that frameworks can use to imperatively write data via that function.
The specification states that it only exists to serve legacy Python frameworks.
Because Nibiru is not bound by any legacy Lua frameworks,
I am choosing to skip that portion of the interface.
