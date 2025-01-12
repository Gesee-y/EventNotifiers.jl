## Implementation of the observer pattern ##

module Notifyers

export AbstractNotifyer,AbstractListener,Notifyer,Listener,@Notifyer
export connect,disconnect,emit,listeners,getargs

#=
	First of all we need to have some base structure for our Subject
	We need it to have a list of his observer so that went a change is commited
	He signal his observer. We will call the subject "Notifyer"
=#

const NOTIFYER_CHANNEL_SIZE = 255

"""
	abstract type AbstractNotifyer

The base type for any notifyer type. If you wanna create your own, he is the one you must derive from.
So you won't miss features.
"""
abstract type AbstractNotifyer end

"""
	abstract type AbstractListener

The base type for any listeners type. If you wanna create your own, he is the one you must derive from.
So you won't miss features.
"""
abstract type AbstractListener <: Function end

"""
	abstract type EmissionState

An abstract type representing all the different way notifications can be send
"""
abstract type EmissionState end

"""
	abstract type NotifyerState

This type should be use to create notifyer state, which enable or disable features.
"""
abstract type NotifyerState end

"""
	abstract type TaskMode

This type represent the different way listeners can be called.
"""
abstract type TaskMode end

"""
	abstract type DelayMode

This type represent different mode of delay.
"""
abstract type DelayMode end

"""
	abstract type AsyncMode

This type represent all the way in which calling the listeners will be organized.
"""
abstract type AsyncMode end

"""
	struct StateMismatch <: Exception
		msg :: String

A struct representing an error due to a mismatch between the current state of the notifyer 
and the command that have been given to him.
"""
struct StateMismatch <: Exception
	msg :: String
end

struct EmissionCallback{L<:AbstractListener}
	data::Vector{L}
end

"""
	struct EndEmitting

This struct should be used to tell synchronous or single tasked notifyer when he should stop calling
the other listeners. It's done by making a listener return this struct
"""
struct EndEmitting end
struct EmptyValue end

"""
	struct AsyncAll <: AsyncMode

It's an async mode in which the listeners will be called everytime the notifyer emit.
"""
struct AsyncAll <: AsyncMode end

"""
	struct AsyncLatest <: AsyncMode

It's an async mode in which only the last emission of the notifyer will be executed.
"""
mutable struct AsyncLatest <: AsyncMode 
	condition :: Condition
	lck :: ReentrantLock
	buffer :: Vector{EmissionCallback}
	data :: Vector{Tuple}
	number::Int
	active::Bool

	## Constructors

	function AsyncLatest(notif::AbstractNotifyer,n=1)
		state = get_state(notif)
		stream = get_stream(state)
		ec = nothing

		obj = new(Condition(), ReentrantLock(), EmissionCallback[], Tuple[],n,true)

		errormonitor(
			@async while obj.active

				# We first create a lock
				lock(obj.lck)

				# While there is availale items in the notifyer channel
				# We take them
				while isready(stream)
					ec = take!(stream)

					# We put each emission callback in the obj buffer
					push!(obj.buffer, ec)
				end
	
				# We suppress the emission callback in excess
				if length(obj.buffer) > obj.number
					deleteat!(obj.buffer,1)
				end
	
				# We suppress the notifyer value in excess
				if length(obj.data) > obj.number
					deleteat!(obj.data,1)
				end
				
				# This variable just serve as a marker
				# To know if we have done a synchronous call
				sync = false

				# If there is no more item in the notifyer channel
				if !isready(stream)

					# We iterate over the available data
					for i in Base.OneTo(obj.number)

						# Here we just execute the most recent calls
						# The execution depend on the state of the notifyer
						if is_asynchronous(notif)
							async_call(notif,state.async,state.emission.task,obj.data[end-(obj.number)+(1)])
						elseif is_synchronous(notif)
							if !isempty(obj.data)
								idx = clamp(length(obj.data)-obj.number+1,1,length(obj.data))
								sync_call(notif,state.async,obj.data[idx])
								sync = true
							end
						end
					end
				end
	
				# If we were in synchronous mode, it's necessary to reset the AsyncLatest object 
				if sync
					async_latest(notif,n)

					unlock(obj.lck)
					break
				else
					# We just wait for the condition
					wait(obj.condition)
				end
				unlock(obj.lck)
				
			end)
		
		return obj
	end
end

"""
	mutable struct AsyncOldest <: AsyncMode

It's an async mode in which only the first emission of the notifyer will be executed and
the other will be considered only if the first one is finished.
"""
mutable struct AsyncOldest <: AsyncMode
	running :: Vector{EmissionCallback}
	count :: Int
	lck :: ReentrantLock

	AsyncOldest(c::Int=1) = new(EmissionCallback[],c,ReentrantLock())
end

"""
	struct SingleTask <: TaskMode 

It's a task mode in which all the listeners will be called in a single task, meaning that they
will be called one after another by in an asynchronous task. 
"""
struct SingleTask <: TaskMode end

"""
	struct MultipleTask <: TaskMode 

It's a task mode in which each listeners will be called in it's own task.
"""
struct MultipleTask <: TaskMode end

"""
	struct NoDelay <: DelayMode

A delay mode that indicate that there should be no delay between listener's call
"""
struct NoDelay <: DelayMode end

"""
	struct Delay{N} <: DelayMode 
		delay_first::Bool

A delay mode indicating that there should be a delay of `N` second between each listener call.
`delay_first' indicate if there should be a delay before the first listener call
"""
struct Delay{N} <: DelayMode 
	delay_first::Bool

	## Constructor

	Delay{N}(d::Bool = false) where N = (N isa Number) ? new{N}(d) : throw(ArgumentError("Type parameter N should be a Number."))
end

"""
	struct AsynchronousState <: EmissionState
		task::TaskMode
		wait_all::Bool

This struct is used to represent the asynchronous mode of the Notifyer.
`wait_all` indicate if the current process should wait for all the task to finish before 
continuing.
"""
struct AsynchronousState <: EmissionState 
	task::TaskMode
	wait_all::Bool

	## Constructors

	AsynchronousState(t::TaskMode = MultipleTask(), w::Bool=false) = new(t,w)
end

"""
	struct SynchronousState <: EmissionState 
		priority::Bool
		consume::Bool

This struct is used to represent the synchronous mode of the Notifyer.
"""
mutable struct SynchronousState <: EmissionState 
	priority::Bool
	consume::Bool

	## Costructors

	SynchronousState(p::Bool = false, c::Bool = true) = new(p,c)
end

"""
	mutable struct ValueState{D<:Tuple} <: NotifyerState 
		value :: D

A notifyer state that set a notifyer to a state similar to a [Reactive]@ref signal.
`value` is the current value of the state
"""
mutable struct ValueState{D<:Tuple} <: NotifyerState 
	ignore_eqvalue :: Bool
	value :: D

	## Constructors

	ValueState{D}(ignore_eqvalue=false) where D <: Tuple = new{D}(ignore_eqvalue)
	ValueState{D}(val::D;ignore_eqvalue=false) where D <: Tuple = new{D}(ignore_eqvalue, val)
end

"""
	struct EmitState <: NotifyerState

A notifyer state that set the notifyer to a valueless state. 
"""
struct EmitState <: NotifyerState end

"""
	mutable struct StateData
		emission :: EmissionState
		mode :: NotifyerState
		async :: AsyncMode
		delay :: DelayMode
		stream :: Channel{EmissionCallback}
		check :: Bool

A struct representing the state of the notifyer. `delay` represent if there should be delay 
between function calls.

"""
mutable struct StateData
	emission :: EmissionState
	mode :: NotifyerState
	async :: AsyncMode
	delay :: DelayMode
	stream :: Channel{EmissionCallback}
	check :: Bool

	## Constructors ##

	StateData(emission::EmissionState = AsynchronousState(), 
			mode::NotifyerState = EmitState(), async::AsyncMode = AsyncAll(),
			delay = NoDelay()) = new(emission, mode, async, delay, 
					Channel{EmissionCallback}(NOTIFYER_CHANNEL_SIZE), true)
end

"""
	mutable struct Listener <: AbstractListener
		const f :: Function
		consume :: Bool
		priority :: Int
		value :: Any

A struct representing a listener. A listener is a function that can be connected to a notifyer.
via the function `connect`
"""
mutable struct Listener <: AbstractListener
	const f :: Function
	consume :: Bool
	priority :: Int
	value :: Any

	Listener(f,consume=false;priority=0,value=EmptyValue()) = new(f,consume,priority,value)
	Listener(l::Listener;priority=0,value=EmptyValue()) = new(l.f,l.consume,priority,value)
end

include("Signals.jl")

"""
	struct Notifyer

An immutable struct that contain all the data of our notifyer.

	Notifier(name::String,args::Tuple)

Will create a Notifyer with the given `name` and `args` type in the current scope.

## Example

```julia-repl

julia> Testing = Notifyer("Testing")

julia> Testing
Notifyer("Testing", 734, (), Function[])
```
"""
struct Notifyer <: AbstractNotifyer
	name :: String
	id :: Int
	condition :: Condition

	args :: Tuple
	listeners :: Vector{Listener}
	closed :: Ref{Bool}

	state :: StateData
	parent :: Union{Nothing, Vector{WeakRef}}

	## Constructors ##

	function Notifyer(name::String,args::Tuple=(); state = StateData(),
			parent = nothing)

		obj = new(name,sum(Int.(collect(name))),Condition(),
						args, Listener[], Ref(false), state, parent)
		_precompile_notifyer(eltype(obj))
		return obj
	end
end

"""
	@Notifyer Notifyer_name(args)

A macro to create your notifyer.
This syntax will create a notifier in the global scope as a constant.

## Example

```julia-repl

julia> @Notifiyer Testing()

julia> Testing
Notifyer("Testing", 734, (), Function[])

julia> function myfunc()
			@Notifiyer Testing2()
	   end

julia> Testing2
Notifyer("Testing2", 784, (), Function[])

```
"""
macro Notifyer(f)
	data = _extract_name_and_argument(f)
	_create_notifyer(__module__,data)
end

include("state_operations.jl")
include("core_operations.jl")
include("value_operations.jl")

"""
	getargs(notif::AbstractNotifyer)

Return the argument accepted by the Notifyer `notif`
"""
getargs(notif::AbstractNotifyer) = getfield(notif,:args)

"""
	eltype(notif::AbstractNotifyer)

Return the type of the accepted argument of the Notifyer `notif`
"""
Base.eltype(notif::AbstractNotifyer) = map(_to_args,getargs(notif))

getvalues(notif::AbstractNotifyer) = map(_to_value,getargs(notif))

Base.isequal(l1::AbstractListener,l2::AbstractListener) = l1.f == l2.f
Base.isequal(l1::AbstractListener,f::Function) = l1.f == f

include("printing.jl")
include("Timer.jl")

_to_args(t::DataType) = t
_to_args(t::Any) = typeof(t)
_to_args(t::Pair) = t.first

_to_value(t::Pair) = t.second
_to_value(t::Any) = t

function _signature_matching(argtypes,args)
	if (length(argtypes) != length(args)) return false end

	for i in eachindex(argtypes)
		_check_signature(argtypes[i],args[i]) == false && return false
	end

	return true
end

##Check the signature of a set of argument
_check_signature(a::Type,b) = b isa a
_check_signature(a::Pair,b) = b isa a.first
_check_signature(a,b) = b isa typeof(a)

## Create the notifyer as a const
# And export it to the current scope
##
function _create_notifyer(m,data)
	name = string(data[1])

	args = []

	for d in data[2]
		if d isa Symbol
			push!(args,Any)
		elseif d isa Expr
			
			if d.args[1] isa Expr
				v = d.args[2]
				d = d.args[1]
				push!(args,Pair{Type,Any}(eval(d.args[2]), v))
			else
				push!(args,eval(d.args[2]))
			end
		else
			throw(ArgumentError("Failed to create notifyer with the following data $d of type $(typeof(d))."))
		end
	end

	args = tuple(args...)
	ex = Expr(:toplevel,m,:(const $(data[1]) = Notifyer($name,$args)))
	ex2 = Expr(:export,data[1])
	eval(ex) ; eval(ex2)
end

function _precompile_notifyer(args::Tuple)
	data = Tuple{args...}
	precompile(emit, (Notifyer,args...))
	precompile(sync_call, (Notifyer, AsyncAll, data))
	precompile(sync_call, (Notifyer, AsyncOldest, data))
	precompile(sync_call, (Notifyer, AsyncLatest, data))
	precompile(async_call, (Notifyer, AsyncAll, MultipleTask, data))
	precompile(async_call, (Notifyer, AsyncOldest, MultipleTask, data))
	precompile(async_call, (Notifyer, AsyncLatest, MultipleTask, data))
	precompile(async_call, (Notifyer, AsyncAll, SingleTask, data))
	precompile(async_call, (Notifyer, AsyncOldest, SingleTask, data))
	precompile(async_call, (Notifyer, AsyncLatest, SingleTask, data))
end

function _extract_name_and_argument(n::Expr)
	name = n.args[1]
	args  = n.args[2:end]

	return name,args
end

precompile(Notifyer, (String, Tuple))

end #module

####################################### Test ################################################

#=using .Notifyers

@Notifyer Test1(x::Int,y::Int)

f(x::Int,y::Int) = x+y

c = 0
expensive_calc(x::Int,y::Int) = begin
	w = rand(10^5)
	#println("args are (",x,", ",y,")")
end

function main()
	#println(Test1)
	f(1,2)
	connect(expensive_calc,Test1)
	#connect(Test1) do x::Int,y::Int
	#	c :: Int = x+y
	#	println(c)
		#println(c)
	#end

	#println(Test1)

	sync_notif(Test1)
	async_latest(Test1,2)

	for i in 1:100
		Test1.emit = (i,1)
	end

	sleep(0.5)
	#Test1.emit = (1,1)

	#@time Test1.emit = (1,2)
	#@time Test1.emit = (1,2)
	sleep(1)
	for i in 1:100
		Test1.emit = (i,1)
	end
	sleep(1)
	async_latest(Test1,1)
	Test1.emit = (1,2)
	sleep(3)
	#println(get_state(Test1).async)
end

function main2()
	connect(expensive_calc,Test1)
	async_notif(Test1)
	async_all(Test1)

	for i in 1:100
		Test1.emit = (i,1)
	end

	sleep(0.5)
	reset(Test1)
	Test1.emit = (1,1)
	sleep(0.5)
end

function main3()
	#connect(expensive_calc,Test1)

	enable_value(Test1)
	sync_notif(Test1)
	#should_not_check_value(Test1)

	@time Test1[] = 1,1
	@time Test1[] = 1,1
	Test2 = map((x,y) -> x+y, Test1;typ=(Int,))
	Test3 = map((x,y) -> x*y, Test1;typ=(Int,))
	Test4 = map(+,Test2,Test3;typ=(Int,))

	@time Test1[] = 1,3
	@time Test1[] = 2,3

	println(Test4[])

	#println(Test2[])
end

#main3()
=#
