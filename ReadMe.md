---
Title: ReadMe

Author: Talom Laël
...

##### Notifyers ####

## Quick start

```
import Pkg
Pkg.add("Notifyers")
using Notifyers
```

## Intro

Event-driven system have always been a must in many domain: GUI application, robotics, plotting, etc.
There are package already addressing that subject like  [Reactive](https://github.com/shashi/Reactive.jl) that use asynchronous signals or  [Observables](https://JuliaGizmos.github.io/Observables.jl) that use synchronous Observable.

In this ecosystem, Notifyer.jl can be seen as a package that provides the better of both world, providing Notifyer, objects relying on states to define their behavior. We may have a synchronous state, asynchronous state, etc. And some states can be mixed together to make unique behaviors.

## Features 

   * Intuitive syntax to create Notifyer, inspired from [Godot game engine signals]() (`@Notifyer name(args)`
   * Multiple states to create multiple behaviors (delayed calls, async delayed calls, single task, etc)
   * States can be passed to one Notifyer to another

## Why Notifyers.jl ?

While offering approximatively the same performance as the two package above, `Notifyer` offer a polyvalent solution if you need both synchronous and asynchronous [observer]() in your project.

## Why states ?

I was thinking after using Reactive and Observable, on a way to get the better of both package since they did approximately the same thing but in different manner.
While graphic programming with OpenGL, then I got inspired by the [OpenGL] state machine in which the procedure is simple:

   * You set a state.

   * You do some operation in this state.

   * You quit the state.

I then decide to do the same with Notifyers.

So, if you want to dive more in the Notifyers, we recommend you to start with the [docs]()

## Contribution


## Bug Report

We know that nothing is perfect in this world, and that is the case for this package so, if there is any bug, improvement you want, or any counter intuitive behaviour (like the `async_all`, `async_oldest` and `async_latest` function that also work in synchronous mode, making their names counter intuitive but that I didn't fix because I think 'async' is way more cool than all the other name I imagined.), create an issue at [my github](https://github.com/Gesee-y/Notifyers.jl)
