## Use this to listen to the change of an object ##

## LTC means 'Listening To Changes' ##

"""
	struct LTChange

Structure used the represent a change in a object.
"""
struct LTChange
	id :: UInt32
	f :: Function
	_module_ :: Module
end

"""
	struct LTC

Structure used to listen to the changes of an object.
"""
struct LTC{T}
	obj :: WeakRef{T}
	old :: T

	stream :: Channel
	condition :: Union{nothing,Condition}
	frequency :: Float64

	function LTC{T}(obj) where T

	end
end