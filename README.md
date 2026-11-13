*This project has been created as part of the 42 curriculum by <rparreir>.*

# Codexion

## Description

Codexion is a simulation in C with POSIX threads. Coders sit around a circular
table with one USB dongle between each pair of neighbours. To compile, a coder
needs the two dongles next to them; after that they debug and refactor. A coder
who does not start compiling within `time_to_burnout` ms burns out, and the
simulation stops.

The goal is to share the dongles between threads without data races, deadlocks
or starvation, using mutexes, a fair scheduler (`fifo` or `edf`) and a monitor
thread that detects burnouts.

## Instructions

Compile with `make` (also `clean`, `fclean`, `re`). Run with 8 arguments:

    ./codexion number_of_coders time_to_burnout time_to_compile time_to_debug \
        time_to_refactor number_of_compiles_required dongle_cooldown scheduler

Times are in milliseconds, and `scheduler` is `fifo` or `edf`. Example:

    ./codexion 4 800 200 200 200 5 10 fifo

## Blocking cases handled

- **Deadlock.** Of the four Coffman conditions, we break *circular wait*: even
  coders take their left dongle first, odd coders their right one. Some
  neighbours then want the same dongle first, and one of them waits holding
  nothing, so a circle of coders each holding one dongle can never form.
- **Starvation.** Each dongle has a waiting queue (a small min-heap), and only
  the coder at the front can take it: with `fifo` the oldest request, with
  `edf` the earliest burnout deadline (ties go to the oldest request).
- **Cooldown.** A released dongle stores `available_at = now + dongle_cooldown`;
  nobody can take it before that time.
- **Burnout detection.** A monitor thread checks every deadline each 1 ms, so
  the message is printed well within the 10 ms limit.
- **Log serialization.** Every message is printed under one log mutex, and
  nothing is printed after "burned out".
- **One coder.** There is only one dongle, so the coder can never compile and
  burns out after `time_to_burnout` ms.
- **Stopping while waiting.** A waiting coder keeps checking if the simulation
  is over; if it ends after they took one dongle, they put it back.

## Thread synchronization mechanisms

- **One `pthread_mutex_t` per dongle** protects `taken`, `available_at` and
  the queue. The check "is it free, and am I first?" and `taken = 1` happen
  under the same lock, so two neighbours can never take the same dongle.
- **`log_mutex`** lets only one thread print at a time, so lines never mix.
- **`stop_mutex`** protects what coders and the monitor share: each coder's
  deadline and compile count (written by the coder, read by the monitor) and
  the `simulation_over` flag (set by the monitor, read by the coders). This is
  how they talk to each other without data races.
- **`pthread_cond_t start_cond`** is a start gate: coders wait on it until the
  main thread sets the start time, then one broadcast releases them together.
- Waiting for a dongle uses no condition variable: the coder retries every
  0.5 ms (`usleep`), and the queue keeps the order fair.

`log_mutex` is always locked before `stop_mutex`, never the other way round,
so these two locks cannot deadlock each other.

## Resources

- Man pages: `pthread_create`, `pthread_mutex_lock`, `pthread_cond_wait`,
  `clock_gettime`, `usleep`.
- CodeVault videos: [How to pass arguments to threads in C](https://www.youtube.com/watch?v=HDohXvS6UIk)
  and [Deadlocks in C](https://www.youtube.com/watch?v=LjWug2tvSBU).
- [Codexion visualizer](https://codexion-visualizer.sacha-dev.me), a community
  tool used to check the logs.

**AI usage.** I used Claude (Anthropic) as a tutor during the project:
to help plan the phases, explain concepts (threads, mutexes, deadlock, heaps),
review my code and help with debugging.
