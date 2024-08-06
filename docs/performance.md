# Performance log

With this log, I hope to capture some of the performance journey with nibiru.

# 2024-08-06

State of nibiru:

* Virtually no parser. Parsing `request-line` only.
* Single process server. No workers. No IPC.

Initial run with `hey` has a slow request running at 300ms.
The slow run has an RPS around 630 requests/sec.
I suspect this is loading of Lua modules or something.
After this slow run, the next runs will generally speed up dramatically.
Although, if I leave nibiru running long enough, the slow request will return.

All of these runs are full of `connection reset by peer`.
These messages are a function of the listen backlog.
The value of the listen backlog for these tests is 32.
When I bump the value up to 128 (which docs indicate is the max),
then it seems that nibiru outperforms the default configuration of `hey`,
and the server successfully handles all 200 requests without error.

The report below is an example with the backlog set to 32 for context.

```
❯ hey http://localhost:8081

Summary:
  Total:	0.0199 secs
  Slowest:	0.0072 secs
  Fastest:	0.0015 secs
  Average:	0.0044 secs
  Requests/sec:	10059.2196


Response time histogram:
  0.002 [1]	|■
  0.002 [1]	|■
  0.003 [4]	|■■■
  0.003 [10]	|■■■■■■■■
  0.004 [27]	|■■■■■■■■■■■■■■■■■■■■■
  0.004 [51]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.005 [42]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.005 [23]	|■■■■■■■■■■■■■■■■■■
  0.006 [7]	|■■■■■
  0.007 [11]	|■■■■■■■■■
  0.007 [5]	|■■■■


Latency distribution:
  10% in 0.0033 secs
  25% in 0.0039 secs
  50% in 0.0043 secs
  75% in 0.0049 secs
  90% in 0.0060 secs
  95% in 0.0063 secs
  99% in 0.0072 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0025 secs, 0.0015 secs, 0.0072 secs
  DNS-lookup:	0.0006 secs, 0.0000 secs, 0.0021 secs
  req write:	0.0001 secs, 0.0000 secs, 0.0013 secs
  resp wait:	0.0016 secs, 0.0002 secs, 0.0028 secs
  resp read:	0.0001 secs, 0.0000 secs, 0.0014 secs

Status code distribution:
  [200]	182 responses

Error distribution:
  [1]	Get "http://localhost:8081": read tcp [::1]:57435->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57437->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57438->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57439->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57440->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57441->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57442->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57443->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57444->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57445->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57446->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57447->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57448->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57450->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57451->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57452->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": read tcp [::1]:57546->[::1]:8081: read: connection reset by peer
  [1]	Get "http://localhost:8081": write tcp [::1]:57547->[::1]:8081: write: broken pipe
```
