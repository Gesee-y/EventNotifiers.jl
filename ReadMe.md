---
Title: Notifyers.jl

Author: Talom Laël

Contact : gesee37@gmail.com

...

# Notifyers.jl

## Quick start

```julia
import Pkg
Pkg.add("Notifyers")
using Notifyers
```

## Intro

Event-driven system have always been a must in many domain: GUI application, robotics, plotting, etc.
There are package already addressing that subject like  [Reactive.jl](https://github.com/JuliaGizmos/Reactive.jl) that use asynchronous signals or  [Observables.jl](https://github.com/JuliaGizmos/Observables.jl) that use synchronous Observable.

In this ecosystem, Notifyers.jl can be seen as a package that provides the better of both worlds, providing Notifyer, objects relying on states to define their behavior. We may have a synchronous state, asynchronous state, etc. And some states can be mixed together to make unique behaviors.

## Installation 

```julia
julia> ] add Notifyers
```

## Features 

   * Intuitive syntax to create Notifyer, inspired from [Godot game engine signals](https://docs.godotengine.org/en/stable/classes/class_signal.html) (`@Notifyer name(arg1::type1,...,argn::typen)`)
   * Multiple states to create multiple behaviors (delayed calls, async delayed calls, single task, etc)
   * States can be passed to one Notifyer to another

## Why Notifyers.jl ?

While offering comparable performance to two package above, `Notifyer` offer a versatile solution if you need both synchronous and asynchronous [observer](https://www.geeksforgeeks.org/observer-pattern-set-1-introduction/) in your project.

## Why states ?

I was thinking after using Reactive and Observable, on a way to get the better of both package since they did approximately the same thing but in different manner.
While learning graphic programming with OpenGL, I got inspired by, [OpenGL]'s state machine in which the procedure is simple:

   * You set a state.
   * You do some operation in this state.
   * You quit the state.

I then decide to do the same with Notifyers.

## Docs

If you want to dive more in the Notifyers, we recommend you to start with the [doc](https://github.com/Gesee-y/Notifyers.jl/blob/main/index.md)

## License

This package is under the MIT license, see [license](https://github.com/Gesee-y/Notifyers.jl/blob/main/License.txt) for more info

## Contribution

I would greatly appreciate your contribution to the package.
To do so, just :
   1. Fork the repository
   2. Create a new branch
   3. Submit a Pull Request

## Bug Report

We know that nothing is perfect in this world, and that is the case for this package so, if there is any bug, improvement you want, or any counter-intuitive, create an issue at [my github](https://github.com/Gesee-y/Notifyers.jl)