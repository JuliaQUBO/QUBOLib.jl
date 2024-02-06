@doc raw"""
    Collection(code::Symbol)

This wrapper type is used to allow for dispatch on the collection code.
"""
struct Collection{code}
    Collection(code::Symbol) = new{code}()
end
