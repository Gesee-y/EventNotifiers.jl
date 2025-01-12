---
Title: ReadMe
Author: Talom Laël
order: 1
...

##### Notifyers ####

## Quick start

```
Pkg.add("Notifyers")
using Notifyers
```

## Intro

You probably know the [Reactive](https://github.com/shashi/Reactive.jl) or the [Observables](https://JuliaGizmos.github.io/Observables.jl) package and yet you look for another implementation of the observer pattern. 
So, there you are, we provide you the [Notifyer] package who is like the fusion of Reactive and Observables via `Notifyer` objects and **states**.

This package have been created with the Reactive and Observables packages and also the [Godot Game Engine]()'s signals in mind.
So it's greatly inspired from them (without just doing copy/paste all around.)

While offering approximatively the same performance as the two package above, `Notifyer` offer a polyvalent solution to benefit the best of both world. And this solution is **State**

## States ##

States are inspired of [OpenGL] state machine in which the procedure is simple:

   * You set a state.

   * You do some operation in this state.

   * You quit the state.

That is the same for Notifyers.

Their states is managed via a `StateData` object that can be freely passed to one Notifyer to another.

So, if you want to dive more in the Notifyers, we recommend you to start with the [docs]()

## Optimization

Also, I am a bit hesitant on letting people create states, since the interface of a state is a bit complicated but if you really want to create a state, just let me know it as bug report and I will try to simplify the interface.

## Bug Report

We know that nothing is perfect in this world, and that is the case for this package so, if there is any bug, improvement you want, or any counter intuitive behaviour (like the `async_all`, `async_oldest` and `async_latest` function that also work in synchronous mode, making their names counter intuitive but that I didn't fix because I think 'async' is way more cool than all the other name I imagined.), let me know at []