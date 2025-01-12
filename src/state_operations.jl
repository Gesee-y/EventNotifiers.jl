## ---------------------------- Operation operating on States ----------------------------- ##

export get_state, is_synchronous, is_asynchronous, is_single_tasked, is_multi_tasked, is_value_state
export is_emit_state
export enable_value, disable_value, async_all, async_oldest, async_latest
export async_notif, sync_notif, wait_all_callback, no_wait, no_delay, set_delay
export enable_priority, enable_consume, disable_consume, disable_priority
export single_task, multiple_task, should_check_value, should_not_check_value

## Function relative to delays

# Default function in case delay has not been set for a notifyer an a given delay mode
create_delay(n::AbstractNotifyer, d::DelayMode) = error("For the notifyer type $(typeof(N)), the function `create_delay` as not be set for the DelayMode $(typeof(d)).")

# Delay for the Notifyer
create_delay(n::Notifyer, d::NoDelay) = 0
create_delay(n::Notifyer, d::Delay{N}) where N = (N > 0.5) ? sleep(N) : sleep_ns(N)

_delay_first(n::AbstractNotifyer,d::DelayMode) = nothing
_delay_first(n::Notifyer,d::NoDelay) = nothing
_delay_first(n::Notifyer, d::Delay{N}) where N = d.delay_first && create_delay(n,d)

get_stream(s::StateData) = getfield(s, :stream)

get_state(n::AbstractNotifyer) = error("get_state has no method for the notifyer type $(typeof(n))")
get_state(n::Notifyer) = getfield(n, :state)

is_synchronous(n::Notifyer) = get_state(n).emission isa SynchronousState
is_asynchronous(n::Notifyer) = get_state(n).emission isa AsynchronousState

is_single_tasked(n::Notifyer) = begin
	if is_asynchronous(n)
		return get_state(n).emission.task isa SingleTask
	end

	return false
end

is_multi_tasked(n::Notifyer) = begin
	if is_asynchronous(n)
		return get_state(n).emission.task isa MultipleTask
	end

	return false
end

kill_async(m::AsyncLatest) = setfield!(m, :active, false)
kill_async(m::AsyncOldest) = nothing
kill_async(m::AsyncAll) = nothing

can_consume(t::SingleTask) = getfield(t, :consume)
can_consume(t::TaskMode) = false
can_consume(n::Notifyer) = begin
	if is_synchronous(n)
		return get_state(n).emission.consume
	elseif is_asynchronous(n)
		return can_consume(get_state(n).emission.task)
	end

	return false
end

is_value_state(n::Notifyer) = get_state(n).mode isa ValueState
is_emit_state(n::Notifyer) = get_state(n).mode isa EmitState

check_value(n::Notifyer) = get_state(n).check

###############################################################################################
###################################### STATE SETTER ###########################################
###############################################################################################

function enable_value(n::Notifyer)
	state = get_state(n)
	args = eltype(n)
	state.mode = ValueState{Tuple{args...}}()
end

function disable_value(n::Notifyer)
	state = get_state(n)
	state.mode = EmitState()
end

function async_notif(n::Notifyer; multi=true)
	state = get_state(n)
	tsk = multi ? MultipleTask() : SingleTask()
	state.emission = AsynchronousState(tsk)
end

function sync_notif(n::Notifyer; priority = false, consume = true)
	state = get_state(n)
	state.emission = SynchronousState(priority, consume)
end

function should_check_value(n::Notifyer)
	state = get_state(n)
	setfield!(state, :check, true)
end

function should_not_check_value(n::Notifyer)
	state = get_state(n)
	setfield!(state, :check, false)
end

function async_all(n::Notifyer)
	state = get_state(n)
	kill_async(state.async)
	state.async = AsyncAll()
end

function async_oldest(n::Notifyer,cnt::Int=1)
	state = get_state(n)
	kill_async(state.async)
	state.async = AsyncOldest(cnt)
end

function async_latest(notif::Notifyer, n=1)
	state = get_state(notif)
	kill_async(state.async)
	state.async = AsyncLatest(notif, n)
end

Base.reset(n::Notifyer) = reset(get_state(n).async)
Base.reset(m::AsyncAll) = nothing
Base.reset(m::AsyncOldest) = (m.running = EmissionCallback[])
Base.reset(m::AsyncLatest) = (notify(m.condition); m.buffer = EmissionCallback[]; m.data = Tuple[])

function wait_all_callback(n::Notifyer)
	if is_asynchronous(n)
		state = get_state(n)

		if is_multi_tasked(n)
			state.emission.wait_all = true
			return
		end

		throw(StateMismatch("The Notifyer is not in multi task state. use `multiple_task(n::Notifyer)` to set it to the multi task state."))
	end

	throw(StateMismatch("The Notifyer is not in asynchronous state. use `async_notif(n::Notifyer)` to set it to asynchronous mode."))
end

function no_wait(n::Notifyer)
	if is_asynchronous(n)

		if is_multi_tasked(n)
			state.emission.wait_all = false
			return
		end

		throw(StateMismatch("The Notifyer is not in multi task state. use `multiple_task(n::Notifyer)` to set it to the multi task state."))
	end

	throw(StateMismatch("The Notifyer is not in asynchronous state. use `async_notif(n::Notifyer)` to set it to asynchronous mode."))
end

function set_delay(n::Notifyer, v::Real)
	state = get_state(n)
	state.delay = Delay{v}()
end

function no_delay(n::Notifyer)
	state = get_state(n)
	state.delay = NoDelay()
end

function delay_first(n::Notifyer)
	state = get_state(n)
	if state.delay isa Delay
		state.delay.delay_first = true
		return
	end

	throw(StateMismatch("The Notifyer's delay mode is not Delay. use `set_delay(n::Notifyer,v::Real)` to set Delay mode on the notifyer."))
end

function dont_delay_first(n::Notifyer)
	state = get_state(n)
	if state.delay isa Delay
		state.delay.delay_first = false
		return
	end
end

function single_task(n::Notifyer)
	state = get_state(n)
	if is_asynchronous(n)
		state.emission.task = SingleTask()
	end

	throw(StateMismatch("The Notifyer is not in asynchronous state. use `async_notif(n::Notifyer)` to set it to asynchronous mode."))
end

function multiple_task(n::Notifyer)
	state = get_state(n)
	if is_asynchronous(n)
		state.emission.task = MultipleTask()
	end

	throw(StateMismatch("The Notifyer is not in asynchronous state. use `async_notif(n::Notifyer)` to set it to asynchronous mode."))
end

function enable_priority(n::Notifyer)
	if is_synchronous(n)
		state = get_state()
		state.emission.priority = true
	end

	throw(StateMismatch("The Notifyer is not in synchronous state. use `sync_notif(n::Notifyer)` to set to synchronous state."))
end

function disable_priority(n::Notifyer)
	if is_synchronous(n)
		state = get_state()
		state.emission.priority = false
	end

	throw(StateMismatch("The Notifyer is not in synchronous state. use `sync_notif(n::Notifyer)` to set to synchronous state."))
end

function enable_consume(n::Notifyer)
	if is_synchronous(n)
		state = get_state()
		state.emission.consume = true
	end

	throw(StateMismatch("The Notifyer is not in synchronous state. use `sync_notif(n::Notifyer)` to set to synchronous state."))
end

function disable_consume(n::Notifyer)
	if is_synchronous(n)
		state = get_state()
		state.emission.consume = false
	end

	throw(StateMismatch("The Notifyer is not in synchronous state. use `sync_notif(n::Notifyer)` to set to synchronous state."))
end

###############################################################################################
#################################### SYNCHRONOUS STATE ########################################
###############################################################################################

_exec_function(f::Function,args::Tuple) = f(args...)
_exec_function(l::Listener,args::Tuple) = _exec_function(l.f, args)

function sync_call(n::Notifyer, m::AsyncAll, value::Tuple)
	state = get_state(n)
	stream = get_stream(state)

	consume = can_consume(n)
	delay = state.delay

	while isready(stream)

		ec = take!(stream)

		_delay_first(n, delay)
		for l in ec.data
			res = _exec_function(l.f, value)

			if consume && res isa EndEmitting
				break
			end

			create_delay(n, delay)
		end
	end
end

#precompile(sync_call, (Notifyer, AsyncAll, Tuple{Int,Int}))

function sync_call(n::Notifyer, m::AsyncOldest, value::Tuple)
	state = get_state(n)
	stream = get_stream(state)

	delay = state.delay
	consume = can_consume(n)

	len = length(m.running)
	cnt = m.count

	lock(m.lck)

	# if there is an object in the stream
	if isready(stream) && len < cnt

		ec = take!(stream)

		#@async while isready(stream)
		#	take!(stream)
		#end

		push!(m.running,ec)

		_delay_first(n, delay)
		for l in ec.data
			res = _exec_function(l.f, value)

			if consume && res isa EndEmitting
				break
			end
			
			create_delay(n, delay)
		end
	end

	unlock(m.lck)
end

function sync_call(n::Notifyer, m::AsyncLatest, value::Tuple)
	state = get_state(n)
	stream = get_stream(state)
	ec = nothing

	consume = can_consume(n)
	delay = state.delay

	# We give the value of the notifyer to the AsyncLatest object
	push!(m.data,value)

	# If the AsyncLatest object is locked
	# meaning that his loop has already started
	if islocked(m.lck)

		# If there is still items in the notifyer channel
		if isready(stream)

			# Then we notify the AsyncLatest object so that his loop should start again
			notify(m.condition)
		else

			# If there is item in the AsyncLatest buffer, then we assign it to `ec`
			!isempty(m.buffer) && (ec = popfirst!(m.buffer))
		end
	end

	if ec != nothing

		_delay_first(n, delay)
		for l in ec.data
			res = _exec_function(l.f, value)

			if consume && res isa EndEmitting
				break
			end
			
			create_delay(n, delay)
		end
	end
end

###############################################################################################
#################################### ASYNCHRONOUS STATE #######################################
###############################################################################################

_task_are_running(t::Task) = !istaskdone(t)
_task_are_running(v::Vector{Task}) = !all(istaskdone, v)

wait_task(t::Task) = wait(t)
wait_task(v::Vector{Task}) = begin
	while _task_are_running(v) # while there is any task running
		yield()
	end
end

_schedule_task(t::Task,wait_all=false) = (errormonitor(schedule(t)); (wait_all && wait_task(t)))
_schedule_task(v::Vector{Task},wait_all=false) = begin

	# We schedule all the task contained in v
	
	for tsk in v
		errormonitor(schedule(tsk))
	end

	# Then if wait_all == true
	if wait_all 
		wait_task(v)
	end
end

## Functions relative to tasks

# Default
create_task(n::AbstractNotifyer, ec::EmissionCallback, t::TaskMode) = error("For the notifyer type $(typeof(N)), the function `create_task` as not be set for the TaskMode $(typeof(t)).")

function create_task(n::Notifyer, ec::EmissionCallback{Listener}, t::SingleTask, value::Tuple)
	
	delay = get_state(n).delay
	# we create our task.
	tsk = @task begin

		# this function will return nothing 
		#if delay_first is not active for the given delay mode
		_delay_first(n,delay)

		# for l in listener
		for l in ec.data
			result = l.f(value...)

			# if consume is enabled and the listener's function return EndEmitting
			(t.consume && result isa EndEmitting) && break

			# We create a delay(If there should be one)
			create_delay(n,delay)
		end
	end

	return tsk
end

function create_task(n::Notifyer, ec::EmissionCallback, t::MultipleTask, value::Tuple)

	# We get the listeners
	list = ec.data

	vt = Vector{Task}(undef, length(list))
	
	for i in eachindex(list)
		vt[i] = @task list[i].f(value...)
	end

	return vt
end

## Function relative to asynchronous calls
function async_call(n::Notifyer, m::AsyncAll, t::TaskMode, value::Tuple)
	
	# We first get the state object of the notifyer
	state = get_state(n)

	# Then we get the channel of the state object
	stream = get_stream(state)
	lck = ReentrantLock()

	lock(lck)

	# while there is an object in the stream
	while isready(stream)

		# We get the object
		ec = take!(stream)

		# And create the task
		tsk = create_task(n, ec, t, value)
		_schedule_task(tsk, state.emission.wait_all)
	end
	unlock(lck)
end
function async_call(n::Notifyer, m::AsyncOldest, t::TaskMode, value::Tuple)
	state = get_state(n)
	stream = get_stream(state)
	len = length(m.running)
	cnt = m.count

	lock(m.lck)

	# if there is an object in the stream
	if isready(stream) && len < cnt
		ec = take!(stream)
		tsk = create_task(n, ec, t, value)

		push!(m.running,ec)

		_schedule_task(tsk)

		if len == 0
			errormonitor(@async begin

				# while there is any task running
				while _task_are_running(tsk)

					# We take the other task (to destroy them.)
					isready(stream) && take!(stream)
					yield()
				end
				m.running = EmissionCallback[]
			end)
		end

		state.emission.wait_all && wait_task(tsk)
	end
	unlock(m.lck)
end
function async_call(n::Notifyer, m::AsyncLatest, t::TaskMode, value::Tuple)
	state = get_state(n)
	stream = get_stream(state)
	ec = nothing

	# If the AsyncLatest object is locked
	# meaning that his loop has already started
	if islocked(m.lck)

		# If there is still items in the notifyer channel
		if isready(stream)

			# Then we notify the AsyncLatest object so that his loop should start again
			notify(m.condition)
		else
			# If there is item in the AsyncLatest buffer, then we assign it to `ec`
			!isempty(m.buffer) && (ec = popfirst!(m.buffer))
		end
	end

	# We give the value of the notifyer to the AsyncLatest object
	push!(m.data,value)

	if ec != nothing
		tsk = create_task(n, ec, t, value)

		_schedule_task(tsk, state.emission.wait_all)
	end
end
